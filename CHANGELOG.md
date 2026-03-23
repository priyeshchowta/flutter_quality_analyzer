# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Read `dependencies` and `dev_dependencies` from `pubspec.yaml`
- Fetch latest versions from pub.dev API
- Compare current version constraints vs latest versions
- Colored console table output with `✔ Up to date` / `✖ Outdated` status
- JSON output format via `--format json` flag
- `--path` flag to point at any Flutter project
- `--verbose` flag for debug logging
- Batched concurrent pub.dev requests (5 at a time) to avoid rate limiting
- Graceful error handling for network failures and missing packages
- CI-friendly exit codes (exit `1` if outdated deps found)
- `fqa` global executable via `dart pub global activate`
