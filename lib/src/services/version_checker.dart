import 'package:pub_semver/pub_semver.dart';

import '../models/dependency_info.dart';
import '../models/version_check_result.dart';
import '../utils/logger.dart';
import 'pub_dev_client.dart';

/// Orchestrates version checking for a list of dependencies.
///
/// For each [DependencyInfo]:
///   1. Fetches the latest version from pub.dev via [PubDevClient].
///   2. Compares the current constraint against the latest version.
///   3. Returns a [VersionCheckResult] per package.
///
/// Requests are made concurrently using [Future.wait] for performance.
class VersionChecker {
  /// Checks all [dependencies] against pub.dev concurrently.
  ///
  /// [concurrency] limits how many requests fly at once to avoid rate limiting.
  Future<List<VersionCheckResult>> checkAll({
    required List<DependencyInfo> dependencies,
    required PubDevClient client,
    int concurrency = 5,
  }) async {
    final results = <VersionCheckResult>[];

    // Process in batches to respect pub.dev rate limits
    for (var i = 0; i < dependencies.length; i += concurrency) {
      final batch = dependencies.skip(i).take(concurrency).toList();

      Logger.debug(
        'Checking batch ${(i ~/ concurrency) + 1}: '
        '${batch.map((d) => d.name).join(', ')}',
      );

      final batchResults = await Future.wait(
        batch.map((dep) => _checkOne(dep, client)),
      );

      results.addAll(batchResults);
    }

    return results;
  }

  /// Checks a single [dependency] against pub.dev.
  Future<VersionCheckResult> _checkOne(
    DependencyInfo dependency,
    PubDevClient client,
  ) async {
    final fetchResult = await client.fetchLatestVersion(dependency.name);

    if (fetchResult.isFailure) {
      Logger.warn('Could not check ${dependency.name}: ${fetchResult.error}');
      return VersionCheckResult.failed(
        packageName: dependency.name,
        currentConstraint: dependency.versionConstraint,
        error: fetchResult.error!,
      );
    }

    final latestVersion = fetchResult.value!.latestVersion;
    final isOutdated = _isOutdated(
      constraint: dependency.versionConstraint,
      latestVersion: latestVersion,
    );

    return VersionCheckResult(
      packageName: dependency.name,
      currentConstraint: dependency.versionConstraint,
      latestVersion: latestVersion,
      isOutdated: isOutdated,
    );
  }

  /// Returns true if [latestVersion] is NOT satisfied by [constraint].
  ///
  /// Examples:
  ///   constraint: "^0.13.0",  latest: "1.2.0"  → true  (outdated)
  ///   constraint: "^1.2.0",   latest: "1.2.0"  → false (up to date)
  ///   constraint: "any",       latest: "1.0.0"  → false (any always matches)
  ///   constraint: null,        latest: "1.0.0"  → false (assume pinned via lock)
  bool _isOutdated({
    required String? constraint,
    required String latestVersion,
  }) {
    // No constraint specified — can't reliably determine outdatedness
    if (constraint == null || constraint == 'any' || constraint.isEmpty) {
      return false;
    }

    try {
      final versionConstraint = VersionConstraint.parse(constraint);
      final latest = Version.parse(latestVersion);
      return !versionConstraint.allows(latest);
    } catch (e) {
      Logger.debug(
        'Could not parse version for comparison. '
        'constraint="$constraint", latest="$latestVersion": $e',
      );
      // Fall back to string inequality — at minimum flag it if clearly different
      return _stripCaret(constraint) != latestVersion;
    }
  }

  /// Strips common version prefixes like `^`, `>=`, `~` for a rough string comparison.
  String _stripCaret(String version) {
    return version.replaceAll(RegExp(r'^[\^~>=<]+'), '').trim();
  }
}
