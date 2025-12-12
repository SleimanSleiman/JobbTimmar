import 'package:flutter_tts/flutter_tts.dart';

/// Service för text-till-tal (TTS) som fungerar offline
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Getter för att kolla om TTS pratar
  bool get isSpeaking => _isSpeaking;

  /// Initierar TTS-motorn
  Future<void> _initialize() async {
    if (_isInitialized) return;

    _tts = FlutterTts();
    
    // Grundinställningar
    await _tts!.setPitch(1.0);
    await _tts!.setSpeechRate(0.4);  // Långsammare tal (0.0-1.0, lägre = långsammare)
    await _tts!.setVolume(1.0);

    // Lyssna på TTS-händelser
    _tts!.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts!.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts!.setCancelHandler(() {
      _isSpeaking = false;
    });

    _tts!.setErrorHandler((msg) {
      _isSpeaking = false;
    });

    _isInitialized = true;
  }

  /// Läser upp text med valt språk
  /// 
  /// [text] - Texten som ska läsas upp
  /// [language] - Språkkod: "sv-SE" för svenska, "ar-SA" för arabiska
  Future<void> speak(String text, {String language = "sv-SE"}) async {
    if (text.trim().isEmpty) return;

    try {
      await _initialize();
      
      // Stoppa eventuell pågående uppläsning
      await stop();
      
      // Sätt språk
      await _tts!.setLanguage(language);
      
      // Starta uppläsning
      await _tts!.speak(text);
    } catch (e) {
      _isSpeaking = false;
      // Ignorerar fel tyst - TTS kanske inte stöds på alla enheter
    }
  }

  /// Stoppar pågående uppläsning omedelbart
  Future<void> stop() async {
    try {
      if (_tts != null) {
        await _tts!.stop();
        _isSpeaking = false;
      }
    } catch (e) {
      _isSpeaking = false;
    }
  }

  /// Frigör resurser (anropa vid app-nedstängning om nödvändigt)
  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }
}
