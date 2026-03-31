import 'ai_provider.dart';
import 'gemini_provider.dart';
import 'groq_provider.dart';

class AiProviderFactory {
  static AiProvider create(String provider) {
    switch (provider) {
      case 'groq':
        return GroqProvider();
      case 'gemini':
      default:
        return GeminiProvider();
    }
  }
}