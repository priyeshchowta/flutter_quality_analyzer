import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/version_check_result.dart';
import '../models/result.dart';
import '../utils/logger.dart';
import 'coverage_analyzer.dart';

/// AI-generated project health summary using Google Gemini API (free tier).
///
/// Get your free API key at: https://aistudio.google.com/app/apikey
/// Free quota: 15 requests/minute, 1 million tokens/day — more than enough.
class AiSummaryService {
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  static const _timeout = Duration(seconds: 30);

  final http.Client _httpClient;

  AiSummaryService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Generates an AI-powered health summary for the project.
  ///
  /// [apiKey]   - Your Gemini API key from https://aistudio.google.com
  /// [results]  - Version check results for all dependencies
  /// [coverage] - Test coverage analysis result
  /// [projectName] - Name of the Flutter project
  Future<Result<String>> generateSummary({
    required String apiKey,
    required String projectName,
    required List<VersionCheckResult> results,
    required CoverageResult coverage,
  }) async {
    if (apiKey.isEmpty) {
      return Result.failure(
        'Gemini API key is missing. '
        'Get a free key at https://aistudio.google.com/app/apikey '
        'and pass it with --gemini-key YOUR_KEY',
      );
    }

    final prompt = _buildPrompt(
      projectName: projectName,
      results: results,
      coverage: coverage,
    );

    Logger.debug('Sending prompt to Gemini...');

    try {
      final uri = Uri.parse('$_geminiUrl?key=$apiKey');

      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.4,
                'maxOutputTokens': 600,
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 401) {
        return Result.failure(
          'Invalid Gemini API key. '
          'Get a free key at https://aistudio.google.com/app/apikey',
        );
      }

      if (response.statusCode == 429) {
        return Result.failure(
          'Gemini rate limit hit. Please wait a minute and try again.',
        );
      }

      if (response.statusCode != 200) {
        return Result.failure(
          'Gemini API error: HTTP ${response.statusCode}',
        );
      }

      return _parseResponse(response.body);
    } on Exception catch (e) {
      return Result.failure('Failed to reach Gemini API: $e');
    }
  }

  /// Parses the Gemini response and extracts the generated text.
  Result<String> _parseResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;

      if (candidates == null || candidates.isEmpty) {
        return Result.failure('Gemini returned no candidates in response.');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      final text = parts?[0]['text'] as String?;

      if (text == null || text.isEmpty) {
        return Result.failure('Gemini returned empty text.');
      }

      return Result.success(text.trim());
    } catch (e) {
      return Result.failure('Failed to parse Gemini response: $e');
    }
  }

  /// Builds a structured prompt from the analysis data.
  String _buildPrompt({
    required String projectName,
    required List<VersionCheckResult> results,
    required CoverageResult coverage,
  }) {
    final outdated = results.where((r) => r.isOutdated).toList();
    final upToDate = results.where((r) => !r.isOutdated && r.error == null).toList();
    final failed = results.where((r) => r.error != null).toList();

    // Build dependency details section
    final depDetails = StringBuffer();
    for (final r in results) {
      depDetails.writeln(
        '- ${r.packageName}: '
        'current=${r.currentConstraint ?? "any"}, '
        'latest=${r.latestVersion ?? "unknown"}, '
        'outdated=${r.isOutdated}, '
        'license=${r.license ?? "unknown"}, '
        'pubPoints=${r.pubPoints ?? "?"}, '
        'popularity=${r.popularity != null ? "${r.popularity}%" : "?"}',
      );
    }

    // Build license summary
    final licenses = results
        .where((r) => r.license != null)
        .map((r) => r.license!)
        .toSet()
        .join(', ');

    return '''
You are a Flutter/Dart project health expert. Analyze the following project data and provide a concise, actionable health report.

PROJECT: $projectName

DEPENDENCY SUMMARY:
- Total packages: ${results.length}
- Outdated: ${outdated.length}
- Up to date: ${upToDate.length}
- Failed to check: ${failed.length}

DEPENDENCY DETAILS:
${depDetails.toString()}

LICENSES FOUND: ${licenses.isEmpty ? "none detected" : licenses}

TEST COVERAGE:
- Has test directory: ${coverage.hasTestDirectory}
- Test files: ${coverage.testFileCount}
- Source files: ${coverage.sourceFileCount}
- Coverage ratio: ${(coverage.coverageRatio * 100).toStringAsFixed(0)}%
- Grade: ${coverage.grade}

Please provide:
1. Overall health score (0-100) with one sentence justification
2. Top 3 most critical issues to fix (be specific, name packages)
3. Top 3 positive things about this project
4. One concrete next step the developer should take today

Keep the response concise, developer-friendly, and under 300 words.
Use plain text only — no markdown formatting.
''';
  }

  void dispose() => _httpClient.close();
}
