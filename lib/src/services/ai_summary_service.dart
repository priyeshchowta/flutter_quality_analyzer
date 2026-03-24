import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/version_check_result.dart';
import '../models/result.dart';
import '../utils/logger.dart';
import 'coverage_analyzer.dart';

/// AI-powered project health summary using Google Gemini API (free tier).
///
/// Get your free API key at: https://aistudio.google.com/app/apikey
/// Free quota: 15 requests/minute, 1 million tokens/day.
class AiSummaryService {
  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  static const _timeout    = Duration(seconds: 30);
  static const _maxRetries = 3;

  final http.Client _httpClient;

  AiSummaryService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Generates an AI-powered health summary for the project.
  ///
  /// Automatically retries up to [_maxRetries] times on rate limit (429).
  Future<Result<String>> generateSummary({
    required String apiKey,
    required String projectName,
    required List<VersionCheckResult> results,
    required CoverageResult coverage,
  }) async {
    if (apiKey.isEmpty) {
      return Result.failure(
        'Gemini API key is missing.\n'
        '  Option 1: Pass via --gemini-key YOUR_KEY\n'
        '  Option 2: export GEMINI_API_KEY=YOUR_KEY\n'
        '  Get a free key at: https://aistudio.google.com/app/apikey',
      );
    }

    final prompt = _buildPrompt(
      projectName: projectName,
      results: results,
      coverage: coverage,
    );

    // Retry loop with exponential backoff for rate limit handling
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      Logger.debug('Gemini request attempt $attempt of $_maxRetries...');

      final result = await _sendRequest(apiKey, prompt);

      // Success — return immediately
      if (result.isSuccess) return result;

      // Rate limited — wait and retry
      if (result.error!.contains('rate limit') || result.error!.contains('429')) {
        if (attempt < _maxRetries) {
          final waitSeconds = attempt * 30; // 30s, 60s, 90s
          Logger.warn(
            'Gemini rate limit hit. '
            'Retrying in ${waitSeconds}s... '
            '(attempt $attempt/$_maxRetries)',
          );
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }
      }

      // Non-retryable error — return immediately
      return result;
    }

    return Result.failure(
      'Gemini rate limit persists after $_maxRetries attempts. '
      'Please wait a minute and try again.',
    );
  }

  /// Sends a single request to the Gemini API.
  Future<Result<String>> _sendRequest(String apiKey, String prompt) async {
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

      Logger.debug('Gemini HTTP status: ${response.statusCode}');

      if (response.statusCode == 401) {
        return Result.failure(
          'Invalid Gemini API key. '
          'Get a free key at https://aistudio.google.com/app/apikey',
        );
      }

      if (response.statusCode == 429) {
        return Result.failure('rate limit 429');
      }

      if (response.statusCode != 200) {
        return Result.failure('Gemini API error: HTTP ${response.statusCode}');
      }

      return _parseResponse(response.body);
    } on Exception catch (e) {
      return Result.failure('Failed to reach Gemini API: $e');
    }
  }

  /// Parses the Gemini JSON response and extracts generated text.
  ///
  /// Response shape:
  /// ```json
  /// {
  ///   "candidates": [
  ///     { "content": { "parts": [ { "text": "..." } ] } }
  ///   ]
  /// }
  /// ```
  Result<String> _parseResponse(String body) {
    try {
      final json       = jsonDecode(body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;

      if (candidates == null || candidates.isEmpty) {
        return Result.failure('Gemini returned no candidates.');
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts   = content?['parts'] as List<dynamic>?;
      final text    = parts?[0]['text'] as String?;

      if (text == null || text.isEmpty) {
        return Result.failure('Gemini returned empty response.');
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
    final failed   = results.where((r) => r.error != null).toList();

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

    final licenses = results
        .where((r) => r.license != null)
        .map((r) => r.license!)
        .toSet()
        .join(', ');

    return '''
You are a Flutter/Dart project health expert. Analyze this project and give a concise, actionable report.

PROJECT: $projectName

DEPENDENCY SUMMARY:
- Total: ${results.length} | Outdated: ${outdated.length} | Failed: ${failed.length}

PACKAGES:
${depDetails.toString()}
LICENSES: ${licenses.isEmpty ? "none detected" : licenses}

TEST COVERAGE:
- Has tests: ${coverage.hasTestDirectory}
- Test files: ${coverage.testFileCount} / Source files: ${coverage.sourceFileCount}
- Ratio: ${(coverage.coverageRatio * 100).toStringAsFixed(0)}% | Grade: ${coverage.grade}

Provide exactly:
1. Health Score: X/100 — one sentence reason
2. Top 3 Issues: specific package names where relevant
3. Top 3 Positives
4. One action to take today

Plain text only, no markdown, under 250 words.
''';
  }

  void dispose() => _httpClient.close();
}
