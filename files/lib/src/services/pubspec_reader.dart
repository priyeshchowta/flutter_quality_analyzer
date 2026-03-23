import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/dependency_info.dart';
import '../models/pubspec_data.dart';
import '../models/result.dart';
import '../utils/logger.dart';

/// Reads and parses a `pubspec.yaml` file from a given project directory.
///
/// Responsibilities:
///   - Locate pubspec.yaml
///   - Parse YAML content
///   - Extract `dependencies` and `dev_dependencies`
///   - Filter out SDK-based deps (e.g., `flutter`, `dart`)
///   - Return structured [PubspecData]
class PubspecReader {
  /// SDK package names that should be skipped during analysis.
  static const _sdkPackages = {'flutter', 'flutter_test', 'sky_engine'};

  /// Reads pubspec.yaml from [projectPath] and returns a [Result<PubspecData>].
  ///
  /// Returns [Result.failure] with a descriptive message on any error.
  Result<PubspecData> read(String projectPath) {
    final file = _locatePubspec(projectPath);

    if (file == null) {
      return Result.failure(
        'Could not find pubspec.yaml in: $projectPath\n'
        'Make sure you point to a valid Flutter/Dart project root.',
      );
    }

    Logger.debug('Reading pubspec.yaml from: ${file.path}');

    final YamlMap yaml;
    try {
      final content = file.readAsStringSync();
      yaml = loadYaml(content) as YamlMap;
    } catch (e) {
      return Result.failure('Failed to parse pubspec.yaml: $e');
    }

    final projectName = _extractProjectName(yaml);
    final dependencies = _extractDependencies(yaml);

    Logger.debug('Project name: $projectName');
    Logger.debug('Raw deps extracted: ${dependencies.length}');

    return Result.success(
      PubspecData(projectName: projectName, dependencies: dependencies),
    );
  }

  /// Searches for pubspec.yaml in [projectPath].
  /// Returns null if not found.
  File? _locatePubspec(String projectPath) {
    final file = File('$projectPath/pubspec.yaml');
    return file.existsSync() ? file : null;
  }

  /// Extracts the project name from the top-level `name` key.
  String _extractProjectName(YamlMap yaml) {
    return yaml['name']?.toString() ?? 'unknown';
  }

  /// Extracts both `dependencies` and `dev_dependencies` sections,
  /// merges them, and filters out SDK / invalid entries.
  List<DependencyInfo> _extractDependencies(YamlMap yaml) {
    final deps = <DependencyInfo>[];

    deps.addAll(_parseSection(yaml, 'dependencies'));
    deps.addAll(_parseSection(yaml, 'dev_dependencies'));

    return deps;
  }

  /// Parses a single YAML section (e.g., "dependencies") into a list of [DependencyInfo].
  ///
  /// Skips:
  ///   - SDK dependencies (e.g., `flutter: sdk: flutter`)
  ///   - Path/git dependencies (not resolvable via pub.dev)
  ///   - Known SDK package names
  List<DependencyInfo> _parseSection(YamlMap yaml, String sectionKey) {
    final section = yaml[sectionKey];
    if (section == null || section is! YamlMap) return [];

    final results = <DependencyInfo>[];

    for (final entry in section.entries) {
      final name = entry.key.toString();

      // Skip known SDK umbrella packages
      if (_sdkPackages.contains(name)) {
        Logger.debug('Skipping SDK package: $name');
        continue;
      }

      final value = entry.value;

      // Skip entries like: flutter: { sdk: flutter }
      if (value is YamlMap) {
        if (value.containsKey('sdk') ||
            value.containsKey('path') ||
            value.containsKey('git')) {
          Logger.debug('Skipping non-pub.dev dependency: $name');
          continue;
        }
        // Some maps have a `version` key — use that
        final versionFromMap = value['version']?.toString();
        results.add(DependencyInfo(name: name, versionConstraint: versionFromMap));
        continue;
      }

      // Standard case: http: ^1.0.0  or  http: any
      final versionConstraint = value?.toString();
      results.add(DependencyInfo(name: name, versionConstraint: versionConstraint));
    }

    return results;
  }
}
