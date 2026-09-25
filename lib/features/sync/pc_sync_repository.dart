// Owns the `sync.*` KeyValues. Pushes a full data export to a private
// GitHub Gist so the read-only web dashboard has something to read.
//
// No accounts: the user pastes a personal GitHub token (gist scope) once,
// stored on-device in KeyValues. The gist itself is private (not listed,
// requires the token to read), so the data never becomes public.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/db/database.dart';
import '../settings/data_export.dart';

/// KeyValues key for the saved GitHub token.
const githubTokenKey = 'sync.githubToken';

/// KeyValues key for the gist id created on first sync.
const gistIdKey = 'sync.gistId';

/// File name of the data blob inside the gist.
const gistFileName = 'nutrition-data.json';

class PcSyncResult {
  const PcSyncResult({required this.gistId, required this.gistUrl});

  final String gistId;
  final String gistUrl;
}

/// Thrown when a sync attempt fails; [message] is safe to show the user.
class PcSyncException implements Exception {
  PcSyncException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PcSyncRepository {
  PcSyncRepository(this._db, this._now, {http.Client? client})
    : _client = client ?? http.Client();

  final AppDatabase _db;
  final DateTime Function() _now;
  final http.Client _client;

  Future<String?> readToken() => _get(githubTokenKey);

  Future<String?> readGistId() => _get(gistIdKey);

  Future<void> saveToken(String token) => _put(githubTokenKey, token.trim());

  Future<void> clearToken() async {
    await (_db.delete(
      _db.keyValues,
    )..where((t) => t.key.equals(githubTokenKey))).go();
  }

  /// Exports the whole database and pushes it to the saved gist, creating
  /// one on the first sync. Throws [PcSyncException] on any failure.
  Future<PcSyncResult> syncNow() async {
    final token = await readToken();
    if (token == null || token.isEmpty) {
      throw PcSyncException('Add a GitHub token first');
    }
    final export = await exportAllTables(_db, now: _now());
    final content = jsonEncode(export);
    final existingId = await readGistId();
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/vnd.github+json',
      'User-Agent': 'nutrition-app-sync',
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      if (existingId == null) 'description': 'Nutrition app data (private)',
      if (existingId == null) 'public': false,
      'files': {
        gistFileName: {'content': content},
      },
    });

    http.Response response;
    try {
      response = existingId == null
          ? await _client.post(
              Uri.https('api.github.com', '/gists'),
              headers: headers,
              body: body,
            )
          : await _client.patch(
              Uri.https('api.github.com', '/gists/$existingId'),
              headers: headers,
              body: body,
            );
    } catch (e) {
      throw PcSyncException("Couldn't reach GitHub: $e");
    }

    if (response.statusCode >= 400) {
      throw PcSyncException(
        'GitHub rejected the sync (${response.statusCode}). '
        'Check the token has the "gist" scope.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, Object?>;
    final id = json['id'] as String;
    await _put(gistIdKey, id);
    final url = json['html_url'] as String? ?? 'https://gist.github.com/$id';
    return PcSyncResult(gistId: id, gistUrl: url);
  }

  Future<String?> _get(String key) async {
    final row = await (_db.select(
      _db.keyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _put(String key, String value) => _db
      .into(_db.keyValues)
      .insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));
}
