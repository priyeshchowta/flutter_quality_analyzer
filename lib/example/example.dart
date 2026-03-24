import 'package:flutter_quality_analyzer/flutter_quality_analyzer.dart';

/// This example demonstrates how to use flutter_quality_analyzer
/// programmatically in your own Dart code.
///
/// To run this example:
///   dart run example/example.dart
///
/// Or use the CLI directly (after `dart pub global activate flutter_quality_analyzer`):
///   fqa --path /path/to/your/flutter_project
///   fqa --path . --verbose
///   fqa --path . --format json
void main() async {
  // ─── 1. Read pubspec.yaml from a Flutter project ──────────────────────────
  final reader = PubspecReader();
  final result = reader.read('.');   // '.' = current directory

  if (result.isFailure) {
    Logger.error(result.error!);
    return;
  }

  final pubspec = result.value!;
  Logger.info('Project : ${pubspec.projectName}');
  Logger.info('Found   : ${pubspec.dependencies.length} dependencies');

  if (pubspec.dependencies.isEmpty) {
    Logger.warn('No dependencies to analyze.');
    return;
  }

  // ─── 2. Fetch latest versions from pub.dev ────────────────────────────────
  final client = PubDevClient();
  final checker = VersionChecker();

  Logger.info('Checking versions against pub.dev...');

  final results = await checker.checkAll(
    dependencies: pubspec.dependencies,
    client: client,
  );

  client.dispose();

  // ─── 3. Print results to console ─────────────────────────────────────────
  final reporter = ConsoleReporter();
  reporter.report(results);

  final outdated = results.where((r) => r.isOutdated).length;
  final upToDate = results.where((r) => !r.isOutdated && r.latestVersion != null).length;
  final failed   = results.where((r) => r.latestVersion == null).length;

  reporter.printSummary(
    total: results.length,
    outdated: outdated,
    upToDate: upToDate,
    failed: failed,
  );

  // ─── 4. Or use JsonReporter for machine-readable output ──────────────────
  // final jsonReporter = JsonReporter();
  // jsonReporter.report(results);
}
