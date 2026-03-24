import 'package:pub_semver/pub_semver.dart';

import '../models/dependency_info.dart';
import '../models/version_check_result.dart';
import '../utils/logger.dart';
import 'pub_dev_client.dart';

/// Orchestrates version + license + score checking for all dependencies.
///
/// Requests are batched concurrently to avoid rate limiting pub.dev.
class VersionChecker {
  /// Checks all [dependencies] against pub.dev concurrently.
  Future<List<VersionCheckResult>> checkAll({
    required List<DependencyInfo> dependencies,
    required PubDevClient client,
    int concurrency = 5,
  }) async {
    final results = <VersionCheckResult>[];

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

  /// Fetches full package info and builds a [VersionCheckResult].
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

    final info = fetchResult.value!;
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
    );
  }

  /// Returns true if [latestVersion] is NOT satisfied by [constraint].
  bool _isOutdated({
    required String? constraint,
    required String latestVersion,
  }) {
    if (constraint == null || constraint == 'any' || constraint.isEmpty) {
      return false;
    }

    try {
      final versionConstraint = VersionConstraint.parse(constraint);
      final latest = Version.parse(latestVersion);
      return !versionConstraint.allows(latest);
    } catch (e) {
      Logger.debug(
        'Could not parse version. constraint="$constraint", latest="$latestVersion": $e',
      );
      return _stripCaret(constraint) != latestVersion;
    }
  }

  String _stripCaret(String version) =>
      version.replaceAll(RegExp(r'^[\^~>=<]+'), '').trim();
}
