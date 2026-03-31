import '../models/version_check_result.dart';
import '../models/result.dart';
import '../utils/logger.dart';
import 'coverage_analyzer.dart';

import 'ai_provider_factory.dart';

class AiSummaryService {
  /// Generates AI-powered health summary with provider + fallback support
  Future<Result<String>> generateSummary({
    required String projectName,
    required List<VersionCheckResult> results,
    required CoverageResult coverage,

    /// New params
    required String provider, // gemini | groq
    String? geminiKey,
    String? groqKey,
  }) async {
    final prompt = _buildPrompt(
      projectName: projectName,
      results: results,
      coverage: coverage,
    );

    final primaryProvider = AiProviderFactory.create(provider);

    final primaryKey = provider == 'groq' ? groqKey : geminiKey;

    if (primaryKey == null || primaryKey.isEmpty) {
      return Result.failure(
        'Missing API key for $provider.\n'
        'Use --gemini-key or --groq-key',
      );
    }

    Logger.info('Using $provider AI provider...');

    final result = await primaryProvider.generateSummary(
      prompt: prompt,
      apiKey: primaryKey,
    );

    // 🔥 FALLBACK: Gemini → Groq
    if (!result.isSuccess &&
        result.error == 'RATE_LIMIT' &&
        provider == 'gemini' &&
        groqKey != null &&
        groqKey.isNotEmpty) {
      Logger.warn('Gemini rate limited → switching to Groq...');

      final fallbackProvider = AiProviderFactory.create('groq');

      final fallbackResult = await fallbackProvider.generateSummary(
        prompt: prompt,
        apiKey: groqKey,
      );

      if (fallbackResult.isSuccess) {
        Logger.info('Groq summary generated successfully');
      } else {
        Logger.error('Groq also failed: ${fallbackResult.error}');
      }

      return fallbackResult;
    }

    return result;
  }

  /// Builds structured prompt for AI analysis
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
}