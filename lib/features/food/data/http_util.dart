import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'remote_food.dart';

const requestTimeout = Duration(seconds: 15);

/// Runs [send] and turns transport failures into [FoodApiException]s.
Future<http.Response> sendGuarded(
  String serviceName,
  Future<http.Response> Function() send,
) async {
  try {
    return await send().timeout(requestTimeout);
  } on TimeoutException {
    throw FoodApiException(
      FoodApiErrorKind.network,
      '$serviceName did not answer in time. Check your connection and try again.',
    );
  } on SocketException {
    throw FoodApiException(
      FoodApiErrorKind.network,
      'No internet connection. Check your connection and try again.',
    );
  } on http.ClientException catch (e) {
    throw FoodApiException(
      FoodApiErrorKind.network,
      'Could not reach $serviceName (${e.message}).',
    );
  }
}

/// Decodes a JSON object body, or throws [FoodApiException].
Map<String, dynamic> decodeJsonObject(String serviceName, http.Response r) {
  try {
    final body = jsonDecode(utf8.decode(r.bodyBytes));
    if (body is Map<String, dynamic>) return body;
  } on FormatException {
    // fall through
  }
  throw FoodApiException(
    FoodApiErrorKind.badResponse,
    '$serviceName sent an unexpected response.',
  );
}

String waitMessage(String serviceName, Duration wait) {
  final s = wait.inSeconds + 1;
  return '$serviceName allows only a few requests per minute. '
      'Try again in $s s.';
}
