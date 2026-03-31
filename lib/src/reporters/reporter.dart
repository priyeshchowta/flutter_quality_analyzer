import '../models/version_check_result.dart';

/// Abstract interface that all reporters must implement.
///
/// Reporters are responsible for presenting [VersionCheckResult] data
/// to the user in a specific format.
///
/// Implementations:
///   - [ConsoleReporter]  → colored terminal table (current)
///   - [JsonReporter]     → machine-readable JSON output (stub)
///
/// Future scope:
///   - HtmlReporter  → standalone HTML report
///   - CsvReporter   → spreadsheet-compatible output
abstract class Reporter {
  /// Renders the full list of [results] to the output target.
  void report(List<VersionCheckResult> results);

  /// Renders a summary (totals: outdated, up-to-date, failed).
  void printSummary({
    required int total,
    required int outdated,
    required int upToDate,
    required int failed,
    int discontinued = 0,
    int vulnerable = 0,
  });
}
