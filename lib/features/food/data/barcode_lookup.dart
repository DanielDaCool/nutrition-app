// Resolves a scanned barcode to a loggable food, or explains why the user
// has to enter it from the label.

import '../../../data/db/database.dart';
import 'barcode_format.dart';
import 'food_repository.dart';
import 'off_client.dart';
import 'remote_food.dart';

/// Whether [code] looks like a product barcode (EAN/UPC/GTIN: 6 to 14
/// digits), as opposed to e.g. a QR code with a link.
bool isProductBarcode(String code) => RegExp(r'^\d{6,14}$').hasMatch(code);

/// Result of looking up a scanned barcode.
sealed class BarcodeResult {
  const BarcodeResult(this.barcode);

  /// The trimmed barcode that was looked up.
  final String barcode;
}

/// A food is ready to log (from the local DB or freshly saved from OFF).
class BarcodeFound extends BarcodeResult {
  const BarcodeFound(super.barcode, this.food, {required this.fromCache});
  final Food food;

  /// True when the food was already in the local DB (no network call).
  final bool fromCache;
}

/// Nothing usable: offer "Add from label". [draft] holds what OFF knew (e.g.
/// the name of a product without nutrition data). [message] explains why.
class BarcodeNeedsLabel extends BarcodeResult {
  const BarcodeNeedsLabel(super.barcode, {this.draft, required this.message});
  final RemoteFood? draft;
  final String message;
}

/// The lookup didn't get an answer (offline, rate-limited, server trouble)
/// or the code isn't a product barcode at all. Not a reason to add a food
/// from the label: that food would shadow the real Open Food Facts entry for
/// good. [canRetry] is true for transient failures worth trying again.
class BarcodeFailed extends BarcodeResult {
  const BarcodeFailed(
    super.barcode, {
    required this.message,
    this.canRetry = true,
  });
  final String message;
  final bool canRetry;
}

/// Lookup order: local foods, then Open Food Facts, then "Add from label".
class BarcodeLookup {
  BarcodeLookup(this._repo, this._off);

  final FoodRepository _repo;
  final OffClient _off;

  /// Looks up [barcode]. Never throws for API failures: network, rate-limit
  /// and bad-response errors become a [BarcodeFailed] with the error
  /// message, as does a code that isn't a product barcode. Only a product
  /// Open Food Facts doesn't have (or has without nutrition) is a
  /// [BarcodeNeedsLabel]. A complete OFF product is saved locally before
  /// it's returned.
  Future<BarcodeResult> lookup(String barcode) async {
    // Normalized so the same physical barcode matches whether this scan (or
    // an earlier one, for a food already saved) decoded it as UPC-A or
    // EAN-13.
    final code = normalizeBarcode(barcode);
    // A food the user saved under this code wins, whatever the code looks
    // like.
    final local = await _repo.findByBarcode(code);
    if (local != null) return BarcodeFound(code, local, fromCache: true);
    if (!isProductBarcode(code)) {
      return BarcodeFailed(
        code,
        message: 'That doesn\'t look like a product barcode.',
        canRetry: false,
      );
    }

    final RemoteFood? remote;
    try {
      remote = await _off.product(code);
    } on FoodApiException catch (e) {
      return BarcodeFailed(
        code,
        message: e.message,
        canRetry: e.kind != FoodApiErrorKind.notFound,
      );
    }
    if (remote == null) {
      return BarcodeNeedsLabel(
        code,
        message: 'Barcode $code isn\'t in Open Food Facts.',
      );
    }
    if (!remote.isComplete) {
      return BarcodeNeedsLabel(
        code,
        draft: remote,
        message: remote.kcalPer100g == null
            ? 'Open Food Facts has "${remote.name}" but no calories for it.'
            : 'Open Food Facts has "${remote.name}" but no '
                  '${remote.missingMacros.join(' or ')} for it.',
      );
    }
    final food = await _repo.upsertRemote(remote);
    return BarcodeFound(code, food, fromCache: false);
  }
}
