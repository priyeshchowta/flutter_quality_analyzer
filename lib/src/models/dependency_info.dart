/// Represents a single dependency extracted from pubspec.yaml.
///
/// [name] is the package name (e.g., "http").
/// [versionConstraint] is the raw version string from pubspec (e.g., "^0.13.0").
///   It can be null if the pubspec entry has no explicit version (e.g., sdk deps).
class DependencyInfo {
  final String name;
  final String? versionConstraint;

  const DependencyInfo({
    required this.name,
    required this.versionConstraint,
  });

  @override
  String toString() => 'DependencyInfo(name: $name, version: $versionConstraint)';
}
