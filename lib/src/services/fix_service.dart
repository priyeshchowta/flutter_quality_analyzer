import 'dart:io';

import '../models/result.dart';
import '../models/version_check_result.dart';
import '../utils/logger.dart';

/// Rewrites pubspec.yaml with the latest compatible version constraints
/// for all outdated packages.
///
/// Strategy: replaces the version constraint of each outdated package
/// in-place using regex, preserving all comments, formatting and
/// other content in the file.
class FixService {
  /// Applies upgrades to [projectPath]/pubspec.yaml.
  ///
  /// Returns the list of packages that were updated, or a failure Result.
  Result<List<String>> fix({
    required String projectPath,
    required List<VersionCheckResult> results,
    bool dryRun = false,
  }) {
    final pubspecFile = File('$projectPath/pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      return Result.failure('pubspec.yaml not found at $projectPath');
    }

    final outdated = results
        .where((r) => r.isOutdated && r.latestVersion != null && r.error == null)
        .toList();

    if (outdated.isEmpty) {
      return Result.success([]);
    }

    var content = pubspecFile.readAsStringSync();
    final updated = <String>[];

    for (final r in outdated) {
      final packageName = r.packageName;
      // Strip build metadata from latest version (e.g. "6.1.5+1" → "6.1.5")
      final rawLatest   = r.latestVersion!;
      final latest      = rawLatest.contains('+')
          ? rawLatest.substring(0, rawLatest.indexOf('+'))
          : rawLatest;
      final newConstraint = '^$latest';

      // Match lines like:   package_name: ^1.2.3
      //                     package_name: ">=1.0.0 <2.0.0"
      //                     package_name: any
      //                     package_name: # inline comment
      // Capture group 1 = everything before the version value
      final pattern = RegExp(
        r'(^\s{0,4}' + RegExp.escape(packageName) + r'\s*:\s*)([^\s#\n][^\n]*)',
        multiLine: true,
      );

      final match = pattern.firstMatch(content);
      if (match == null) {
        Logger.debug('Could not find $packageName in pubspec.yaml — skipping');
        continue;
      }

      final oldLine = match.group(0)!;
      final prefix  = match.group(1)!;
      final newLine = '$prefix$newConstraint';

      Logger.debug('$packageName: "${match.group(2)}" → "$newConstraint"');

      content = content.replaceFirst(oldLine, newLine);
      updated.add(packageName);
    }

    if (updated.isNotEmpty && !dryRun) {
      pubspecFile.writeAsStringSync(content);
    }

    return Result.success(updated);
  }
}
