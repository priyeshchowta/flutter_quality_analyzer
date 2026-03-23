/// Utility functions for working with Dart/pub version strings.
///
/// These are kept as pure functions for easy unit testing and reuse.
class VersionUtils {
  VersionUtils._(); // Prevent instantiation

  /// Strips common version constraint prefixes (^, ~, >=, <=, >, <)
  /// from a version string and returns just the numeric part.
  ///
  /// Examples:
  ///   "^1.2.3"  → "1.2.3"
  ///   ">=2.0.0" → "2.0.0"
  ///   "1.0.0"   → "1.0.0"
  static String stripConstraint(String version) {
    return version.replaceAll(RegExp(r'^[\^~>=<!]+'), '').trim();
  }

  /// Returns true if [version] looks like a valid semver string.
  ///
  /// Accepts optional pre-release and build suffixes.
  static bool isValidSemver(String version) {
    final semverRegex = RegExp(
      r'^\d+\.\d+\.\d+([+-][a-zA-Z0-9._-]+)*$',
    );
    return semverRegex.hasMatch(version.trim());
  }

  /// Formats a version constraint string for display.
  ///
  /// Returns "-" for null or empty values.
  static String formatConstraint(String? constraint) {
    if (constraint == null || constraint.isEmpty) return '-';
    return constraint;
  }
}
