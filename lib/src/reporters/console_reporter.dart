import '../models/version_check_result.dart';
import 'reporter.dart';

/// Renders the analysis results to stdout in a clean, readable table format.
///
/// Implements [Reporter]. For machine-readable output, use [JsonReporter].
class ConsoleReporter implements Reporter {
  // ANSI color codes for terminal output
  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';
  static const _cyan = '\x1B[36m';
  static const _dim = '\x1B[2m';

  /// Prints the full results table to stdout.
  void report(List<VersionCheckResult> results) {
    if (results.isEmpty) {
      print('No results to display.');
      return;
    }

    // Calculate column widths dynamically for alignment
    final packageWidth = _maxWidth(
      results.map((r) => r.packageName),
      minimum: 20,
      header: 'PACKAGE',
    );
    final currentWidth = _maxWidth(
      results.map((r) => r.currentConstraint ?? '-'),
      minimum: 12,
      header: 'CURRENT',
    );
    final latestWidth = _maxWidth(
      results.map((r) => r.latestVersion ?? '-'),
      minimum: 10,
      header: 'LATEST',
    );

    // Header row
    _printDivider(packageWidth, currentWidth, latestWidth);
    _printRow(
      label: '${_bold}${_cyan}PACKAGE$_reset',
      current: '${_bold}${_cyan}CURRENT$_reset',
      latest: '${_bold}${_cyan}LATEST$_reset',
      status: '${_bold}${_cyan}STATUS$_reset',
      packageWidth: packageWidth,
      currentWidth: currentWidth,
      latestWidth: latestWidth,
    );
    _printDivider(packageWidth, currentWidth, latestWidth);

    // Data rows
    for (final result in _sortResults(results)) {
      _printResultRow(result, packageWidth, currentWidth, latestWidth);
    }

    _printDivider(packageWidth, currentWidth, latestWidth);
    print('');
  }

  /// Prints a summary block with counts.
  void printSummary({
    required int total,
    required int outdated,
    required int upToDate,
    required int failed,
  }) {
    print('${_bold}── Summary ──────────────────────────$_reset');
    print('  Total checked : $total');
    print('  $_green✔ Up to date$_reset   : $upToDate');
    print('  ${_red}✖ Outdated$_reset    : $outdated');
    if (failed > 0) {
      print('  ${_yellow}⚠ Failed$_reset      : $failed');
    }
    print('');

    if (outdated > 0) {
      print('${_yellow}Run `dart pub upgrade` to update your dependencies.$_reset');
    } else if (outdated == 0 && failed == 0) {
      print('${_green}All dependencies are up to date! 🎉$_reset');
    }
    print('');
  }

  // ────────────────────────────────────────
  // Private helpers
  // ────────────────────────────────────────

  /// Sorts results: outdated first, then up-to-date, then failed.
  List<VersionCheckResult> _sortResults(List<VersionCheckResult> results) {
    return [...results]..sort((a, b) {
        if (a.isOutdated && !b.isOutdated) return -1;
        if (!a.isOutdated && b.isOutdated) return 1;
        if (a.error == null && b.error != null) return -1;
        if (a.error != null && b.error == null) return 1;
        return a.packageName.compareTo(b.packageName);
      });
  }

  void _printResultRow(
    VersionCheckResult r,
    int packageWidth,
    int currentWidth,
    int latestWidth,
  ) {
    final String statusLabel;
    final String statusColor;
    final String packageColor;

    if (r.error != null) {
      statusLabel = '⚠ Error';
      statusColor = _yellow;
      packageColor = _dim;
    } else if (r.isOutdated) {
      statusLabel = '✖ Outdated';
      statusColor = _red;
      packageColor = _bold;
    } else {
      statusLabel = '✔ Up to date';
      statusColor = _green;
      packageColor = '';
    }

    _printRow(
      label: '$packageColor${r.packageName}$_reset',
      current: r.currentConstraint ?? _dim + '-$_reset',
      latest: r.latestVersion ?? _dim + '-$_reset',
      status: '$statusColor$statusLabel$_reset',
      packageWidth: packageWidth,
      currentWidth: currentWidth,
      latestWidth: latestWidth,
    );

    // Print error detail on the next line (indented), if any
    if (r.error != null) {
      print('  $_dim  └─ ${r.error}$_reset');
    }
  }

  void _printRow({
    required String label,
    required String current,
    required String latest,
    required String status,
    required int packageWidth,
    required int currentWidth,
    required int latestWidth,
  }) {
    // Padding is calculated using the *visible* length (stripped of ANSI codes)
    // so that color escape characters don't throw off column alignment.
    print(
      '  $label${_space(packageWidth - _stripAnsi(label).length)}'
      '  $current${_space(currentWidth - _stripAnsi(current).length)}'
      '  $latest${_space(latestWidth - _stripAnsi(latest).length)}'
      '  $status',
    );
  }

  void _printDivider(int packageWidth, int currentWidth, int latestWidth) {
    final total = packageWidth + currentWidth + latestWidth + 14 + 14;
    print('  ${'─' * total}');
  }

  /// Returns [n] spaces. Clamps negative values to 0.
  String _space(int n) => ' ' * (n < 0 ? 0 : n);

  /// Strips ANSI escape codes to get the visible string length.
  String _stripAnsi(String s) {
    return s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
  }

  /// Calculates the column width based on the longest string in [values],
  /// bounded by [minimum].
  int _maxWidth(
    Iterable<String> values, {
    required int minimum,
    required String header,
  }) {
    final maxVal = values.fold<int>(
      header.length,
      (prev, s) => s.length > prev ? s.length : prev,
    );
    return maxVal < minimum ? minimum : maxVal;
  }
}
