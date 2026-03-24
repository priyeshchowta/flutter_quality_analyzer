import 'package:flutter_quality_analyzer/src/reporters/console_reporter.dart';
import 'package:flutter_quality_analyzer/src/services/coverage_analyzer.dart';
import 'package:flutter_quality_analyzer/src/services/pub_dev_client.dart';
import 'package:flutter_quality_analyzer/src/services/pubspec_reader.dart';
import 'package:flutter_quality_analyzer/src/services/version_checker.dart';
import 'package:flutter_quality_analyzer/src/utils/logger.dart';

/// This example demonstrates how to use flutter_quality_analyzer
/// programmatically in your own Dart code.
///
/// To run this example:
///   dart run example/example.dart
///
/// Or use the CLI directly (after `dart pub global activate flutter_quality_analyzer`):
///   fqa --path /path/to/your/flutter_project
///   fqa --path . --coverage
///   fqa --path . --ai-summary --gemini-key YOUR_KEY
///   fqa --path . --coverage --ai-summary --gemini-key YOUR_KEY
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

  // ─── 2. Fetch versions + license + pub score from pub.dev ─────────────────
  final client  = PubDevClient();
  final checker = VersionChecker();

  Logger.info('Checking versions, licenses & scores from pub.dev...');

  final results = await checker.checkAll(
    dependencies: pubspec.dependencies,
    client: client,
  );

  client.dispose();

  // ─── 3. Analyze test coverage ─────────────────────────────────────────────
  final coverage = CoverageAnalyzer().analyze('.');

  // ─── 4. Print results to console ──────────────────────────────────────────
  final reporter = ConsoleReporter();
  reporter.report(results);

  final outdated = results.where((r) => r.isOutdated).length;
  final upToDate = results.where((r) => !r.isOutdated && r.error == null).length;
  final failed   = results.where((r) => r.error != null).length;

  reporter.printSummary(
    total: results.length,
    outdated: outdated,
    upToDate: upToDate,
    failed: failed,
  );

  reporter.printCoverage(coverage);

  // ─── 5. Optional: AI summary via Gemini (needs free API key) ──────────────
  // Get free key at: https://aistudio.google.com/app/apikey
  //
  // final aiService = AiSummaryService();
  // final summaryResult = await aiService.generateSummary(
  //   apiKey: 'YOUR_GEMINI_API_KEY',
  //   projectName: pubspec.projectName,
  //   results: results,
  //   coverage: coverage,
  // );
  // aiService.dispose();
  //
  // if (summaryResult.isSuccess) {
  //   reporter.printAiSummary(summaryResult.value!);
  // }

  // ─── 6. Or use JsonReporter for machine-readable output ───────────────────
  // final jsonReporter = JsonReporter();
  // jsonReporter.report(results);
  // jsonReporter.printCoverage(coverage);
}
