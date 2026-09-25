import 'dart:convert';

import 'package:http/http.dart' as http;

import 'http_util.dart';
import 'remote_food.dart';
import 'usda_parser.dart';

/// Build with `--dart-define=USDA_API_KEY=...`. DEMO_KEY allows only about
/// 30 requests/hour.
const usdaApiKey = String.fromEnvironment(
  'USDA_API_KEY',
  defaultValue: 'DEMO_KEY',
);

/// USDA FoodData Central client for generic foods (Foundation, SR Legacy).
class UsdaClient {
  UsdaClient(
    this._http, {
    this.apiKey = usdaApiKey,
    this.baseUrl = 'https://api.nal.usda.gov/fdc',
  });

  static const serviceName = 'USDA FoodData Central';
  static const dataTypes = ['Foundation', 'SR Legacy'];

  final http.Client _http;
  final String apiKey;
  final String baseUrl;

  /// Searches generic foods. Uses the POST form of /v1/foods/search so the
  /// dataType list ("SR Legacy" has a space) is sent as a JSON array.
  Future<List<RemoteFood>> search(String query, {int pageSize = 25}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.parse('$baseUrl/v1/foods/search')
        .replace(queryParameters: {'api_key': apiKey});
    final r = await sendGuarded(
      serviceName,
      () => _http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'query': q,
          'dataType': dataTypes,
          'pageSize': pageSize,
        }),
      ),
    );
    switch (r.statusCode) {
      case 200:
        return parseUsdaSearchResponse(decodeJsonObject(serviceName, r));
      case 429:
        throw FoodApiException(
          FoodApiErrorKind.rateLimited,
          apiKey == 'DEMO_KEY'
              ? 'USDA request limit reached for the demo key. Try again in '
                    'an hour, or build the app with your own USDA_API_KEY.'
              : 'USDA request limit reached. Try again in an hour.',
        );
      case 401:
      case 403:
        throw const FoodApiException(
          FoodApiErrorKind.badKey,
          'The USDA API key was rejected. Check USDA_API_KEY.',
        );
      default:
        throw FoodApiException(
          r.statusCode >= 500
              ? FoodApiErrorKind.server
              : FoodApiErrorKind.badResponse,
          'USDA search failed (HTTP ${r.statusCode}). Try again later.',
        );
    }
  }
}
