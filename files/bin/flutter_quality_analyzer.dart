import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_quality_analyzer/src/services/pubspec_reader.dart';
import 'package:flutter_quality_analyzer/src/services/pub_dev_client.dart';
import 'package:flutter_quality_analyzer/src/services/version_checker.dart';
import 'package:flutter_quality_analyzer/src/reporters/console_reporter.dart';
import 'package:flutter_quality_analyzer/src/reporters/json_reporter.dart';
import 'package:flutter_quality_analyzer/src/reporters/reporter.dart';
import 'package:flutter_quality_analyzer/src/utils/logger.dart';

/// Entry point for the flutter_quality_analyzer CLI tool.
///
/// Usage:
///   dart run bin/flutter_quality_analyzer.dart [options]
///
/// Options:
///   --path    (-p)  Path to the Flutter project directory (default: current directory)
///   --format  (-f)  Output format: console (default) or json
///   --verbose (-v)  Enable verbose/debug logging
///   --help    (-h)  Show usage information
void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'path',
      abbr: 'p',
      defaultsTo: '.',
      help: 'Path to the Flutter project directory containing pubspec.yaml',
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
  final format = args['format'] as String;
  final verbose = args['verbose'] as bool;

  Logger.isVerbose = verbose;

  // Only print banner for console format — keep JSON stdout clean for piping
  if (format == 'console') _printBanner();

  // --- Step 1: Read pubspec.yaml ---
  final pubspecReader = PubspecReader();
  final pubspecResult = pubspecReader.read(projectPath);

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
    Logger.warn('No dependencies found in pubspec.yaml. Exiting.');
    exit(0);
  }

  // --- Step 2: Fetch latest versions from pub.dev ---
  final pubDevClient = PubDevClient();
  final versionChecker = VersionChecker();

  if (format == 'console') {
    Logger.info('Fetching latest versions from pub.dev...\n');
  }

  final results = await versionChecker.checkAll(
    dependencies: pubspec.dependencies,
    client: pubDevClient,
  );

  pubDevClient.dispose();

  // --- Step 3: Render output ---
  final Reporter reporter =
      format == 'json' ? JsonReporter() : ConsoleReporter();

  reporter.report(results);

  final outdated = results.where((r) => r.isOutdated).length;
  final upToDate =
      results.where((r) => !r.isOutdated && r.latestVersion != null).length;
  final failed = results.where((r) => r.latestVersion == null).length;

  reporter.printSummary(
    total: results.length,
    outdated: outdated,
    upToDate: upToDate,
    failed: failed,
  );

  // Non-zero exit if outdated deps exist — makes this CI-friendly
  exit(outdated > 0 ? 1 : 0);
}

void _printBanner() {
  print('''
╔══════════════════════════════════════════════╗
║       Flutter Quality Analyzer  v1.0.0       ║
║       Dependency Health Check Tool           ║
╚══════════════════════════════════════════════╝
''');
}
