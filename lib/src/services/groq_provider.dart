import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/result.dart';
import '../utils/logger.dart';
import 'ai_provider.dart';

class GroqProvider implements AiProvider {
  static const _url = 'https://api.groq.com/openai/v1/chat/completions';

  final http.Client _client;

  GroqProvider({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<Result<String>> generateSummary({
    required String prompt,
    required String apiKey,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.4,
          'max_tokens': 600,
        }),
      );

      Logger.debug('Groq status: ${response.statusCode}');

      if (response.statusCode == 429) {
        return Result.failure('RATE_LIMIT');
      }

      if (response.statusCode != 200) {
        // Surface the actual error message from Groq for easier debugging
        String detail = '';
        try {
          final errJson = jsonDecode(response.body) as Map<String, dynamic>;
          detail = errJson['error']?['message'] as String? ?? '';
        } catch (_) {}
        final msg = detail.isNotEmpty
            ? 'Groq error ${response.statusCode}: $detail'
            : 'Groq error ${response.statusCode}';
        Logger.debug('Groq response body: ${response.body}');
        return Result.failure(msg);
      }

      final json = jsonDecode(response.body);
      final text = json['choices']?[0]?['message']?['content'];

      if (text == null) {
        return Result.failure('Empty response');
      }

      return Result.success(text.trim());
    } catch (e) {
      return Result.failure(e.toString());
    } finally {
      _client.close();
    }
  }
}