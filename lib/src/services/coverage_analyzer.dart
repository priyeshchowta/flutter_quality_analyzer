import 'dart:io';

import '../utils/logger.dart';

/// Result of the test coverage analysis for a Flutter/Dart project.
class CoverageResult {
  /// Whether a test/ directory was found
  final bool hasTestDirectory;

  /// Total number of .dart test files found
  final int testFileCount;

  /// Total number of source .dart files in lib/
  final int sourceFileCount;

  /// Names of all test files found
  final List<String> testFiles;

  /// Rough coverage ratio: testFileCount / sourceFileCount (0.0 – 1.0+)
  final double coverageRatio;

  /// Human-readable coverage grade: Excellent / Good / Fair / Poor / None
  final String grade;

  const CoverageResult({
    required this.hasTestDirectory,
    required this.testFileCount,
    required this.sourceFileCount,
    required this.testFiles,
    required this.coverageRatio,
    required this.grade,
  });
}

/// Analyzes the test coverage of a Flutter/Dart project by inspecting
/// the file system — no need to run `flutter test`.
///
/// This is a structural analysis (not line coverage). It checks:
///   - Whether a test/ directory exists
///   - How many test files (.dart) are in test/
///   - How many source files are in lib/
///   - Derives a rough coverage ratio and grade
class CoverageAnalyzer {
  /// Analyzes test coverage for the project at [projectPath].
  CoverageResult analyze(String projectPath) {
    Logger.debug('Analyzing test coverage at: $projectPath');

    final testDir = Directory('$projectPath/test');
    final libDir = Directory('$projectPath/lib');

    if (!testDir.existsSync()) {
      Logger.debug('No test/ directory found.');
      return CoverageResult(
        hasTestDirectory: false,
        testFileCount: 0,
        sourceFileCount: _countDartFiles(libDir),
        testFiles: [],
        coverageRatio: 0.0,
        grade: 'None',
      );
    }

    final testFiles = _findTestFiles(testDir);
    final sourceFileCount = _countDartFiles(libDir);
    final testFileCount = testFiles.length;

    final ratio = sourceFileCount > 0
        ? testFileCount / sourceFileCount
        : 0.0;

    final grade = _computeGrade(ratio, testFileCount);

    Logger.debug(
      'Tests: $testFileCount files | Sources: $sourceFileCount files '
      '| Ratio: ${(ratio * 100).toStringAsFixed(0)}% | Grade: $grade',
    );

    return CoverageResult(
      hasTestDirectory: true,
      testFileCount: testFileCount,
      sourceFileCount: sourceFileCount,
      testFiles: testFiles,
      coverageRatio: ratio,
      grade: grade,
    );
  }

  /// Recursively finds all *_test.dart files inside [dir].
  List<String> _findTestFiles(Directory dir) {
    if (!dir.existsSync()) return [];

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.dart'))
        .map((f) => f.uri.pathSegments.last)
        .toList()
      ..sort();
  }

  /// Counts all .dart files inside [dir] recursively.
  int _countDartFiles(Directory dir) {
    if (!dir.existsSync()) return 0;

    return dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .length;
  }

  /// Assigns a grade based on test-to-source ratio and raw test count.
  ///
  /// Grading scale:
  ///   Excellent : ratio >= 0.8 (80%+ test coverage by file count)
  ///   Good      : ratio >= 0.5
  ///   Fair      : ratio >= 0.2
  ///   Poor      : ratio > 0 but < 20%
  ///   None      : no test files at all
  String _computeGrade(double ratio, int testFileCount) {
    if (testFileCount == 0) return 'None';
    if (ratio >= 0.8) return 'Excellent';
    if (ratio >= 0.5) return 'Good';
    if (ratio >= 0.2) return 'Fair';
    return 'Poor';
  }
}
