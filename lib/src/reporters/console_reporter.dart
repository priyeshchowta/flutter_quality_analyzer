import '../models/version_check_result.dart';
import '../services/coverage_analyzer.dart';
import 'reporter.dart';

/// Renders analysis results to stdout in a clean, colored table format.
class ConsoleReporter implements Reporter {
  static const _reset  = '\x1B[0m';
  static const _bold   = '\x1B[1m';
  static const _green  = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _red    = '\x1B[31m';
  static const _cyan   = '\x1B[36m';
  static const _dim    = '\x1B[2m';
  static const _blue   = '\x1B[34m';

  @override
  void report(List<VersionCheckResult> results) {
    if (results.isEmpty) {
      print('No results to display.');
      return;
    }

    final packageWidth = _maxWidth(results.map((r) => r.packageName), min: 20, header: 'PACKAGE');
    final currentWidth = _maxWidth(results.map((r) => r.currentConstraint ?? '-'), min: 12, header: 'CURRENT');
    final latestWidth  = _maxWidth(results.map((r) => r.latestVersion ?? '-'), min: 10, header: 'LATEST');
    final licenseWidth = _maxWidth(results.map((r) => r.license ?? '-'), min: 10, header: 'LICENSE');

    _printDivider(packageWidth, currentWidth, latestWidth, licenseWidth);
    _printRow(
      pkg: '${_bold}${_cyan}PACKAGE$_reset',
      current: '${_bold}${_cyan}CURRENT$_reset',
      latest: '${_bold}${_cyan}LATEST$_reset',
      license: '${_bold}${_cyan}LICENSE$_reset',
      points: '${_bold}${_cyan}PTS$_reset',
      pop: '${_bold}${_cyan}POP$_reset',
      status: '${_bold}${_cyan}STATUS$_reset',
      pkgW: packageWidth, curW: currentWidth,
      latW: latestWidth,  licW: licenseWidth,
    );
    _printDivider(packageWidth, currentWidth, latestWidth, licenseWidth);

    for (final r in _sortResults(results)) {
      _printResultRow(r, packageWidth, currentWidth, latestWidth, licenseWidth);
    }

    _printDivider(packageWidth, currentWidth, latestWidth, licenseWidth);
    print('');
  }

  @override
  void printSummary({
    required int total,
    required int outdated,
    required int upToDate,
    required int failed,
  }) {
    print('${_bold}── Dependency Summary ───────────────────$_reset');
    print('  Total checked : $total');
    print('  $_green✔ Up to date$_reset   : $upToDate');
    print('  ${_red}✖ Outdated$_reset    : $outdated');
    if (failed > 0) print('  ${_yellow}⚠ Failed$_reset      : $failed');
    print('');
    if (outdated > 0) {
      print('${_yellow}Run `dart pub upgrade` to update your dependencies.$_reset');
    } else if (outdated == 0 && failed == 0) {
      print('${_green}All dependencies are up to date! 🎉$_reset');
    }
    print('');
  }

  /// Prints the test coverage section.
  void printCoverage(CoverageResult coverage) {
    print('${_bold}── Test Coverage ────────────────────────$_reset');

    final gradeColor = _gradeColor(coverage.grade);

    print('  Test files   : ${coverage.testFileCount}');
    print('  Source files : ${coverage.sourceFileCount}');
    print(
      '  Ratio        : ${(coverage.coverageRatio * 100).toStringAsFixed(0)}%',
    );
    print('  Grade        : $gradeColor${coverage.grade}$_reset');

    if (coverage.testFileCount > 0) {
      print('  Test files found:');
      for (final f in coverage.testFiles) {
        print('    $_dim• $f$_reset');
      }
    } else {
      print('  ${_yellow}⚠ No test files found. Consider adding tests.$_reset');
    }
    print('');
  }

  /// Prints the AI-generated summary section.
  void printAiSummary(String summary) {
    print('${_bold}── AI Health Summary (Gemini) ───────────$_reset');
    print('');
    // Indent each line for clean formatting
    for (final line in summary.split('\n')) {
      print('  $line');
    }
    print('');
  }

  // ────────────────────────────────────────
  // Private helpers
  // ────────────────────────────────────────

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
    int pkgW, int curW, int latW, int licW,
  ) {
    final String statusLabel;
    final String statusColor;
    final String pkgColor;

    if (r.error != null) {
      statusLabel = '⚠ Error';
      statusColor = _yellow;
      pkgColor    = _dim;
    } else if (r.isOutdated) {
      statusLabel = '✖ Outdated';
      statusColor = _red;
      pkgColor    = _bold;
    } else {
      statusLabel = '✔ Up to date';
      statusColor = _green;
      pkgColor    = '';
    }

    final points = r.pubPoints != null ? '${r.pubPoints}' : '-';
    final pop    = r.popularity != null ? '${r.popularity}%' : '-';

    _printRow(
      pkg: '$pkgColor${r.packageName}$_reset',
      current: r.currentConstraint ?? '$_dim-$_reset',
      latest: r.latestVersion ?? '$_dim-$_reset',
      license: r.license != null
          ? '$_blue${r.license}$_reset'
          : '$_dim-$_reset',
      points: points,
      pop: pop,
      status: '$statusColor$statusLabel$_reset',
      pkgW: pkgW, curW: curW, latW: latW, licW: licW,
    );

    if (r.error != null) {
      print('    $_dim└─ ${r.error}$_reset');
    }
  }

  void _printRow({
    required String pkg,
    required String current,
    required String latest,
    required String license,
    required String points,
    required String pop,
    required String status,
    required int pkgW,
    required int curW,
    required int latW,
    required int licW,
  }) {
    print(
      '  $pkg${_sp(pkgW - _vis(pkg))}'
      '  $current${_sp(curW - _vis(current))}'
      '  $latest${_sp(latW - _vis(latest))}'
      '  $license${_sp(licW - _vis(license))}'
      '  ${_pad(points, 5)}'
      '  ${_pad(pop, 6)}'
      '  $status',
    );
  }

  void _printDivider(int pkgW, int curW, int latW, int licW) {
    final total = pkgW + curW + latW + licW + 5 + 6 + 14 + 10;
    print('  ${'─' * total}');
  }

  String _sp(int n) => ' ' * (n < 0 ? 0 : n);

  String _pad(String s, int w) => s.length >= w ? s : s + _sp(w - s.length);

  /// Strips ANSI codes to measure visible string length.
  int _vis(String s) =>
      s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').length;

  int _maxWidth(Iterable<String> values, {required int min, required String header}) {
    final maxVal = values.fold<int>(
      header.length,
      (prev, s) => s.length > prev ? s.length : prev,
    );
    return maxVal < min ? min : maxVal;
  }

  String _gradeColor(String grade) {
    switch (grade) {
      case 'Excellent': return _green;
      case 'Good':      return _cyan;
      case 'Fair':      return _yellow;
      case 'Poor':      return _red;
      default:          return _red;
    }
  }
}
