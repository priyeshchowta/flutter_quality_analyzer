import 'dependency_info.dart';

/// Holds the parsed content of a pubspec.yaml file.
///
/// [projectName] is the name field from pubspec.yaml.
/// [dependencies] is the flat list of non-SDK dependencies to be analyzed.
class PubspecData {
  final String projectName;
  final List<DependencyInfo> dependencies;

  const PubspecData({
    required this.projectName,
    required this.dependencies,
  });

  @override
  String toString() =>
      'PubspecData(project: $projectName, deps: ${dependencies.length})';
}
