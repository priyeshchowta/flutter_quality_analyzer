# Changelog

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
