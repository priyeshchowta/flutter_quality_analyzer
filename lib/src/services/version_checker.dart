import 'package:pub_semver/pub_semver.dart';

import '../models/dependency_info.dart';
import '../models/version_check_result.dart';
import '../utils/logger.dart';
import 'pub_dev_client.dart';

/// Orchestrates version + license + score checking for all dependencies.
///
/// Requests are batched concurrently to avoid pub.dev rate limiting.
class VersionChecker {
  Future<List<VersionCheckResult>> checkAll({
    required List<DependencyInfo> dependencies,
    required PubDevClient client,
    int concurrency = 5,
  }) async {
    final results = <VersionCheckResult>[];

    for (var i = 0; i < dependencies.length; i += concurrency) {
      final batch = dependencies.skip(i).take(concurrency).toList();
      Logger.debug(
        'Batch ${(i ~/ concurrency) + 1}: '
        '${batch.map((d) => d.name).join(', ')}',
      );

      final batchResults = await Future.wait(
        batch.map((dep) => _checkOne(dep, client)),
      );
      results.addAll(batchResults);
    }

    return results;
  }

  Future<VersionCheckResult> _checkOne(
    DependencyInfo dependency,
    PubDevClient client,
  ) async {
    final fetchResult = await client.fetchPackageInfo(dependency.name);

    if (fetchResult.isFailure) {
      Logger.warn('Could not check ${dependency.name}: ${fetchResult.error}');
      return VersionCheckResult.failed(
        packageName: dependency.name,
        currentConstraint: dependency.versionConstraint,
        error: fetchResult.error!,
      );
    }

    final info      = fetchResult.value!;
    final isOutdated = _isOutdated(
      constraint: dependency.versionConstraint,
      latestVersion: info.latestVersion,
    );

    return VersionCheckResult(
      packageName: dependency.name,
      currentConstraint: dependency.versionConstraint,
      latestVersion: info.latestVersion,
      isOutdated: isOutdated,
      license: info.license,
      pubPoints: info.pubPoints,
      popularity: info.popularity,
      likes: info.likes,
      isDiscontinued: info.isDiscontinued,
      replacedBy: info.replacedBy,
    );
  }

  /// Returns true if [latestVersion] is NOT satisfied by [constraint].
  ///
  /// Handles:
  ///   - Standard semver:   "^1.2.0", ">=2.0.0"
  ///   - Build metadata:    "6.1.5+1"  (stripped before parsing)
  ///   - Any constraint:    "any"      → never outdated
  ///   - Null constraint:   null       → never outdated
  bool _isOutdated({
    required String? constraint,
    required String latestVersion,
  }) {
    if (constraint == null || constraint.isEmpty || constraint == 'any') {
      return false;
    }

    try {
      final versionConstraint = VersionConstraint.parse(constraint);

      // Strip build metadata suffix (+1, +hotfix, etc.) before parsing
      // pub_semver does not support build metadata in Version.parse()
      final cleanLatest = _stripBuildMetadata(latestVersion);
      final latest      = Version.parse(cleanLatest);

      return !versionConstraint.allows(latest);
    } catch (e) {
      Logger.debug(
        'Version parse failed — falling back to string compare. '
        'constraint="$constraint", latest="$latestVersion": $e',
      );
      // Fallback: strip constraint prefix and compare strings
      return _stripConstraintPrefix(constraint) != latestVersion;
    }
  }

  /// Strips build metadata suffix from a version string.
  ///
  /// Examples:
  ///   "6.1.5+1"      → "6.1.5"
  ///   "1.0.0+hotfix" → "1.0.0"
  ///   "1.0.0"        → "1.0.0"
  String _stripBuildMetadata(String version) {
    final plusIndex = version.indexOf('+');
    return plusIndex >= 0 ? version.substring(0, plusIndex) : version;
  }

  /// Strips version constraint operators for fallback string comparison.
  String _stripConstraintPrefix(String version) =>
      version.replaceAll(RegExp(r'^[\^~>=<!]+'), '').trim();
}
