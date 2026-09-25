import '../../../data/db/database.dart';
import 'food_repository.dart';
import 'off_client.dart';
import 'remote_food.dart';

/// Result of looking up a scanned barcode.
sealed class BarcodeResult {
  const BarcodeResult(this.barcode);
  final String barcode;
}

/// A food is ready to log (from the local DB or freshly saved from OFF).
class BarcodeFound extends BarcodeResult {
  const BarcodeFound(super.barcode, this.food, {required this.fromCache});
  final Food food;
  final bool fromCache;
}

/// Nothing usable: offer "Add from label". [draft] holds what OFF knew (e.g.
/// the name of a product without nutrition data). [message] explains why.
class BarcodeNeedsLabel extends BarcodeResult {
  const BarcodeNeedsLabel(super.barcode, {this.draft, required this.message});
  final RemoteFood? draft;
  final String message;
}

/// Lookup order: local foods, then Open Food Facts, then "Add from label".
class BarcodeLookup {
  BarcodeLookup(this._repo, this._off);

  final FoodRepository _repo;
  final OffClient _off;

  Future<BarcodeResult> lookup(String barcode) async {
    final code = barcode.trim();
    final local = await _repo.findByBarcode(code);
    if (local != null) return BarcodeFound(code, local, fromCache: true);

    final RemoteFood? remote;
    try {
      remote = await _off.product(code);
    } on FoodApiException catch (e) {
      return BarcodeNeedsLabel(code, message: e.message);
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
        message: 'Open Food Facts has "${remote.name}" but no calories for it.',
      );
    }
    final food = await _repo.upsertRemote(remote);
    return BarcodeFound(code, food, fromCache: false);
  }
}
