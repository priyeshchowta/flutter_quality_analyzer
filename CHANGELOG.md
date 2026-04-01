# Changelog

All notable changes to `flutter_quality_analyzer` are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [2.2.2] - 2026-04-01

### Fixed
- Shortened package description in `pubspec.yaml` to satisfy pub.dev limits
- Removed invalid `homepage` and `repository` URLs from `pubspec.yaml`
- Added top-level `example/flutter_quality_analyzer_example.dart` so pub.dev detects an example

## [2.2.1] - 2026-03-31

### Changed
- Completely rewrote README to showcase all v2.2.0 features: sample output table,
  full command reference, security / fix / discontinued / AI provider examples,
  API key setup links, and exit-code table
- Updated `pubspec.yaml` description to reflect the full current feature set

## [2.2.0] - 2026-03-31

### Added
- **Discontinued package detection** — pub.dev `isDiscontinued` flag is now
  checked for every package; discontinued packages are shown as `⛔ Discontinued`
  in the table with a `→ use <replacement>` hint when available
- **Security vulnerability check (`--security` / `-s`)** — queries the free
  [OSV API](https://osv.dev/) (no key needed) in a single batch request;
  vulnerable packages are flagged as `🔒 VULN (HIGH)` in the table with severity
  graded from CVSSv3 scores (CRITICAL / HIGH / MEDIUM / LOW); a dedicated
  Security section is printed in the console summary
- **Auto-fix outdated constraints (`--fix`)** — rewrites version constraints
  for all outdated packages in `pubspec.yaml` to `^<latestVersion>` in-place,
  preserving all comments and formatting; run `dart pub get` afterwards to apply
- **Dry-run mode (`--dry-run`)** — preview `--fix` changes without writing
  to disk; prints exactly which constraints would be updated
- `VulnerabilityResult` and `Vulnerability` models in `src/models/`
- `OsvClient` service in `src/services/` (batch OSV API, no key required)
- `FixService` service in `src/services/` (in-place pubspec.yaml rewrite)
- Summary now shows `⛔ Discontinued` and `🔒 Vulnerable` counts
- CI exit code now non-zero when discontinued or vulnerable packages are found

### Changed
- `ConsoleReporter.printSummary` gains `discontinued` and `vulnerable` named params
- `JsonReporter.printSummary` gains `discontinued` and `vulnerable` named params
- `JsonReporter._resultToMap` includes `isDiscontinued`, `replacedBy`,
  `vulnerabilityCount`, `highestSeverity` fields
- Table STATUS column prioritises: Error → Discontinued → Vulnerable → Outdated → OK

## [2.1.1] - 2026-03-31

### Fixed
- Groq AI summary was failing with `error 400`: switched from deprecated
  `llama3-70b-8192` (8k context) to `llama-3.3-70b-versatile` (131k context)
- AI prompt now trims large package lists: outdated + failed packages are always
  included; up-to-date packages capped at 15 to keep token usage lean across
  all providers
- Groq error responses now surface the actual error message from the API body
  instead of just the HTTP status code, making failures easier to diagnose

## [2.1.0] - 2026-03-31

### Added
- Groq AI provider support (`--ai-provider groq --groq-key YOUR_KEY`) as a free
  alternative to Gemini — uses `llama-3.3-70b-versatile` via the OpenAI-compatible API
- `--ai-provider` CLI flag (`gemini` | `groq`, default: `gemini`) with validation
- Automatic Gemini → Groq fallback: if Gemini returns a rate-limit error and a
  `--groq-key` is also supplied, the summary is retried with Groq transparently
- `AiProvider` abstract interface for provider-agnostic AI calls
- `AiProviderFactory` — factory that instantiates the correct provider by name
- `GeminiProvider` — extracted Gemini logic from `AiSummaryService` into its own class
- `GroqProvider` — new Groq implementation

### Fixed
- LICENSE column was always `-`: pub.dev removed the `license` field from
  `latest.pubspec`; license is now correctly parsed from the `tags` array in
  the score endpoint (e.g. `license:mit` → `MIT`, `license:bsd-3-clause` → `BSD-3-Clause`)
- Popularity score (`POP`) was always `?`: `popularityScore` was removed from
  the pub.dev API; popularity is now derived from `downloadCount30Days`
  (scaled to 0–100, where 1 M+ downloads = 100%)
- `--ai-provider` flag now validates allowed values (`gemini` | `groq`); invalid
  values previously silently fell through to Gemini
- Missing AI key now exits with code 1 instead of silently returning

### Changed
- `AiSummaryService.generateSummary` signature updated: replaced single `apiKey`
  param with `provider`, `geminiKey`, and `groqKey` params
- `AiSummaryService` no longer owns an `http.Client` — each provider manages its own
- Removed `AiSummaryService.dispose()` (no longer needed)
- Banner and help text updated to reflect multi-provider support

## [2.0.1] - 2024-01-04

### Fixed
- LICENSE column now correctly fetched from `latest.pubspec.license` field
- Popularity score (`POP`) now correctly parsed from pub.dev score API
- Version comparison now handles build metadata (e.g. `6.1.5+1`) correctly
- Gemini rate limit now retries automatically (up to 3 times, 30s apart)
  instead of failing immediately

## [2.0.0] - 2024-01-03

### Added
- License detection — fetched from pub.dev API for every package
- pub points and popularity score columns in output table
- Like count from pub.dev
- Test coverage analyzer — counts test files vs source files, grades the project
- AI-powered health summary using Google Gemini API (free tier)
- New CLI flags: `--coverage`, `--ai-summary`, `--gemini-key`
- `VersionCheckResult.copyWith()` for immutable field updates

### Changed
- `PubDevClient.fetchLatestVersion` renamed to `fetchPackageInfo` (fetches more data)
- Output table now shows LICENSE, PTS (pub points), POP (popularity) columns
- Banner updated to v2.0.0

## [1.0.1] - 2024-01-02

### Fixed
- Fixed dartdoc angle bracket HTML warning in Result<T> comments
- Added example/example.dart for pub.dev package score
- Fixed placeholder GitHub URL in pubspec.yaml

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Dependency version checking via pub.dev API
- Colored console output and JSON output
- `fqa` global executable
