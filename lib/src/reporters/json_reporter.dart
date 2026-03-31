import 'dart:convert';

import '../models/version_check_result.dart';
import '../services/coverage_analyzer.dart';
import 'reporter.dart';

/// Outputs analysis results as pretty-printed JSON.
///
/// Useful for piping into other tools or CI systems.
class JsonReporter implements Reporter {
  @override
  void report(List<VersionCheckResult> results) {
    final packages = results.map(_resultToMap).toList();
    print(const JsonEncoder.withIndent('  ').convert({'packages': packages}));
  }

  @override
  void printSummary({
    required int total,
    required int outdated,
    required int upToDate,
    required int failed,
    int discontinued = 0,
    int vulnerable = 0,
  }) {
    print(const JsonEncoder.withIndent('  ').convert({
      'summary': {
        'total': total,
        'outdated': outdated,
        'upToDate': upToDate,
        'discontinued': discontinued,
        'vulnerable': vulnerable,
        'failed': failed,
      },
    }));
  }

  /// Prints the coverage result as JSON.
  void printCoverage(CoverageResult coverage) {
    print(const JsonEncoder.withIndent('  ').convert({
      'testCoverage': {
        'hasTestDirectory': coverage.hasTestDirectory,
        'testFileCount': coverage.testFileCount,
        'sourceFileCount': coverage.sourceFileCount,
        'coverageRatio': coverage.coverageRatio,
        'grade': coverage.grade,
        'testFiles': coverage.testFiles,
      },
    }));
  }

  /// Prints the AI summary as JSON.
  void printAiSummary(String summary) {
    print(const JsonEncoder.withIndent('  ').convert({
      'aiSummary': summary,
    }));
  }

  Map<String, dynamic> _resultToMap(VersionCheckResult r) {
    return {
      'name': r.packageName,
      'current': r.currentConstraint,
      'latest': r.latestVersion,
      'status': r.error != null
          ? 'error'
          : r.isDiscontinued
              ? 'discontinued'
              : r.isOutdated
                  ? 'outdated'
                  : 'up-to-date',
      'license': r.license,
      'pubPoints': r.pubPoints,
      'popularity': r.popularity,
      'likes': r.likes,
      'isDiscontinued': r.isDiscontinued,
      if (r.replacedBy != null) 'replacedBy': r.replacedBy,
      'vulnerabilityCount': r.vulnerabilityCount,
      if (r.highestSeverity != null) 'highestSeverity': r.highestSeverity,
      if (r.error != null) 'error': r.error,
    };
  }
}
