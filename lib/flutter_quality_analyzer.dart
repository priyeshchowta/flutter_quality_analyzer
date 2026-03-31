import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_quality_analyzer/src/models/version_check_result.dart';
import 'package:flutter_quality_analyzer/src/reporters/console_reporter.dart';
import 'package:flutter_quality_analyzer/src/reporters/json_reporter.dart';
import 'package:flutter_quality_analyzer/src/services/ai_summary_service.dart';
import 'package:flutter_quality_analyzer/src/services/coverage_analyzer.dart';
import 'package:flutter_quality_analyzer/src/services/fix_service.dart';
import 'package:flutter_quality_analyzer/src/services/osv_client.dart';
import 'package:flutter_quality_analyzer/src/services/pub_dev_client.dart';
import 'package:flutter_quality_analyzer/src/services/pubspec_reader.dart';
import 'package:flutter_quality_analyzer/src/services/version_checker.dart';
import 'package:flutter_quality_analyzer/src/utils/logger.dart';

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
      help: 'Analyze test coverage (file-level)',
    )
    ..addFlag(
      'ai-summary',
      abbr: 'a',
      defaultsTo: false,
      negatable: false,
      help: 'Generate AI-powered health summary',
    )
    ..addFlag(
      'security',
      abbr: 's',
      defaultsTo: false,
      negatable: false,
      help: 'Check for known CVEs via OSV API (free, no key needed)',
    )
    ..addFlag(
      'fix',
      defaultsTo: false,
      negatable: false,
      help: 'Auto-update outdated version constraints in pubspec.yaml',
    )
    ..addFlag(
      'dry-run',
      defaultsTo: false,
      negatable: false,
      help: 'Preview --fix changes without writing to pubspec.yaml',
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

  final projectPath = args['path'] as String;
  final format      = args['format'] as String;
  final verbose     = args['verbose'] as bool;
  final doCoverage  = args['coverage'] as bool;
  final doAiSummary = args['ai-summary'] as bool;
  final doSecurity  = args['security'] as bool;
  final doFix       = args['fix'] as bool;
  final dryRun      = args['dry-run'] as bool;

  final geminiKey  = args['gemini-key'] as String? ?? '';
  final aiProvider = args['ai-provider'] as String;
  final groqKey    = args['groq-key'] as String?;

  Logger.isVerbose = verbose;

  if (format == 'console') _printBanner();

  // ─── Read pubspec.yaml ────────────────────────────────────────────────────
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

  // ─── Version check + license + score ─────────────────────────────────────
  final pubDevClient = PubDevClient();
  if (format == 'console') {
    Logger.info('Fetching versions, licenses & scores from pub.dev...\n');
  }

  final results = await VersionChecker().checkAll(
    dependencies: pubspec.dependencies,
    client: pubDevClient,
  );
  pubDevClient.dispose();

  // ─── Security check (OSV) ────────────────────────────────────────────────
  List<VersionCheckResult> checkedResults = results;
  if (doSecurity) {
    if (format == 'console') {
      Logger.info('Checking for known vulnerabilities via OSV...\n');
    }
    final osvMap = await OsvClient().checkAll(results);
    checkedResults = results.map((r) {
      final vuln = osvMap[r.packageName];
      if (vuln == null) return r;
      return r.copyWith(
        vulnerabilityCount: vuln.vulnerabilities.length,
        highestSeverity: vuln.hasVulnerabilities ? vuln.highestSeverity : null,
      );
    }).toList().cast<VersionCheckResult>();
  }

  // ─── Test coverage ────────────────────────────────────────────────────────
  final coverage = doCoverage
      ? CoverageAnalyzer().analyze(projectPath)
      : null;

  // ─── AI Summary ───────────────────────────────────────────────────────────
  String? aiSummary;
  if (doAiSummary) {
    if (aiProvider == 'gemini' && geminiKey.isEmpty) {
      Logger.warn('--ai-summary requires --gemini-key');
    } else if (aiProvider == 'groq' && (groqKey == null || groqKey.isEmpty)) {
      Logger.warn('--ai-provider groq requires --groq-key');
      exit(1);
    } else {
      if (format == 'console') {
        Logger.info('Generating AI health summary via $aiProvider...\n');
      }

      final summaryResult = await AiSummaryService().generateSummary(
        projectName: pubspec.projectName,
        results: checkedResults,
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

  // ─── Report ───────────────────────────────────────────────────────────────
  final outdated     = checkedResults.where((r) => r.isOutdated).length;
  final upToDate     = checkedResults.where((r) => !r.isOutdated && r.error == null && !r.isDiscontinued).length;
  final failed       = checkedResults.where((r) => r.error != null).length;
  final discontinued = checkedResults.where((r) => r.isDiscontinued).length;
  final vulnerable   = checkedResults.where((r) => (r.vulnerabilityCount ?? 0) > 0).length;

  if (format == 'json') {
    final reporter = JsonReporter();
    reporter.report(checkedResults);
    reporter.printSummary(
      total: checkedResults.length,
      outdated: outdated,
      upToDate: upToDate,
      failed: failed,
      discontinued: discontinued,
      vulnerable: vulnerable,
    );
    if (coverage != null) reporter.printCoverage(coverage);
    if (aiSummary != null) reporter.printAiSummary(aiSummary);
  } else {
    final reporter = ConsoleReporter();
    reporter.report(checkedResults);
    reporter.printSummary(
      total: checkedResults.length,
      outdated: outdated,
      upToDate: upToDate,
      failed: failed,
      discontinued: discontinued,
      vulnerable: vulnerable,
    );
    if (doSecurity) reporter.printSecurity(checkedResults);
    if (coverage != null) reporter.printCoverage(coverage);
    if (aiSummary != null) reporter.printAiSummary(aiSummary, provider: aiProvider);
  }

  // ─── Fix ─────────────────────────────────────────────────────────────────
  if (doFix || dryRun) {
    final fixResult = FixService().fix(
      projectPath: projectPath,
      results: checkedResults,
      dryRun: dryRun,
    );
    if (format == 'console') {
      if (fixResult.isSuccess) {
        ConsoleReporter().printFixResult(fixResult.value!, dryRun: dryRun);
      } else {
        Logger.error('Fix failed: ${fixResult.error}');
      }
    }
  }

  exit((outdated + discontinued + vulnerable) > 0 ? 1 : 0);
}

void _printBanner() {
  print('''
╔══════════════════════════════════════════════╗
║       Flutter Quality Analyzer  v2.2.1       ║
║  Versions · Licenses · Coverage · AI Summary ║
╚══════════════════════════════════════════════╝
''');
}