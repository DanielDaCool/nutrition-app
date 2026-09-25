// HTTP client for Open Food Facts product lookup and search.

import 'package:http/http.dart' as http;

import 'http_util.dart';
import 'off_parser.dart';
import 'rate_limiter.dart';
import 'remote_food.dart';

/// Open Food Facts API client (read only).
///
/// Limits (per IP): 15 product reads/min and 10 searches/min. The client
/// enforces both locally so the user gets a clear message instead of a 429.
class OffClient {
  OffClient(
    this._http, {
    this.baseUrl = 'https://world.openfoodfacts.org',
    DateTime Function()? clock,
  }) : _productLimiter = RateLimiter(maxRequests: 15, clock: clock),
       _searchLimiter = RateLimiter(maxRequests: 10, clock: clock);

  /// OFF asks API users to identify their app in the User-Agent.
  static const userAgent =
      'NutritionApp/0.1 (+https://github.com/DanielDaCool/nutrition-app)';
  static const serviceName = 'Open Food Facts';

  final http.Client _http;
  final String baseUrl;
  final RateLimiter _productLimiter;
  final RateLimiter _searchLimiter;

  Map<String, String> get _headers => const {
    'User-Agent': userAgent,
    'Accept': 'application/json',
  };

  /// Product by barcode, or null if OFF doesn't have it.
  ///
  /// Throws [FoodApiException] for a malformed barcode, when rate limited
  /// (locally or HTTP 429), and on network, server or parse errors.
  Future<RemoteFood?> product(String barcode) async {
    final code = barcode.trim();
    if (!RegExp(r'^\d{6,14}$').hasMatch(code)) {
      throw const FoodApiException(
        FoodApiErrorKind.notFound,
        'That doesn\'t look like a product barcode.',
      );
    }
    _acquire(_productLimiter);
    final uri = Uri.parse('$baseUrl/api/v2/product/$code')
        .replace(queryParameters: {'fields': offProductFields.join(',')});
    final r = await sendGuarded(
      serviceName,
      () => _http.get(uri, headers: _headers),
    );
    // OFF answers 404 with {"status": 0, ...} for unknown barcodes.
    if (r.statusCode == 404) return null;
    _checkStatus(r);
    return parseOffProductResponse(
      decodeJsonObject(serviceName, r),
      barcode: code,
    );
  }

  /// Full-text search. Call on submit only, never per keystroke.
  ///
  /// Returns an empty list for a blank query. Throws [FoodApiException] like
  /// [product].
  Future<List<RemoteFood>> search(String query, {int pageSize = 24}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    _acquire(_searchLimiter);
    // Full-text search isn't in API v2; the documented option today is the
    // legacy search endpoint (counts toward the 10/min search limit).
    final uri = Uri.parse('$baseUrl/cgi/search.pl').replace(
      queryParameters: {
        'search_terms': q,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '$pageSize',
        'fields': offProductFields.join(','),
      },
    );
    final r = await sendGuarded(
      serviceName,
      () => _http.get(uri, headers: _headers),
    );
    _checkStatus(r);
    return parseOffSearchResponse(decodeJsonObject(serviceName, r));
  }

  /// Takes a slot from [limiter] or throws a rate-limited
  /// [FoodApiException] saying how long to wait.
  void _acquire(RateLimiter limiter) {
    final wait = limiter.tryAcquire();
    if (wait != null) {
      throw FoodApiException(
        FoodApiErrorKind.rateLimited,
        waitMessage(serviceName, wait),
      );
    }
  }

  /// Maps non-200 responses to a [FoodApiException] of the matching kind.
  void _checkStatus(http.Response r) {
    if (r.statusCode == 429) {
      throw const FoodApiException(
        FoodApiErrorKind.rateLimited,
        'Open Food Facts is limiting requests right now. '
        'Wait a minute and try again.',
      );
    }
    if (r.statusCode >= 500) {
      throw FoodApiException(
        FoodApiErrorKind.server,
        'Open Food Facts is having problems (HTTP ${r.statusCode}). '
        'Try again later.',
      );
    }
    if (r.statusCode != 200) {
      throw FoodApiException(
        FoodApiErrorKind.badResponse,
        'Open Food Facts refused the request (HTTP ${r.statusCode}).',
      );
    }
  }
}
