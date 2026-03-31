import '../models/result.dart';

abstract class AiProvider {
  Future<Result<String>> generateSummary({
    required String prompt,
    required String apiKey,
  });
}