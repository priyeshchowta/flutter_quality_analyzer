# Flutter Quality Analyzer

A Dart CLI tool that analyzes a Flutter/Dart project's `pubspec.yaml` and reports dependency health — showing current vs. latest version for every package.

---

## Features

- 📦 Reads `dependencies` and `dev_dependencies` from `pubspec.yaml`
- 🌐 Fetches latest versions from the [pub.dev API](https://pub.dev/help/api)
- 🔍 Compares version constraints (handles `^`, `>=`, `~`, etc.)
- 🎨 Clean colored terminal output
- ⚡ Concurrent requests (batched, rate-limit safe)
- 🔧 Graceful error handling for network failures
- 🏗️ Extensible architecture (ready for license detection, test coverage, AI summaries)

---

## Project Structure

```
flutter_quality_analyzer/
├── bin/
│   └── flutter_quality_analyzer.dart   # Entry point / CLI arg parsing
├── lib/
│   ├── flutter_quality_analyzer.dart   # Barrel exports
│   └── src/
│       ├── models/
│       │   ├── dependency_info.dart     # Single dependency from pubspec
│       │   ├── pubspec_data.dart        # Parsed pubspec.yaml content
│       │   ├── result.dart              # Generic Result<T> type
│       │   └── version_check_result.dart
│       ├── services/
│       │   ├── pubspec_reader.dart      # Reads + parses pubspec.yaml
│       │   ├── pub_dev_client.dart      # HTTP client for pub.dev API
│       │   └── version_checker.dart    # Orchestrates checks, concurrency
│       ├── reporters/
│       │   └── console_reporter.dart   # Formatted terminal output
│       └── utils/
│           ├── logger.dart             # Leveled logger (INFO/WARN/ERROR/DEBUG)
│           └── version_utils.dart      # Pure version string helpers
├── test/
│   └── flutter_quality_analyzer_test.dart
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## Setup & Run

### 1. Get dependencies

```bash
cd flutter_quality_analyzer
dart pub get
```

### 2. Run against a Flutter project

```bash
# Analyze the current directory
dart run bin/flutter_quality_analyzer.dart

# Analyze a specific project
dart run bin/flutter_quality_analyzer.dart --path /path/to/flutter_project

# Enable verbose/debug logs
dart run bin/flutter_quality_analyzer.dart --path /path/to/project --verbose

# Show help
dart run bin/flutter_quality_analyzer.dart --help
```

### 3. Run tests

```bash
dart test
```

### 4. Compile to a standalone executable (optional)

```bash
dart compile exe bin/flutter_quality_analyzer.dart -o fqa
./fqa --path /path/to/project
```

---

## Sample Output

```
╔══════════════════════════════════════════════╗
║       Flutter Quality Analyzer  v1.0.0       ║
║       Dependency Health Check Tool           ║
╚══════════════════════════════════════════════╝

[INFO] Project: my_flutter_app
[INFO] Found 8 dependencies to analyze.

[INFO] Fetching latest versions from pub.dev...

  ────────────────────────────────────────────────────────────
  PACKAGE              CURRENT        LATEST      STATUS
  ────────────────────────────────────────────────────────────
  dio                  ^4.0.0         5.4.3       ✖ Outdated
  get                  ^4.6.5         4.6.6       ✖ Outdated
  shared_preferences   ^2.2.2         2.2.2       ✔ Up to date
  provider             ^6.1.1         6.1.2       ✖ Outdated
  ────────────────────────────────────────────────────────────

── Summary ──────────────────────────
  Total checked : 4
  ✔ Up to date  : 1
  ✖ Outdated    : 3

Run `dart pub upgrade` to update your dependencies.
```

---

## Exit Codes

| Code | Meaning                          |
|------|----------------------------------|
| 0    | All dependencies up to date      |
| 1    | One or more outdated deps found  |
| 1    | Fatal error (missing pubspec etc)|

This makes the tool CI-friendly — it will fail a pipeline if outdated deps exist.

---

## Future Scope

The architecture is designed for these upcoming features:

| Feature              | Where to add                          |
|----------------------|---------------------------------------|
| License detection    | `lib/src/services/license_checker.dart` + new model |
| Test coverage        | `lib/src/services/coverage_analyzer.dart`           |
| AI-based summary     | `lib/src/services/ai_summary_service.dart`          |
| JSON reporter        | `lib/src/reporters/json_reporter.dart`              |
| HTML reporter        | `lib/src/reporters/html_reporter.dart`              |

All reporters can share a common `Reporter` abstract interface.

---

## Dependencies Used

| Package       | Purpose                              |
|---------------|--------------------------------------|
| `args`        | CLI argument parsing                 |
| `http`        | HTTP calls to pub.dev API            |
| `yaml`        | Parsing pubspec.yaml                 |
| `pub_semver`  | Proper semver constraint comparison  |
| `ansi_styles` | Terminal color output                |
