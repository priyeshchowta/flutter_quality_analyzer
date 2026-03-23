/// A simple leveled logger for CLI output.
///
/// Supports INFO, WARN, ERROR, and DEBUG (verbose) levels.
/// DEBUG messages are only printed when [isVerbose] is true.
///
/// All log methods are static for convenience — no instantiation needed.
class Logger {
  static const _reset = '\x1B[0m';
  static const _bold = '\x1B[1m';
  static const _yellow = '\x1B[33m';
  static const _red = '\x1B[31m';
  static const _dim = '\x1B[2m';
  static const _cyan = '\x1B[36m';

  /// Set to true to enable debug-level output.
  static bool isVerbose = false;

  /// Informational message (always shown).
  static void info(String message) {
    print('$_cyan[INFO]$_reset $message');
  }

  /// Warning message (always shown).
  static void warn(String message) {
    print('$_yellow${_bold}[WARN]$_reset $message');
  }

  /// Error message (always shown). Writes to stderr.
  static void error(String message) {
    // ignore: avoid_print
    print('$_red${_bold}[ERROR]$_reset $message');
  }

  /// Debug message (only shown if [isVerbose] == true).
  static void debug(String message) {
    if (!isVerbose) return;
    print('$_dim[DEBUG] $message$_reset');
  }
}
