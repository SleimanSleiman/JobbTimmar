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
  /// Först förenklas texten, sedan översätts den
  static Future<GeminiResult> translateToArabic(String input) async {
    if (input.trim().isEmpty) {
      return GeminiResult(
        originalText: input,
        improvedText: input,
        success: true,
      );
    }

    final prompt = '''Du ska göra två saker med följande svenska text:
1. Först förenkla texten (kortare meningar, enklare ord)
2. Sedan översätta den förenklade versionen till arabiska

Använd enkel, vardaglig arabiska (libanesisk dialekt om möjligt).
Undvik formell/klassisk arabiska - skriv som man pratar i vardagen.

Svara ENDAST med den arabiska översättningen, ingen förklaring eller mellansteg.

Text:
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

  /// Genererar svarsförslag baserat på meddelandet
  /// Ger ett snällt svar för ja, nej och annat
  static Future<SuggestionResult> generateReplySuggestions(String input) async {
    if (input.trim().isEmpty) {
      return SuggestionResult(
        originalText: input,
        yesSuggestion: '',
        noSuggestion: '',
        otherSuggestion: '',
        success: true,
      );
    }

    final prompt = '''Analysera följande meddelande och ge ETT svarsförslag för varje kategori.
Svaren ska vara snälla, varma och vänliga. Använd enkla ord som passar för SMS.

Meddelande:
$input

Svara i EXAKT detta format (en rad per svar, utan punkter eller bindestreck):
JA: [ett snällt, positivt ja-svar]
NEJ: [ett artigt, snällt nej-svar som inte sårar]
ANNAT: [en vänlig fråga eller alternativt svar]

Exempel på snälla svar:
JA: Ja, självklart! Det går jättebra 😊
NEJ: Tyvärr kan jag inte just nu, men tack för att du frågade!
ANNAT: Kan vi prata mer om det? Jag vill gärna hjälpa till!''';

    try {
      final result = await _sendRequest(input, prompt);
      
      // Parsa svaret
      String yesSuggestion = '';
      String noSuggestion = '';
      String otherSuggestion = '';
      
      final lines = result.improvedText.split('\n');
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.toUpperCase().startsWith('JA:')) {
          yesSuggestion = trimmedLine.substring(3).trim();
        } else if (trimmedLine.toUpperCase().startsWith('NEJ:')) {
          noSuggestion = trimmedLine.substring(4).trim();
        } else if (trimmedLine.toUpperCase().startsWith('ANNAT:')) {
          otherSuggestion = trimmedLine.substring(6).trim();
        }
      }
      
      return SuggestionResult(
        originalText: input,
        yesSuggestion: yesSuggestion,
        noSuggestion: noSuggestion,
        otherSuggestion: otherSuggestion,
        success: true,
      );
    } catch (e) {
      return SuggestionResult(
        originalText: input,
        yesSuggestion: '',
        noSuggestion: '',
        otherSuggestion: '',
        success: false,
        errorMessage: e.toString(),
      );
    }
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

class SuggestionResult {
  final String originalText;
  final String yesSuggestion;
  final String noSuggestion;
  final String otherSuggestion;
  final bool success;
  final String? errorMessage;

  SuggestionResult({
    required this.originalText,
    required this.yesSuggestion,
    required this.noSuggestion,
    required this.otherSuggestion,
    required this.success,
    this.errorMessage,
  });

  bool get hasSuggestions => 
      yesSuggestion.isNotEmpty || 
      noSuggestion.isNotEmpty || 
      otherSuggestion.isNotEmpty;
}
