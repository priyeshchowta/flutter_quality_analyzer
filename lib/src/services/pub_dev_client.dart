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
  final bool isDiscontinued;
  final String? replacedBy;

  const PubDevPackageInfo({
    required this.packageName,
    required this.latestVersion,
    this.license,
    this.pubPoints,
    this.popularity,
    this.likes,
    this.isDiscontinued = false,
    this.replacedBy,
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

      // isDiscontinued / replacedBy live at the top level of the package response
      final isDiscontinued = mainJson['isDiscontinued'] as bool? ?? false;
      final replacedBy     = mainJson['replacedBy'] as String?;

      // ── Parse score response ─────────────────────────────────────────────
      // Shape: { "grantedPoints": 140, "likeCount": 120,
      //          "downloadCount30Days": 500000,
      //          "tags": ["license:mit", "sdk:flutter", ...] }
      int? pubPoints;
      int? popularity;
      int? likes;
      String? license;

      if (scoreBody != null) {
        try {
          final scoreJson = jsonDecode(scoreBody) as Map<String, dynamic>;

          pubPoints = scoreJson['grantedPoints'] as int?;
          likes     = scoreJson['likeCount'] as int?;

          // popularityScore was removed from pub.dev API — use downloadCount30Days
          // Bucket downloads into a 0–100 score: 1M+ downloads = 100
          final downloads = scoreJson['downloadCount30Days'] as int?;
          if (downloads != null) {
            popularity = (downloads / 10000).clamp(0, 100).round();
          }

          // License is in tags as "license:mit", "license:bsd-3-clause" etc.
          // Pick the first SPDX-style license tag (skip meta tags like fsf-libre, osi-approved)
          final tags = (scoreJson['tags'] as List<dynamic>?)?.cast<String>() ?? [];
          final licenseTag = tags
              .where((t) => t.startsWith('license:'))
              .where((t) => !const {'license:fsf-libre', 'license:osi-approved', 'license:gpl-compatible'}.contains(t))
              .firstOrNull;
          if (licenseTag != null) {
            // Convert "license:bsd-3-clause" → proper SPDX casing
            // Known SPDX identifiers we normalise explicitly; fallback to upper-case
            final raw = licenseTag.replaceFirst('license:', '');
            const spdxMap = {
              'mit': 'MIT',
              'apache-2.0': 'Apache-2.0',
              'bsd-2-clause': 'BSD-2-Clause',
              'bsd-3-clause': 'BSD-3-Clause',
              'lgpl-2.0': 'LGPL-2.0',
              'lgpl-2.1': 'LGPL-2.1',
              'lgpl-3.0': 'LGPL-3.0',
              'gpl-2.0': 'GPL-2.0',
              'gpl-3.0': 'GPL-3.0',
              'mpl-2.0': 'MPL-2.0',
              'isc': 'ISC',
              'unlicense': 'Unlicense',
            };
            license = spdxMap[raw] ?? raw.toUpperCase();
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
        isDiscontinued: isDiscontinued,
        replacedBy: replacedBy,
      ));
    } catch (e) {
      return Result.failure('Failed to parse pub.dev response for "$packageName": $e');
    }
  }

  void dispose() => _httpClient.close();
}
