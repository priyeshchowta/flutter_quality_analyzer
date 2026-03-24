import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/result.dart';
import '../utils/logger.dart';

/// Full package info fetched from pub.dev API.
class PubDevPackageInfo {
  final String packageName;
  final String latestVersion;

  // ── License & score ───────────────────────────────────────
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
/// Fetches version, license, pub points, popularity, and likes
/// for any package in a single API call.
class PubDevClient {
  static const _baseUrl = 'https://pub.dev/api/packages';
  static const _scoreUrl = 'https://pub.dev/api/packages';
  static const _timeout = Duration(seconds: 10);

  final http.Client _httpClient;

  PubDevClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Fetches full package info (version + license + score) from pub.dev.
  Future<Result<PubDevPackageInfo>> fetchPackageInfo(String packageName) async {
    final uri = Uri.parse('$_baseUrl/$packageName');
    Logger.debug('GET $uri');

    try {
      // Fetch main package info and score in parallel
      final responses = await Future.wait([
        _httpClient.get(uri).timeout(_timeout),
        _httpClient
            .get(Uri.parse('$_scoreUrl/$packageName/score'))
            .timeout(_timeout),
      ]);

      final mainResponse = responses[0];
      final scoreResponse = responses[1];

      if (mainResponse.statusCode == 404) {
        return Result.failure('Package "$packageName" not found on pub.dev.');
      }

      if (mainResponse.statusCode != 200) {
        return Result.failure(
          'pub.dev returned HTTP ${mainResponse.statusCode} for "$packageName".',
        );
      }

      return _parseResponse(
        packageName,
        mainResponse.body,
        scoreResponse.statusCode == 200 ? scoreResponse.body : null,
      );
    } on Exception catch (e) {
      Logger.debug('Network error for $packageName: $e');
      return Result.failure('Network error fetching "$packageName": $e');
    }
  }

  /// Parses main package JSON + optional score JSON into [PubDevPackageInfo].
  ///
  /// Main API shape:
  /// ```json
  /// {
  ///   "latest": { "version": "1.2.3", "pubspec": { ... } },
  ///   "likes": 120
  /// }
  /// ```
  ///
  /// Score API shape:
  /// ```json
  /// {
  ///   "grantedPoints": 140,
  ///   "maxPoints": 160,
  ///   "popularityScore": 0.98,
  ///   "likeCount": 120
  /// }
  /// ```
  Result<PubDevPackageInfo> _parseResponse(
    String packageName,
    String mainBody,
    String? scoreBody,
  ) {
    try {
      final mainJson = jsonDecode(mainBody) as Map<String, dynamic>;
      final latest = mainJson['latest'] as Map<String, dynamic>?;

      if (latest == null) {
        return Result.failure(
          'Unexpected pub.dev response for "$packageName": missing "latest".',
        );
      }

      final version = latest['version'] as String?;
      if (version == null || version.isEmpty) {
        return Result.failure(
          'Could not extract version for "$packageName" from pub.dev.',
        );
      }

      // Extract license from pubspec inside the response
      final pubspec = latest['pubspec'] as Map<String, dynamic>?;
      final license = _extractLicense(pubspec);

      // Parse score data if available
      int? pubPoints;
      int? popularity;
      int? likes;

      if (scoreBody != null) {
        try {
          final scoreJson = jsonDecode(scoreBody) as Map<String, dynamic>;
          pubPoints = scoreJson['grantedPoints'] as int?;
          final popularityScore = scoreJson['popularityScore'];
          if (popularityScore != null) {
            popularity = ((popularityScore as num) * 100).round();
          }
          likes = scoreJson['likeCount'] as int?;
        } catch (e) {
          Logger.debug('Could not parse score for $packageName: $e');
        }
      }

      Logger.debug(
        '$packageName → v$version | license: $license '
        '| points: $pubPoints | popularity: $popularity%',
      );

      return Result.success(
        PubDevPackageInfo(
          packageName: packageName,
          latestVersion: version,
          license: license,
          pubPoints: pubPoints,
          popularity: popularity,
          likes: likes,
        ),
      );
    } catch (e) {
      return Result.failure(
        'Failed to parse pub.dev response for "$packageName": $e',
      );
    }
  }

  /// Extracts the license string from the pubspec map inside the API response.
  String? _extractLicense(Map<String, dynamic>? pubspec) {
    if (pubspec == null) return null;
    return pubspec['license'] as String?;
  }

  void dispose() => _httpClient.close();
}
