/// Holds the complete analysis result for a single package.
///
/// Includes version info, license, pub points, popularity score,
/// and test coverage data. All new fields are nullable — they are
/// only populated when the corresponding feature is enabled.
class VersionCheckResult {
  final String packageName;
  final String? currentConstraint;
  final String? latestVersion;
  final bool isOutdated;
  final String? error;

  // ── License ───────────────────────────────────────────────
  /// SPDX license identifier e.g. "MIT", "BSD-3-Clause". Null if unknown.
  final String? license;

  // ── pub.dev score ─────────────────────────────────────────
  /// pub points out of 160 (null if not fetched)
  final int? pubPoints;

  /// Popularity score 0–100
  final int? popularity;

  /// Like count on pub.dev
  final int? likes;

  // ── Test coverage ─────────────────────────────────────────
  /// Whether a test/ directory exists in the project
  final bool? hasTests;

  /// Number of test files found
  final int? testFileCount;

  const VersionCheckResult({
    required this.packageName,
    required this.currentConstraint,
    required this.latestVersion,
    required this.isOutdated,
    this.error,
    this.license,
    this.pubPoints,
    this.popularity,
    this.likes,
    this.hasTests,
    this.testFileCount,
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

  /// Returns a copy of this result with updated fields.
  VersionCheckResult copyWith({
    String? license,
    int? pubPoints,
    int? popularity,
    int? likes,
    bool? hasTests,
    int? testFileCount,
  }) {
    return VersionCheckResult(
      packageName: packageName,
      currentConstraint: currentConstraint,
      latestVersion: latestVersion,
      isOutdated: isOutdated,
      error: error,
      license: license ?? this.license,
      pubPoints: pubPoints ?? this.pubPoints,
      popularity: popularity ?? this.popularity,
      likes: likes ?? this.likes,
      hasTests: hasTests ?? this.hasTests,
      testFileCount: testFileCount ?? this.testFileCount,
    );
  }

  @override
  String toString() =>
      'VersionCheckResult(package: $packageName, current: $currentConstraint, '
      'latest: $latestVersion, outdated: $isOutdated, license: $license)';
}
