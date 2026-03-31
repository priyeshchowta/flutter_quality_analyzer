# Flutter Quality Analyzer

A Dart CLI tool that gives you a complete health report for any Flutter/Dart project — dependency versions, licenses, security vulnerabilities, discontinued packages, test coverage, and an AI-powered summary.

[![pub.dev](https://img.shields.io/pub/v/flutter_quality_analyzer.svg)](https://pub.dev/packages/flutter_quality_analyzer)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

---

## Features

| | Feature | Flag |
|---|---|---|
| 📦 | Version check — current vs latest for every dependency | *(always on)* |
| 🏷️ | License detection — SPDX identifier per package | *(always on)* |
| 📊 | pub points & popularity score | *(always on)* |
| ⛔ | Discontinued package detection with replacement hint | *(always on)* |
| 🔒 | Security vulnerability check via [OSV API](https://osv.dev/) — free, no key needed | `--security` |
| 🧪 | Test coverage analysis — file-level ratio & grade | `--coverage` |
| 🤖 | AI-powered health summary (Gemini or Groq) | `--ai-summary` |
| 🔧 | Auto-fix outdated constraints in `pubspec.yaml` | `--fix` |
| 👁️ | Dry-run preview of `--fix` changes | `--dry-run` |
| 🎨 | Colored console output or machine-readable JSON | `--format` |

---

## Installation

### Global (recommended — use from any project)

```bash
dart pub global activate flutter_quality_analyzer
```

Then run from inside any Flutter project:

```bash
fqa
```

> If `fqa` is not found, add `~/.pub-cache/bin` to your PATH:
> ```bash
> export PATH="$PATH:$HOME/.pub-cache/bin"
> ```

### As a dev dependency

```yaml
dev_dependencies:
  flutter_quality_analyzer: ^2.2.0
```

```bash
dart run flutter_quality_analyzer
```

---

## Usage

### Basic — version check, licenses, scores

```bash
fqa
fqa --path /path/to/your/flutter_project
```

### Security vulnerability check

```bash
fqa --security
```

Queries the [OSV API](https://osv.dev/) — completely free, no API key required.

### Auto-fix outdated packages

```bash
# Preview what would change (safe — doesn't write anything)
fqa --dry-run

# Apply — rewrites pubspec.yaml with ^<latestVersion> for all outdated packages
fqa --fix

# Run `dart pub get` after to apply the new constraints
dart pub get
```

### Test coverage analysis

```bash
fqa --coverage
```

Counts test files vs source files, grades the project: **Excellent / Good / Fair / Poor / None**.

### AI health summary

```bash
# Using Gemini (free key at https://aistudio.google.com/app/apikey)
fqa --ai-summary --gemini-key YOUR_KEY

# Using Groq — free, fast, no rate-limit issues (llama-3.3-70b-versatile)
fqa --ai-summary --ai-provider groq --groq-key YOUR_KEY

# Gemini with auto-fallback to Groq if rate-limited
fqa --ai-summary --gemini-key YOUR_GEMINI_KEY --groq-key YOUR_GROQ_KEY

# Set Gemini key via environment variable instead
export GEMINI_API_KEY=YOUR_KEY
fqa --ai-summary
```

### Full analysis — everything at once

```bash
fqa --coverage --security --ai-summary --ai-provider groq --groq-key YOUR_KEY
```

### JSON output (for CI / scripting)

```bash
fqa --security --format json
fqa --coverage --format json > report.json
```

### All flags

| Flag | Short | Description |
|---|---|---|
| `--path` | `-p` | Path to Flutter project (default: current directory) |
| `--format` | `-f` | Output format: `console` (default) or `json` |
| `--security` | `-s` | Check for known CVEs via OSV API |
| `--coverage` | `-c` | Analyze test file coverage |
| `--ai-summary` | `-a` | Generate AI health summary |
| `--ai-provider` | | AI provider: `gemini` (default) or `groq` |
| `--gemini-key` | | Gemini API key (or set `GEMINI_API_KEY` env var) |
| `--groq-key` | | Groq API key |
| `--fix` | | Auto-update outdated constraints in `pubspec.yaml` |
| `--dry-run` | | Preview `--fix` changes without writing to disk |
| `--verbose` | `-v` | Enable debug logging |
| `--help` | `-h` | Show usage |

---

## Sample Output

```
╔══════════════════════════════════════════════╗
║       Flutter Quality Analyzer  v2.2.1       ║
║  Versions · Licenses · Coverage · AI Summary ║
╚══════════════════════════════════════════════╝

[INFO] Project  : my_flutter_app
[INFO] Packages : 10 found

[INFO] Fetching versions, licenses & scores from pub.dev...
[INFO] Checking for known vulnerabilities via OSV...

  ──────────────────────────────────────────────────────────────────────────────────────
  PACKAGE              CURRENT       LATEST      LICENSE       PTS  POP   STATUS
  ──────────────────────────────────────────────────────────────────────────────────────
  dio                  ^4.0.0        5.9.2       MIT           160   100%  ✖ Outdated
  some_old_pkg         ^1.0.0        1.0.0       MIT            80    12%  ⛔ Discontinued
                └─ Use new_pkg instead
  bad_pkg              ^2.1.0        2.1.0       Apache-2.0    120    45%  🔒 VULN (HIGH)
  provider             ^6.0.5        6.1.5+1     MIT           150   100%  ✔ Up to date
  go_router            ^13.0.0       17.1.0      BSD-3-Clause  150   100%  ✔ Up to date
  ──────────────────────────────────────────────────────────────────────────────────────

── Dependency Summary ─────────────────────
  Total checked : 10
  ✔ Up to date   : 7
  ✖ Outdated    : 1
  ⛔ Discontinued : 1
  🔒 Vulnerable   : 1

Run `dart pub upgrade` to update your dependencies.
Or run with --fix to auto-update pubspec.yaml.

── Security ─────────────────────────────
  🔒 bad_pkg — 1 vuln(s), highest: HIGH

── Test Coverage ────────────────────────
  Test files   : 5
  Source files : 12
  Ratio        : 42%
  Grade        : Fair

── AI Health Summary (Groq) ────────────

  Health Score: 72/100 — project is mostly healthy but has one high-severity
  vulnerability and an outdated core networking package.

  Top 3 Issues:
  1. bad_pkg has a HIGH severity CVE — upgrade or replace immediately
  2. dio is 2 major versions behind (v4 → v5) with breaking API changes
  3. some_old_pkg is discontinued — migrate to new_pkg

  Top 3 Positives:
  1. 7 out of 10 dependencies are fully up to date
  2. All packages use OSI-approved licenses (MIT, BSD-3-Clause, Apache-2.0)
  3. Test coverage exists with 5 test files

  One action to take today: run `fqa --fix && dart pub get` to resolve the
  outdated constraint, then address the HIGH vulnerability in bad_pkg.
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All dependencies healthy (up to date, no vulns, none discontinued) |
| `1` | One or more outdated, discontinued, or vulnerable packages found |
| `1` | Fatal error (missing `pubspec.yaml`, invalid args, etc.) |

CI-friendly — will fail a pipeline if any issues are found.

---

## Get Free API Keys

| Provider | Free tier | Link |
|---|---|---|
| **Gemini** | 15 req/min, 1M tokens/day | https://aistudio.google.com/app/apikey |
| **Groq** | Generous free tier, fast | https://console.groq.com |
| **OSV** | Completely free, no key | https://osv.dev |

---

## Project Structure

```
flutter_quality_analyzer/
├── bin/
│   └── flutter_quality_analyzer.dart   # CLI entry point
├── lib/
│   └── src/
│       ├── models/
│       │   ├── dependency_info.dart
│       │   ├── pubspec_data.dart
│       │   ├── result.dart
│       │   ├── version_check_result.dart
│       │   └── vulnerability_result.dart   # OSV vulnerability model
│       ├── services/
│       │   ├── pubspec_reader.dart
│       │   ├── pub_dev_client.dart          # version, license, score, discontinued
│       │   ├── version_checker.dart
│       │   ├── osv_client.dart              # OSV batch security check
│       │   ├── fix_service.dart             # pubspec.yaml auto-fix
│       │   ├── coverage_analyzer.dart
│       │   ├── ai_summary_service.dart      # provider routing + fallback
│       │   ├── ai_provider.dart             # abstract interface
│       │   ├── ai_provider_factory.dart
│       │   ├── gemini_provider.dart
│       │   └── groq_provider.dart
│       ├── reporters/
│       │   ├── console_reporter.dart
│       │   ├── json_reporter.dart
│       │   └── reporter.dart
│       └── utils/
│           ├── logger.dart
│           └── version_utils.dart
└── test/
    └── flutter_quality_analyzer_test.dart
```

---

## Dependencies

| Package | Purpose |
|---|---|
| `args` | CLI argument parsing |
| `http` | HTTP calls to pub.dev, OSV, and AI APIs |
| `yaml` | Parsing `pubspec.yaml` |
| `pub_semver` | Semver constraint comparison |
| `ansi_styles` | Terminal colour output |


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
