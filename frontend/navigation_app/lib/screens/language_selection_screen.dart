import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/assistant_language.dart';
import '../services/localization_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/voice_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    super.key,
    this.voiceService,
    this.speechRecognitionService,
    this.localizationService,
  });

  @visibleForTesting
  final VoiceService? voiceService;

  @visibleForTesting
  final SpeechRecognitionService? speechRecognitionService;

  @visibleForTesting
  final LocalizationService? localizationService;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late final VoiceService _voiceService = widget.voiceService ?? VoiceService();
  late final SpeechRecognitionService _speechService =
      widget.speechRecognitionService ?? SpeechRecognitionService();
  late final LocalizationService _localizationService =
      widget.localizationService ?? LocalizationService();
  late final bool _ownsServices =
      widget.voiceService == null && widget.speechRecognitionService == null;

  String _status = 'Preparing voice language selection.';
  bool _isBusy = false;
  int _automaticPromptCount = 0;
  Timer? _promptTimer;
  String? _recognitionFailureMessage;

  static const String _initialPrompt =
      'Welcome to AI Navigation Assistant. Please say English, Telugu, or Hindi to choose your language.';

  @override
  void initState() {
    super.initState();
    _initializeLanguageSelection();
  }

  Future<void> _initializeLanguageSelection() async {
    await _localizationService.init();
    if (!mounted) return;

    final voiceReady = await _voiceService.initialize();
    var englishVoiceReady = voiceReady;
    if (voiceReady) {
      englishVoiceReady = await _voiceService.setLanguage('en-US');
    }
    if (!mounted) return;

    if (englishVoiceReady) {
      await _speakEnglish(_initialPrompt);
    } else {
      setState(() => _status =
          'English speech is unavailable. Use the English language buttons.');
    }

    final initialized = await _speechService.initialize(
      onStatusChanged: _onRecognitionStatus,
      onError: _onRecognitionError,
    );
    if (!mounted) return;
    final listening = initialized &&
        await _speechService.startListening(_onRecognitionResult);
    setState(() {
      _status = listening
          ? 'Listening. Say English, Telugu, or Hindi. You can also choose an English button.'
          : _recognitionFailureMessage ??
              (initialized
                  ? 'Voice recognition could not start. Use an English language button or check microphone access in Android settings.'
                  : 'Voice recognition is unavailable. Use an English language button or check microphone permission in Android settings.');
    });
    if (listening) _schedulePromptReminder();
  }

  void _onRecognitionStatus(String status) {
    if (!mounted || _isBusy) return;
    final normalized = status.toLowerCase();
    if (normalized.contains('denied')) {
      setState(() => _status =
          'Microphone access was denied. Use the English buttons or enable microphone access in Android app settings.');
    } else if (normalized.contains('unavailable')) {
      setState(() => _status =
          'Voice recognition is unavailable. Use one of the English language buttons.');
    }
  }

  Future<void> _onRecognitionError(String code, String message) async {
    if (!mounted || _isBusy) return;
    final normalizedCode = code.toLowerCase();
    if (normalizedCode == 'permission_denied') {
      _promptTimer?.cancel();
      const fallback =
          'Microphone access was denied. Use the English buttons or enable microphone access in Android app settings.';
      _recognitionFailureMessage = fallback;
      setState(() => _status = fallback);
      await _speakEnglish(
        'Microphone access was denied. Please use one of the English language buttons, or enable microphone access in Android app settings.',
      );
      return;
    }
    if (normalizedCode == 'unavailable') {
      _promptTimer?.cancel();
      const fallback =
          'Voice recognition is unavailable. Use one of the English language buttons.';
      _recognitionFailureMessage = fallback;
      setState(() => _status = fallback);
      await _speakEnglish(
        'Voice recognition is unavailable. Please choose English, Telugu, or Hindi using the accessible buttons.',
      );
      return;
    }
    if (normalizedCode == 'no_match' ||
        normalizedCode == '6' ||
        normalizedCode == 'speech_timeout' ||
        normalizedCode == 'end_of_speech_timeout') {
      _schedulePromptReminder(immediate: true);
    }
  }

  Future<void> _onRecognitionResult(String phrase) async {
    if (_isBusy || !mounted) return;
    final choice = const AssistantLocalizations(AssistantLanguage.english)
        .matchLanguageChoice(phrase);
    if (choice == null) {
      _schedulePromptReminder(immediate: true);
      return;
    }
    await _selectLanguage(choice);
  }

  void _schedulePromptReminder({bool immediate = false}) {
    if (_isBusy || _automaticPromptCount >= 2) {
      return;
    }
    if (immediate) {
      _promptTimer?.cancel();
      _promptTimer = null;
    } else if (_promptTimer?.isActive == true) {
      return;
    }
    _promptTimer = Timer(
      immediate
          ? const Duration(milliseconds: 700)
          : const Duration(seconds: 12),
      () {
        _promptTimer = null;
        if (!mounted || _isBusy || _automaticPromptCount >= 2) return;
        _automaticPromptCount++;
        _speakEnglish(
          'Please say English, Telugu, or Hindi. You can also choose one of the English buttons.',
        );
      },
    );
  }

  Future<void> _repeatPrompt() async {
    _automaticPromptCount = 0;
    await _speakEnglish(
      'Please say English, Telugu, or Hindi. You can also choose one of the English buttons.',
    );
  }

  Future<void> _speakEnglish(String text) async {
    await _speechService.setTtsSpeaking(true);
    try {
      await _voiceService.setLanguage('en-US');
      await _voiceService.speak(text);
    } finally {
      await _speechService.setTtsSpeaking(false);
    }
  }

  Future<void> _selectLanguage(AssistantLanguage language) async {
    if (_isBusy) return;
    _promptTimer?.cancel();
    _isBusy = true;
    if (mounted) {
      setState(() => _status = 'Confirming ${language.name} selection.');
    }

    await _speechService.stopListening();
    final englishConfirmation = switch (language) {
      AssistantLanguage.english => 'English selected.',
      AssistantLanguage.telugu => 'Telugu selected.',
      AssistantLanguage.hindi => 'Hindi selected.',
    };
    await _speakEnglish(englishConfirmation);

    final appLanguage = switch (language) {
      AssistantLanguage.english => AppLanguage.english,
      AssistantLanguage.telugu => AppLanguage.telugu,
      AssistantLanguage.hindi => AppLanguage.hindi,
    };
    await _localizationService.setLanguage(appLanguage);

    final voiceAvailable = await _voiceService.setLanguage(language.localeTag);
    if (!voiceAvailable) {
      await _speakEnglish(
        'The selected language voice is not installed. I will speak English. Open Android text-to-speech settings and install the ${language.name} voice to enable speech in that language.',
      );
    }

    await _speechService.stopListening();
    await _speechService.setLanguage(language.localeTag);
    if (!mounted) return;
    final routeIsRoot = ModalRoute.of(context)?.isFirst ?? true;
    if (routeIsRoot) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pop(language);
    }
  }

  @override
  void dispose() {
    _promptTimer?.cancel();
    if (_ownsServices) {
      _speechService.dispose();
      _voiceService.dispose();
    } else {
      _speechService.stopListening();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Choose Spoken Language',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  liveRegion: true,
                  label: 'Language selection status',
                  value: _status,
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, height: 1.4),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Say English, Telugu, or Hindi. You can also select a language below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, height: 1.4),
                ),
                const SizedBox(height: 24),
                _languageButton(AssistantLanguage.english),
                const SizedBox(height: 16),
                _languageButton(AssistantLanguage.telugu),
                const SizedBox(height: 16),
                _languageButton(AssistantLanguage.hindi),
                const SizedBox(height: 16),
                Semantics(
                  button: true,
                  label: 'Repeat language prompt',
                  child: SizedBox(
                    height: 64,
                    child: OutlinedButton(
                      onPressed: _isBusy ? null : _repeatPrompt,
                      child: const Text(
                        'REPEAT LANGUAGE PROMPT',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'The English screen remains unchanged. Telugu and Hindi speech require the corresponding Android voice data.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageButton(AssistantLanguage language) {
    return Semantics(
      button: true,
      label: '${language.name} spoken language',
      hint: 'Double tap to select ${language.name}',
      child: SizedBox(
        height: 76,
        child: ElevatedButton(
          onPressed: _isBusy ? null : () => _selectLanguage(language),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            language.name.toUpperCase(),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
