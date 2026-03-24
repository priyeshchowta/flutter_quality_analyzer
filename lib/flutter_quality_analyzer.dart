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

/// flutter_quality_analyzer CLI — v2.0.0
///
/// Features:
///   ✔ Dependency version checks (pub.dev)
///   ✔ License detection
///   ✔ pub points + popularity scores
///   ✔ Test coverage analysis
///   ✔ AI-powered health summary (Gemini)
///
/// Usage:
///   fqa --path /your/flutter/project
///   fqa --path . --coverage
///   fqa --path . --ai-summary --gemini-key YOUR_KEY
///   fqa --path . --coverage --ai-summary --gemini-key YOUR_KEY --format json
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'path',
      abbr: 'p',
      defaultsTo: '.',
      help: 'Path to the Flutter project directory',
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
          'Get free key at https://aistudio.google.com/app/apikey',
    )
    ..addFlag(
      'coverage',
      abbr: 'c',
      defaultsTo: false,
      negatable: false,
      help: 'Analyze test coverage (file-level)',
    )
    ..addFlag(
      'ai-summary',
      abbr: 'a',
      defaultsTo: false,
      negatable: false,
      help: 'Generate AI-powered health summary using Gemini (requires --gemini-key)',
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

  final projectPath  = args['path'] as String;
  final format       = args['format'] as String;
  final verbose      = args['verbose'] as bool;
  final doCoverage   = args['coverage'] as bool;
  final doAiSummary  = args['ai-summary'] as bool;
  final geminiKey    = args['gemini-key'] as String? ?? '';

  Logger.isVerbose = verbose;

  if (format == 'console') _printBanner();

  // ─── Step 1: Read pubspec.yaml ────────────────────────────────────────────
  final pubspecResult = PubspecReader().read(projectPath);
  if (pubspecResult.isFailure) {
    Logger.error(pubspecResult.error!);
    exit(1);
  }

  final pubspec = pubspecResult.value!;

  if (format == 'console') {
    Logger.info('Project  : ${pubspec.projectName}');
    Logger.info('Packages : ${pubspec.dependencies.length} found\n');
  }

  if (pubspec.dependencies.isEmpty) {
    Logger.warn('No dependencies found. Exiting.');
    exit(0);
  }

  // ─── Step 2: Version check + license + score ─────────────────────────────
  final pubDevClient = PubDevClient();
  if (format == 'console') {
    Logger.info('Fetching versions, licenses & scores from pub.dev...\n');
  }

  final results = await VersionChecker().checkAll(
    dependencies: pubspec.dependencies,
    client: pubDevClient,
  );
  pubDevClient.dispose();

  // ─── Step 3: Test coverage ────────────────────────────────────────────────
  final coverage = doCoverage
      ? CoverageAnalyzer().analyze(projectPath)
      : null;

  // ─── Step 4: AI Summary ───────────────────────────────────────────────────
  String? aiSummary;
  if (doAiSummary) {
    if (geminiKey.isEmpty) {
      Logger.warn(
        '--ai-summary requires --gemini-key. '
        'Get a free key at https://aistudio.google.com/app/apikey',
      );
    } else {
      if (format == 'console') {
        Logger.info('Generating AI health summary via Gemini...\n');
      }

      final aiService = AiSummaryService();
      final summaryResult = await aiService.generateSummary(
        apiKey: geminiKey,
        projectName: pubspec.projectName,
        results: results,
        coverage: coverage ??
            CoverageAnalyzer().analyze(projectPath),
      );
      aiService.dispose();

      if (summaryResult.isFailure) {
        Logger.warn('AI summary failed: ${summaryResult.error}');
      } else {
        aiSummary = summaryResult.value;
      }
    }
  }

  // ─── Step 5: Report ───────────────────────────────────────────────────────
  if (format == 'json') {
    final jsonReporter = JsonReporter();
    jsonReporter.report(results);

    final outdated = results.where((r) => r.isOutdated).length;
    final upToDate = results.where((r) => !r.isOutdated && r.error == null).length;
    final failed   = results.where((r) => r.error != null).length;
    jsonReporter.printSummary(
      total: results.length,
      outdated: outdated,
      upToDate: upToDate,
      failed: failed,
    );

    if (coverage != null) jsonReporter.printCoverage(coverage);
    if (aiSummary != null) jsonReporter.printAiSummary(aiSummary);
  } else {
    final consoleReporter = ConsoleReporter();
    consoleReporter.report(results);

    final outdated = results.where((r) => r.isOutdated).length;
    final upToDate = results.where((r) => !r.isOutdated && r.error == null).length;
    final failed   = results.where((r) => r.error != null).length;
    consoleReporter.printSummary(
      total: results.length,
      outdated: outdated,
      upToDate: upToDate,
      failed: failed,
    );

    if (coverage != null) consoleReporter.printCoverage(coverage);
    if (aiSummary != null) consoleReporter.printAiSummary(aiSummary);
  }

  final outdated = results.where((r) => r.isOutdated).length;
  exit(outdated > 0 ? 1 : 0);
}

void _printBanner() {
  print('''
╔══════════════════════════════════════════════╗
║       Flutter Quality Analyzer  v2.0.0       ║
║  Versions · Licenses · Coverage · AI Summary ║
╚══════════════════════════════════════════════╝
''');
}
