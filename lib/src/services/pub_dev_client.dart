import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/result.dart';
import '../utils/logger.dart';

/// Full package info fetched from pub.dev API.
class PubDevPackageInfo {
  final String packageName;
  final String latestVersion;
  final String? license;
  final int? pubPoints;
  final int? popularity;
  final int? likes;

  const PubDevPackageInfo({
    required this.packageName,
    required this.latestVersion,
    this.license,
    this.pubPoints,
    this.popularity,
    this.likes,
  });
}

/// HTTP client for the pub.dev public API.
///
/// Hits two endpoints in parallel per package:
///   GET /api/packages/{name}        → version, license (from pubspec)
///   GET /api/packages/{name}/score  → pubPoints, popularity, likes
class PubDevClient {
  static const _base    = 'https://pub.dev/api/packages';
  static const _timeout = Duration(seconds: 10);

  final http.Client _httpClient;

  PubDevClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<Result<PubDevPackageInfo>> fetchPackageInfo(String packageName) async {
    final mainUri  = Uri.parse('$_base/$packageName');
    final scoreUri = Uri.parse('$_base/$packageName/score');

    Logger.debug('GET $mainUri');
    Logger.debug('GET $scoreUri');

    try {
      final responses = await Future.wait([
        _httpClient.get(mainUri).timeout(_timeout),
        _httpClient.get(scoreUri).timeout(_timeout),
      ]);

      final mainRes  = responses[0];
      final scoreRes = responses[1];

      if (mainRes.statusCode == 404) {
        return Result.failure('Package "$packageName" not found on pub.dev.');
      }
      if (mainRes.statusCode != 200) {
        return Result.failure(
          'pub.dev returned HTTP ${mainRes.statusCode} for "$packageName".',
        );
      }

      return _parse(
        packageName,
        mainRes.body,
        scoreRes.statusCode == 200 ? scoreRes.body : null,
      );
    } on Exception catch (e) {
      Logger.debug('Network error for $packageName: $e');
      return Result.failure('Network error fetching "$packageName": $e');
    }
  }

  Result<PubDevPackageInfo> _parse(
    String packageName,
    String mainBody,
    String? scoreBody,
  ) {
    try {
      // ── Parse main response ──────────────────────────────────────────────
      // Shape: { "latest": { "version": "x.y.z", "pubspec": { ... } } }
      final mainJson = jsonDecode(mainBody) as Map<String, dynamic>;
      final latest   = mainJson['latest'] as Map<String, dynamic>?;

      if (latest == null) {
        return Result.failure('Missing "latest" in pub.dev response for "$packageName".');
      }

      final version = latest['version'] as String?;
      if (version == null || version.isEmpty) {
        return Result.failure('Could not extract version for "$packageName".');
      }

      // License lives inside latest.pubspec.license
      // e.g. "MIT" / "BSD-3-Clause" / "Apache-2.0"
      final pubspecMap = latest['pubspec'] as Map<String, dynamic>?;
      final license    = pubspecMap?['license'] as String?;

      // ── Parse score response ─────────────────────────────────────────────
      // Shape: { "grantedPoints": 140, "popularityScore": 0.98, "likeCount": 120 }
      int? pubPoints;
      int? popularity;
      int? likes;

      if (scoreBody != null) {
        try {
          final scoreJson = jsonDecode(scoreBody) as Map<String, dynamic>;

          pubPoints = scoreJson['grantedPoints'] as int?;
          likes     = scoreJson['likeCount'] as int?;

          // popularityScore is a double 0.0–1.0 → convert to 0–100 int
          final popRaw = scoreJson['popularityScore'];
          if (popRaw != null) {
            popularity = ((popRaw as num) * 100).round();
          }
        } catch (e) {
          Logger.debug('Could not parse score for $packageName: $e');
        }
      }

      Logger.debug(
        '$packageName → v$version | '
        'license: ${license ?? "?"} | '
        'pts: ${pubPoints ?? "?"} | '
        'pop: ${popularity != null ? "$popularity%" : "?"} | '
        'likes: ${likes ?? "?"}',
      );

      return Result.success(PubDevPackageInfo(
        packageName: packageName,
        latestVersion: version,
        license: license,
        pubPoints: pubPoints,
        popularity: popularity,
        likes: likes,
      ));
    } catch (e) {
      return Result.failure('Failed to parse pub.dev response for "$packageName": $e');
    }
  }

  void dispose() => _httpClient.close();
}
