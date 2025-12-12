import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gemini_text_service.dart';
import '../services/speech_service.dart';
import '../services/speech_input_service.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final SpeechService _speechService = SpeechService();
  final SpeechInputService _speechInputService = SpeechInputService();
  
  bool _isLoading = false;
  bool _isSpeaking = false;
  bool _isListening = false;
  String _listeningLanguage = '';
  GeminiResult? _result;
  SuggestionResult? _suggestionResult;
  String? _errorMessage;
  String _currentAction = '';

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _speechService.stop();
    _speechInputService.stopListening();
    super.dispose();
  }

  /// Läser upp text med TTS
  Future<void> _speak(String text, String language) async {
    setState(() => _isSpeaking = true);
    await _speechService.speak(text, language: language);
    // Vänta lite så knappen uppdateras
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() => _isSpeaking = _speechService.isSpeaking);
    }
  }

  /// Stoppar TTS
  Future<void> _stopSpeaking() async {
    await _speechService.stop();
    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  /// Startar röstinmatning (STT)
  Future<void> _startListening(String language) async {
    // Stoppa eventuell TTS först
    await _stopSpeaking();
    
    // Om redan lyssnar på samma språk, stoppa
    if (_isListening && _listeningLanguage == language) {
      await _stopListening();
      return;
    }
    
    // Stoppa om lyssnar på annat språk
    if (_isListening) {
      await _stopListening();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Spara befintlig text för att kunna lägga till ny text
    final existingText = _textController.text;
    final addSpace = existingText.isNotEmpty && !existingText.endsWith(' ');

    setState(() {
      _isListening = true;
      _listeningLanguage = language;
    });

    final success = await _speechInputService.startListening(
      language: language,
      onResult: (text) {
        if (mounted && text.isNotEmpty) {
          setState(() {
            // Lägg till ny text efter befintlig text
            if (existingText.isEmpty) {
              _textController.text = text;
            } else {
              _textController.text = existingText + (addSpace ? ' ' : '') + text;
            }
          });
        }
      },
      onStopped: () {
        // Uppdatera UI när lyssning slutar automatiskt
        if (mounted) {
          setState(() {
            _isListening = false;
            _listeningLanguage = '';
          });
        }
      },
    );

    if (!success && mounted) {
      setState(() {
        _isListening = false;
        _listeningLanguage = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mikrofonåtkomst krävs för röstinmatning.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Stoppar röstinmatning (STT)
  Future<void> _stopListening() async {
    await _speechInputService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _listeningLanguage = '';
      });
    }
  }

  Future<void> _processText(String action) async {
    final text = _textController.text.trim();
    
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skriv ett meddelande först'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _suggestionResult = null;
      _currentAction = action;
    });

    try {
      if (action == 'suggestions') {
        final suggestionResult = await GeminiTextService.generateReplySuggestions(text);
        setState(() {
          _suggestionResult = suggestionResult;
          _isLoading = false;
        });
      } else {
        final GeminiResult result;
        switch (action) {
          case 'improve':
            result = await GeminiTextService.improveText(text);
            break;
          case 'simplify':
            result = await GeminiTextService.simplifyText(text);
            break;
          case 'toArabic':
            result = await GeminiTextService.translateToArabic(text);
            break;
          case 'toSwedish':
            result = await GeminiTextService.translateToSwedish(text);
            break;
          default:
            result = await GeminiTextService.improveText(text);
        }
        
        setState(() {
          _result = result;
          _isLoading = false;
        });
      }

      // Scrolla ner till resultatet
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } on GeminiException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_result == null) return;

    await Clipboard.setData(ClipboardData(text: _result!.improvedText));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Texten kopierad!')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearAll() {
    _stopSpeaking(); // Stoppa tal när man rensar
    setState(() {
      _textController.clear();
      _result = null;
      _suggestionResult = null;
      _errorMessage = null;
      _currentAction = '';
    });
  }

  void _useImprovedText() {
    if (_result != null) {
      _stopSpeaking(); // Stoppa tal när man använder texten
      _textController.text = _result!.improvedText;
      setState(() {
        _result = null;
      });
    }
  }

  Future<void> _copySuggestion(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Svaret kopierat!')),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _useSuggestion(String text) {
    _textController.text = text;
    setState(() {
      _suggestionResult = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Svaret inlagt - du kan redigera det innan du skickar'),
        backgroundColor: Colors.teal,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _getResultTitle() {
    switch (_currentAction) {
      case 'improve':
        return 'Förbättrad text';
      case 'simplify':
        return 'Förenklad text';
      case 'toArabic':
        return 'Arabisk översättning';
      case 'toSwedish':
        return 'Svensk översättning';
      case 'suggestions':
        return 'Svarsförslag';
      default:
        return 'Resultat';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS'),
        centerTitle: true,
        actions: [
          if (_textController.text.isNotEmpty || _result != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Rensa allt',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Text input
            TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 3,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: _isListening 
                    ? 'Lyssnar... Tala nu!' 
                    : 'Skriv ditt meddelande här...',
                hintStyle: TextStyle(
                  color: _isListening ? Colors.teal : Colors.grey.shade500, 
                  fontSize: 18,
                  fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
                ),
                filled: true,
                fillColor: _isListening ? Colors.teal.shade50 : Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _isListening ? Colors.teal : Colors.grey.shade300,
                    width: _isListening ? 2 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.teal, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (_) => setState(() {}),
            ),
            
            const SizedBox(height: 12),
            
            // Röstinmatning (STT) knappar
            Row(
              children: [
                Expanded(
                  child: _MicButton(
                    label: '🎤 Svenska',
                    isActive: _isListening && _listeningLanguage == 'sv-SE',
                    onPressed: () => _startListening('sv-SE'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MicButton(
                    label: '🎤 Arabiska',
                    isActive: _isListening && _listeningLanguage == 'ar-SA',
                    onPressed: () => _startListening('ar-SA'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MicButton(
                    label: '⏹ Stoppa',
                    isActive: false,
                    isStop: true,
                    onPressed: _isListening ? _stopListening : null,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Rad 1: Förbättra & Förenkla
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Förbättra',
                    icon: Icons.auto_fix_high,
                    color: Colors.green.shade600,
                    isLoading: _isLoading && _currentAction == 'improve',
                    onPressed: _isLoading ? null : () => _processText('improve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Förenkla',
                    icon: Icons.abc,
                    color: Colors.orange.shade600,
                    isLoading: _isLoading && _currentAction == 'simplify',
                    onPressed: _isLoading ? null : () => _processText('simplify'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Rad 2: Översättning
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Till arabiska',
                    icon: Icons.translate,
                    color: Colors.purple.shade600,
                    isLoading: _isLoading && _currentAction == 'toArabic',
                    onPressed: _isLoading ? null : () => _processText('toArabic'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Till svenska',
                    icon: Icons.translate,
                    color: Colors.blue.shade600,
                    isLoading: _isLoading && _currentAction == 'toSwedish',
                    onPressed: _isLoading ? null : () => _processText('toSwedish'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Rad 3: Svarsförslag
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Ge svarsförslag',
                    icon: Icons.lightbulb_outline,
                    color: Colors.teal.shade600,
                    isLoading: _isLoading && _currentAction == 'suggestions',
                    onPressed: _isLoading ? null : () => _processText('suggestions'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Resultat
            if (_result != null) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getResultTitle(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Resultat-ruta
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200, width: 2),
                ),
                child: SelectableText(
                  _result!.improvedText,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.5,
                    // Höger-till-vänster för arabiska
                    fontFamily: _currentAction == 'toArabic' ? null : null,
                  ),
                  textDirection: _currentAction == 'toArabic' 
                      ? TextDirection.rtl 
                      : TextDirection.ltr,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Resultat-knappar
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: const Icon(Icons.copy, size: 22),
                        label: const Text('Kopiera', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _useImprovedText,
                        icon: const Icon(Icons.edit, size: 22),
                        label: const Text('Använd', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // TTS-knappar - Visa endast relevant språk-knapp
              Row(
                children: [
                  // Visa Lyssna SV endast om INTE arabisk översättning
                  if (_currentAction != 'toArabic')
                    Expanded(
                      child: _TtsButton(
                        label: 'Lyssna (SV)',
                        icon: Icons.volume_up,
                        color: Colors.teal.shade600,
                        onPressed: () => _speak(_result!.improvedText, 'sv-SE'),
                      ),
                    ),
                  // Visa Lyssna AR endast om arabisk översättning
                  if (_currentAction == 'toArabic') ...[
                    Expanded(
                      child: _TtsButton(
                        label: 'Lyssna (AR)',
                        icon: Icons.volume_up,
                        color: Colors.indigo.shade600,
                        onPressed: () => _speak(_result!.improvedText, 'ar-SA'),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  // Stoppa-knappen
                  Expanded(
                    child: _TtsButton(
                      label: 'Stoppa',
                      icon: Icons.stop_circle,
                      color: Colors.red.shade600,
                      onPressed: _isSpeaking ? _stopSpeaking : null,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Original-knapp - visa med rätt språk beroende på action
              if (_result!.hasChanges) ...[
                // Om vi översatt till svenska, är originalet på arabiska
                if (_currentAction == 'toSwedish')
                  SizedBox(
                    width: double.infinity,
                    child: _TtsButton(
                      label: 'Lyssna på original (AR)',
                      icon: Icons.history,
                      color: Colors.grey.shade600,
                      onPressed: () => _speak(_result!.originalText, 'ar-SA'),
                    ),
                  )
                // Annars är originalet på svenska
                else
                  SizedBox(
                    width: double.infinity,
                    child: _TtsButton(
                      label: 'Lyssna på original (SV)',
                      icon: Icons.history,
                      color: Colors.grey.shade600,
                      onPressed: () => _speak(_result!.originalText, 'sv-SE'),
                    ),
                  ),
              ],
              
              // Original-text
              if (_result!.hasChanges) ...[
                const SizedBox(height: 20),
                Card(
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Original:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _result!.originalText,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            
            // Svarsförslag - separata paneler
            if (_suggestionResult != null && _suggestionResult!.hasSuggestions) ...[
              Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.teal, size: 24),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Svarsförslag',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // JA-panel
              if (_suggestionResult!.yesSuggestion.isNotEmpty)
                _SuggestionPanel(
                  title: '✅ Om du vill svara JA',
                  suggestion: _suggestionResult!.yesSuggestion,
                  color: Colors.green,
                  onCopy: () => _copySuggestion(_suggestionResult!.yesSuggestion),
                ),
              
              const SizedBox(height: 12),
              
              // NEJ-panel
              if (_suggestionResult!.noSuggestion.isNotEmpty)
                _SuggestionPanel(
                  title: '❌ Om du vill svara NEJ',
                  suggestion: _suggestionResult!.noSuggestion,
                  color: Colors.red,
                  onCopy: () => _copySuggestion(_suggestionResult!.noSuggestion),
                ),
              
              const SizedBox(height: 12),
              
              // ANNAT-panel
              if (_suggestionResult!.otherSuggestion.isNotEmpty)
                _SuggestionPanel(
                  title: '💬 Annat svar',
                  suggestion: _suggestionResult!.otherSuggestion,
                  color: Colors.blue,
                  onCopy: () => _copySuggestion(_suggestionResult!.otherSuggestion),
                ),
            ],
            
            // Felmeddelande
            if (_errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Extra utrymme längst ner
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}

/// Återanvändbar knapp-widget för TTS
class _TtsButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _TtsButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey.shade300 : color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isDisabled ? 0 : 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Knapp-widget för röstinmatning (mikrofon)
class _MicButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isStop;
  final VoidCallback? onPressed;

  const _MicButton({
    required this.label,
    required this.isActive,
    this.isStop = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    
    Color backgroundColor;
    if (isDisabled) {
      backgroundColor = Colors.grey.shade300;
    } else if (isStop) {
      backgroundColor = Colors.red.shade400;
    } else if (isActive) {
      backgroundColor = Colors.teal.shade700;
    } else {
      backgroundColor = Colors.teal.shade400;
    }

    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: isActive ? 4 : 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Text(
                'Lyssnar',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Återanvändbar knapp-widget
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel för svarsförslag
class _SuggestionPanel extends StatelessWidget {
  final String title;
  final String suggestion;
  final Color color;
  final VoidCallback onCopy;

  const _SuggestionPanel({
    required this.title,
    required this.suggestion,
    required this.color,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titel
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          // Förslag-text
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              suggestion,
              style: const TextStyle(
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ),
          // Kopiera-knapp
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Kopiera', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
