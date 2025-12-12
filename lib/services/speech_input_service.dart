import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

/// Service för tal-till-text (STT) som fungerar offline
class SpeechInputService {
  static final SpeechInputService _instance = SpeechInputService._internal();
  factory SpeechInputService() => _instance;
  SpeechInputService._internal();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _currentLanguage = 'sv-SE';
  Function()? _onListeningStopped;

  /// Getter för att kolla om STT lyssnar
  bool get isListening => _isListening;

  /// Getter för nuvarande språk
  String get currentLanguage => _currentLanguage;

  /// Initierar STT-motorn
  Future<bool> _initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            // Anropa callback när lyssning slutar
            _onListeningStopped?.call();
          }
        },
        onError: (error) {
          _isListening = false;
          _onListeningStopped?.call();
        },
      );
      return _isInitialized;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  /// Startar lyssning med valt språk
  /// 
  /// [onResult] - Callback som anropas med transkriberad text
  /// [onStopped] - Callback som anropas när lyssning slutar automatiskt
  /// [language] - Språkkod: "sv-SE" för svenska, "ar-SA" för arabiska
  /// 
  /// Returnerar true om lyssning startade, false om det misslyckades
  Future<bool> startListening({
    required Function(String text) onResult,
    Function()? onStopped,
    String language = 'sv-SE',
  }) async {
    // Stoppa eventuell pågående lyssning
    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Initiera om inte redan gjort
    final initialized = await _initialize();
    if (!initialized) {
      return false;
    }

    // Kontrollera om mikrofon är tillgänglig
    if (!_speech.isAvailable) {
      return false;
    }

    _currentLanguage = language;
    _onListeningStopped = onStopped;

    try {
      _isListening = true;
      
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords);
        },
        localeId: language,
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        pauseFor: const Duration(seconds: 3), // Sluta lyssna efter 3 sek tystnad
        listenFor: const Duration(seconds: 30), // Max 30 sek total
      );
      
      return true;
    } catch (e) {
      _isListening = false;
      return false;
    }
  }

  /// Stoppar lyssning
  Future<void> stopListening() async {
    if (_isListening) {
      try {
        await _speech.stop();
      } catch (e) {
        // Ignorera fel vid stopp
      }
      _isListening = false;
    }
    _onListeningStopped = null;
  }

  /// Avbryter lyssning
  Future<void> cancelListening() async {
    try {
      await _speech.cancel();
    } catch (e) {
      // Ignorera fel
    }
    _isListening = false;
    _onListeningStopped = null;
  }

  /// Kontrollerar om STT är tillgängligt
  Future<bool> isAvailable() async {
    await _initialize();
    return _speech.isAvailable;
  }
}
