import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/result.dart';
import '../utils/logger.dart';

/// Response model for a successful pub.dev package lookup.
class PubDevPackageInfo {
  final String packageName;
  final String latestVersion;

  const PubDevPackageInfo({
    required this.packageName,
    required this.latestVersion,
  });
}

/// HTTP client for the pub.dev public API.
///
/// API docs: https://pub.dev/help/api
///
/// Designed to be injectable/mockable for testing.
/// Future scope: add license info, publisher, score, etc.
class PubDevClient {
  static const _baseUrl = 'https://pub.dev/api/packages';

  /// Timeout for each HTTP request.
  static const _timeout = Duration(seconds: 10);

  final http.Client _httpClient;

  /// Accepts an optional [http.Client] for testability (dependency injection).
  PubDevClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Fetches the latest stable version of [packageName] from pub.dev.
  ///
  /// Returns [Result.failure] on network errors, non-200 responses,
  /// or malformed JSON.
  Future<Result<PubDevPackageInfo>> fetchLatestVersion(String packageName) async {
    final uri = Uri.parse('$_baseUrl/$packageName');
    Logger.debug('GET $uri');

    try {
      final response = await _httpClient.get(uri).timeout(_timeout);

      if (response.statusCode == 404) {
        return Result.failure('Package "$packageName" not found on pub.dev.');
      }

      if (response.statusCode != 200) {
        return Result.failure(
          'pub.dev returned HTTP ${response.statusCode} for "$packageName".',
        );
      }

      return _parseResponse(packageName, response.body);
    } on Exception catch (e) {
      Logger.debug('Network error for $packageName: $e');
      return Result.failure('Network error fetching "$packageName": $e');
    }
  }

  /// Parses the pub.dev JSON response and extracts the latest version string.
  ///
  /// Expected JSON shape:
  /// {
  ///   "latest": {
  ///     "version": "1.2.3",
  ///     ...
  ///   }
  /// }
  Result<PubDevPackageInfo> _parseResponse(String packageName, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final latest = json['latest'] as Map<String, dynamic>?;

      if (latest == null) {
        return Result.failure(
          'Unexpected pub.dev response shape for "$packageName": missing "latest" key.',
        );
      }

      final version = latest['version'] as String?;
      if (version == null || version.isEmpty) {
        return Result.failure(
          'Could not extract version string for "$packageName" from pub.dev response.',
        );
      }

      Logger.debug('$packageName → latest: $version');
      return Result.success(
        PubDevPackageInfo(packageName: packageName, latestVersion: version),
      );
    } catch (e) {
      return Result.failure('Failed to parse pub.dev response for "$packageName": $e');
    }
  }

  /// Disposes the underlying HTTP client.
  /// Call this when the client is no longer needed.
  void dispose() => _httpClient.close();
}
