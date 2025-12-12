import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/secrets.dart';

class GeminiTextService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';
  
  /// Förbättrar texten med Gemini AI
  /// Fixar grammatik, stavning, ordval, ordföljd och tydlighet
  static Future<GeminiResult> improveText(String input) async {
    if (input.trim().isEmpty) {
      return GeminiResult(
        originalText: input,
        improvedText: input,
        success: true,
      );
    }

    final prompt = '''Skriv om följande text på korrekt svenska. Förbättra:
- Grammatik och stavning
- Ordföljd (svensk ordföljd)
- Ordval och tydlighet
- Lägg till skiljetecken där det behövs

Behåll meddelandets betydelse och ton. Svara ENDAST med den förbättrade texten, ingen förklaring.

Text att förbättra:
$input''';

    return await _sendRequest(input, prompt);
  }

  /// Förenklar texten för att göra den lättare att förstå
  static Future<GeminiResult> simplifyText(String input) async {
    if (input.trim().isEmpty) {
      return GeminiResult(
        originalText: input,
        improvedText: input,
        success: true,
      );
    }

    final prompt = '''Förenkla följande svenska text så att den blir lättare att förstå.
Använd:
- Kortare meningar
- Enklare ord
- Tydlig struktur

Behåll betydelsen. Svara ENDAST med den förenklade texten, ingen förklaring.

Text att förenkla:
$input''';

    return await _sendRequest(input, prompt);
  }

  /// Översätter text från svenska till libanesisk/enkel arabiska
  static Future<GeminiResult> translateToArabic(String input) async {
    if (input.trim().isEmpty) {
      return GeminiResult(
        originalText: input,
        improvedText: input,
        success: true,
      );
    }

    final prompt = '''Översätt följande svenska text till arabiska.
Använd enkel, vardaglig arabiska (helst libanesisk dialekt om möjligt).
Undvik formell/klassisk arabiska - skriv som man pratar.

Svara ENDAST med översättningen, ingen förklaring.

Text att översätta:
$input''';

    return await _sendRequest(input, prompt);
  }

  /// Översätter text från arabiska till svenska
  static Future<GeminiResult> translateToSwedish(String input) async {
    if (input.trim().isEmpty) {
      return GeminiResult(
        originalText: input,
        improvedText: input,
        success: true,
      );
    }

    final prompt = '''Översätt följande arabiska text till svenska.
Använd enkel, tydlig svenska.

Svara ENDAST med översättningen, ingen förklaring.

Text att översätta:
$input''';

    return await _sendRequest(input, prompt);
  }

  /// Skickar request till Gemini API
  static Future<GeminiResult> _sendRequest(String originalText, String prompt) async {
    final url = '$_baseUrl?key=${Secrets.geminiApiKey}';
    
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 81920,
      }
    });

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        // Parsa svaret från Gemini
        final candidates = json['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final improvedText = parts[0]['text'] as String;
            return GeminiResult(
              originalText: originalText,
              improvedText: improvedText.trim(),
              success: true,
            );
          }
        }
        
        throw GeminiException('Kunde inte tolka svaret från AI');
      } else {
        // Försök parsa felmeddelandet
        String errorMessage = 'API-fel: ${response.statusCode}';
        try {
          final errorJson = jsonDecode(response.body);
          if (errorJson['error'] != null) {
            errorMessage = errorJson['error']['message'] ?? errorMessage;
          }
        } catch (_) {}
        
        throw GeminiException(errorMessage);
      }
    } catch (e) {
      if (e is GeminiException) {
        rethrow;
      }
      throw GeminiException(
        'Kunde inte ansluta till servern. Kontrollera din internetanslutning.',
      );
    }
  }
}

class GeminiResult {
  final String originalText;
  final String improvedText;
  final bool success;
  final String? errorMessage;

  GeminiResult({
    required this.originalText,
    required this.improvedText,
    required this.success,
    this.errorMessage,
  });

  bool get hasChanges => originalText.trim() != improvedText.trim();
}

class GeminiException implements Exception {
  final String message;

  GeminiException(this.message);

  @override
  String toString() => message;
}
