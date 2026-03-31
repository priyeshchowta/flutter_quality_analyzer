import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/result.dart';
import '../utils/logger.dart';
import 'ai_provider.dart';

class GeminiProvider implements AiProvider {
  static const _url =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.0-flash:generateContent';

  final http.Client _client;

  GeminiProvider({http.Client? client})
      : _client = client ?? http.Client();

  @override
  Future<Result<String>> generateSummary({
    required String prompt,
    required String apiKey,
  }) async {
    try {
      final uri = Uri.parse('$_url?key=$apiKey');

      final response = await _client.post(
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
      );

      Logger.debug('Gemini status: ${response.statusCode}');

      if (response.statusCode == 429) {
        return Result.failure('RATE_LIMIT');
      }

      if (response.statusCode != 200) {
        return Result.failure('Gemini error ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'];

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