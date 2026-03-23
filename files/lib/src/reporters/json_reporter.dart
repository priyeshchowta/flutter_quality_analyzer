import 'dart:convert';

import '../models/version_check_result.dart';
import 'reporter.dart';

/// Outputs analysis results as a pretty-printed JSON document to stdout.
///
/// Useful for piping results into other tools or CI systems.
///
/// Example output:
/// {
///   "summary": { "total": 5, "outdated": 2, "upToDate": 3, "failed": 0 },
///   "packages": [
///     {
///       "name": "http",
///       "current": "^0.13.0",
///       "latest": "1.2.0",
///       "status": "outdated"
///     }
///   ]
/// }
class JsonReporter implements Reporter {
  @override
  void report(List<VersionCheckResult> results) {
    final packages = results.map(_resultToMap).toList();
    final output = {'packages': packages};
    print(const JsonEncoder.withIndent('  ').convert(output));
  }

  @override
  void printSummary({
    required int total,
    required int outdated,
    required int upToDate,
    required int failed,
  }) {
    final summary = {
      'summary': {
        'total': total,
        'outdated': outdated,
        'upToDate': upToDate,
        'failed': failed,
      }
    };
    print(const JsonEncoder.withIndent('  ').convert(summary));
  }

  Map<String, dynamic> _resultToMap(VersionCheckResult r) {
    return {
      'name': r.packageName,
      'current': r.currentConstraint,
      'latest': r.latestVersion,
      'status': r.error != null
          ? 'error'
          : r.isOutdated
              ? 'outdated'
              : 'up-to-date',
      if (r.error != null) 'error': r.error,
    };
  }
}
