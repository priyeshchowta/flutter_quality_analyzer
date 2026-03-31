import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_quality_analyzer/src/services/pubspec_reader.dart';
import 'package:flutter_quality_analyzer/src/services/pub_dev_client.dart';
import 'package:flutter_quality_analyzer/src/services/version_checker.dart';
import 'package:flutter_quality_analyzer/src/services/coverage_analyzer.dart';
import 'package:flutter_quality_analyzer/src/services/ai_summary_service.dart';
import 'package:flutter_quality_analyzer/src/reporters/console_reporter.dart';
import 'package:flutter_quality_analyzer/src/reporters/json_reporter.dart';
import 'package:flutter_quality_analyzer/src/utils/logger.dart';

/// flutter_quality_analyzer CLI — v2.1.1
///
/// Usage examples:
///   dart run flutter_quality_analyzer
///   dart run flutter_quality_analyzer --coverage
///   dart run flutter_quality_analyzer --ai-summary --gemini-key YOUR_KEY
///   dart run flutter_quality_analyzer --coverage --ai-summary --gemini-key YOUR_KEY
///   dart run flutter_quality_analyzer --path /other/project --coverage
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'path',
      abbr: 'p',
      // Defaults to current working directory — which is the user's
      // Flutter project root when run via `dart run flutter_quality_analyzer`
      defaultsTo: Directory.current.path,
      help: 'Path to the Flutter project directory. '
          'Defaults to current directory.',
    )
    ..addOption(
      'format',
      abbr: 'f',
      defaultsTo: 'console',
      allowed: ['console', 'json'],
      allowedHelp: {
        'console': 'Colored table output (default)',
        'json': 'Machine-readable JSON output',
      },
      help: 'Output format',
    )
    ..addOption(
      'gemini-key',
      help: 'Gemini API key for AI summary. '
          'Can also be set via GEMINI_API_KEY environment variable. '
          'Get a free key at https://aistudio.google.com/app/apikey',
    )
    ..addOption(
      'ai-provider',
      help: 'AI provider to use (gemini | groq)',
      defaultsTo: 'gemini',
      allowed: ['gemini', 'groq'],
      allowedHelp: {
        'gemini': 'Google Gemini (default)',
        'groq': 'Groq (free, fast)',
      },
    )
    ..addOption(
      'groq-key',
      help: 'Groq API key. Get a free key at https://console.groq.com',
    )
    ..addFlag(
      'coverage',
      abbr: 'c',
      defaultsTo: false,
      negatable: false,
      help: 'Analyze test coverage (counts test files vs source files)',
    )
    ..addFlag(
      'ai-summary',
      abbr: 'a',
      defaultsTo: false,
      negatable: false,
      help: 'Generate AI health summary',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      negatable: false,
      help: 'Enable verbose/debug logging',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      defaultsTo: false,
      negatable: false,
      help: 'Show usage information',
    );

  late final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    Logger.error('Invalid arguments: $e');
    print(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    _printBanner();
    print(parser.usage);
    exit(0);
  }

  // Use current working directory as default path.
  // When user runs `dart run flutter_quality_analyzer` from inside
  // their Flutter project, this automatically points to their project.
  final projectPath = args['path'] as String;
  final format      = args['format'] as String;
  final verbose     = args['verbose'] as bool;
  final doCoverage  = args['coverage'] as bool;
  final doAiSummary = args['ai-summary'] as bool;

  // ✅ ADD THIS
  final aiProvider = args['ai-provider'] as String;
  final groqKey    = args['groq-key'] as String?;

  final geminiKey = (args['gemini-key'] as String?)?.trim().isNotEmpty == true
      ? args['gemini-key'] as String
      : Platform.environment['GEMINI_API_KEY'] ?? '';

  Logger.isVerbose = verbose;

  if (format == 'console') _printBanner();

  final pubspecResult = PubspecReader().read(projectPath);
  if (pubspecResult.isFailure) {
    Logger.error(pubspecResult.error!);
    Logger.error(
      'Make sure you run this command from inside your Flutter project, '
      'or pass the correct path with --path /your/project',
    );
    exit(1);
  }

  final pubspec = pubspecResult.value!;

  if (format == 'console') {
    Logger.info('Project  : ${pubspec.projectName}');
    Logger.info('Packages : ${pubspec.dependencies.length} found\n');
  }

  if (pubspec.dependencies.isEmpty) {
    Logger.warn('No dependencies found in pubspec.yaml. Exiting.');
    exit(0);
  }

  final pubDevClient = PubDevClient();
  if (format == 'console') {
    Logger.info('Fetching versions, licenses & scores from pub.dev...\n');
  }

  final results = await VersionChecker().checkAll(
    dependencies: pubspec.dependencies,
    client: pubDevClient,
  );
  pubDevClient.dispose();

  final coverage = doCoverage
      ? CoverageAnalyzer().analyze(projectPath)
      : null;

  // ─── AI Summary ─────────────────────────────────────────────
  String? aiSummary;
  if (doAiSummary) {
    if (aiProvider == 'gemini' && geminiKey.isEmpty) {
      Logger.warn('Missing --gemini-key');
    } else if (aiProvider == 'groq' &&
        (groqKey == null || groqKey.isEmpty)) {
      Logger.warn('Missing --groq-key');
      exit(1);
    } else {
      if (format == 'console') {
        Logger.info('Generating AI health summary via $aiProvider...\n');
      }

      final aiService = AiSummaryService();

      // ✅ UPDATED CALL
      final summaryResult = await aiService.generateSummary(
        projectName: pubspec.projectName,
        results: results,
        coverage: coverage ?? CoverageAnalyzer().analyze(projectPath),
        provider: aiProvider,
        geminiKey: geminiKey,
        groqKey: groqKey,
      );

      if (summaryResult.isFailure) {
        Logger.warn('AI summary failed: ${summaryResult.error}');
      } else {
        aiSummary = summaryResult.value;
      }
    }
  }

  // ─── Step 5: Report output ────────────────────────────────────────────────
  final outdated = results.where((r) => r.isOutdated).length;
  final upToDate = results.where((r) => !r.isOutdated && r.error == null).length;
  final failed   = results.where((r) => r.error != null).length;

  if (format == 'json') {
    final reporter = JsonReporter();
    reporter.report(results);
    reporter.printSummary(
      total: results.length,
      outdated: outdated,
      upToDate: upToDate,
      failed: failed,
    );
    if (coverage != null) reporter.printCoverage(coverage);
    if (aiSummary != null) reporter.printAiSummary(aiSummary);
  } else {
    final reporter = ConsoleReporter();
    reporter.report(results);
    reporter.printSummary(
      total: results.length,
      outdated: outdated,
      upToDate: upToDate,
      failed: failed,
    );
    if (coverage != null) reporter.printCoverage(coverage);
    if (aiSummary != null) reporter.printAiSummary(aiSummary);
  }

  // Non-zero exit if outdated deps exist — CI friendly
  exit(outdated > 0 ? 1 : 0);
}

void _printBanner() {
  print('''
╔══════════════════════════════════════════════╗
║       Flutter Quality Analyzer  v2.1.1       ║
║  Versions · Licenses · Coverage · AI Summary ║
╚══════════════════════════════════════════════╝
''');
}