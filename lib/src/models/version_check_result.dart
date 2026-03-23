/// Holds the result of a version check for a single package.
///
/// [packageName]       - Name of the package.
/// [currentConstraint] - Raw version string from pubspec (e.g., "^0.13.0").
/// [latestVersion]     - Latest stable version from pub.dev. Null if fetch failed.
/// [isOutdated]        - True if the current constraint does not satisfy the latest version.
/// [error]             - Error message if the pub.dev fetch failed.
class VersionCheckResult {
  final String packageName;
  final String? currentConstraint;
  final String? latestVersion;
  final bool isOutdated;
  final String? error;

  const VersionCheckResult({
    required this.packageName,
    required this.currentConstraint,
    required this.latestVersion,
    required this.isOutdated,
    this.error,
  });

  /// Convenience factory for a failed fetch result.
  factory VersionCheckResult.failed({
    required String packageName,
    required String? currentConstraint,
    required String error,
  }) {
    return VersionCheckResult(
      packageName: packageName,
      currentConstraint: currentConstraint,
      latestVersion: null,
      isOutdated: false,
      error: error,
    );
  }

  @override
  String toString() =>
      'VersionCheckResult(package: $packageName, current: $currentConstraint, '
      'latest: $latestVersion, outdated: $isOutdated)';
}
