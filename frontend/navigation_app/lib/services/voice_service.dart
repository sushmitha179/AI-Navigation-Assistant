import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';
import '../models/navigation_model.dart';

/// Voice service for text-to-speech functionality.
///
/// This service handles text-to-speech to provide audio feedback
/// for visually impaired users.
class VoiceService {
  VoiceService({FlutterTts? textToSpeech, bool? isAndroid})
      : _textToSpeech = textToSpeech,
        _isAndroid = isAndroid ?? Platform.isAndroid;

  final FlutterTts? _textToSpeech;
  final bool _isAndroid;
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  Future<void> _speechQueue = Future<void>.value();
  String _activeLanguageTag = 'en-US';
  String? _lastNavigationKey;
  DateTime? _lastNavigationAt;
  static const Duration _navigationCooldown = Duration(seconds: 3);

  /// Initialize the voice service
  ///
  /// Returns true if initialization successful
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _flutterTts = _textToSpeech ?? FlutterTts();

      // Set default speech parameters
      await _flutterTts!
          .setSpeechRate(0.5); // Slower rate for better comprehension
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      await _flutterTts!.awaitSpeakCompletion(true);

      _isInitialized = true;
      if (!await setLanguage('en-US')) {
        _isInitialized = false;
        return false;
      }
      return true;
    } catch (e) {
      print('Voice service initialization error: $e');
      return false;
    }
  }

  String get activeLanguageTag => _activeLanguageTag;

  Future<bool> setLanguage(String languageTag) async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null || _isSpeaking) return false;
    try {
      final installedVoices = await _getInstalledVoices(tts, languageTag);
      if (installedVoices.isEmpty) {
        await _useEnglishFallback(tts);
        return false;
      }
      final voice = installedVoices.first;
      final voiceResult = await tts.setVoice({
        'name': voice['name']!,
        'locale': voice['locale']!,
      });
      if (voiceResult != true && voiceResult != 1) {
        await _useEnglishFallback(tts);
        return false;
      }
      final result = await tts.setLanguage(languageTag);
      if (result != true && result != 1) {
        await _useEnglishFallback(tts);
        return false;
      }
      _activeLanguageTag = languageTag;
      return true;
    } catch (error) {
      print('TTS language unavailable ($languageTag): $error');
      await _useEnglishFallback(tts);
      return false;
    }
  }

  Future<List<Map<String, String>>> _getInstalledVoices(
    FlutterTts tts,
    String languageTag,
  ) async {
    if (await tts.isLanguageAvailable(languageTag) != true) return const [];
    if (_isAndroid && await tts.isLanguageInstalled(languageTag) != true) {
      return const [];
    }
    final voices = await tts.getVoices;
    if (voices is! List) return const [];
    final requestedLocale = _normalizeLocale(languageTag);
    return voices
        .whereType<Map>()
        .map((voice) => voice.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ))
        .where((voice) =>
            voice['name'] != null &&
            voice['locale'] != null &&
            _normalizeLocale(voice['locale']!) == requestedLocale)
        .map((voice) => Map<String, String>.from(voice))
        .toList(growable: false);
  }

  String _normalizeLocale(String tag) => tag.replaceAll('_', '-').toLowerCase();

  Future<bool> _useEnglishFallback(FlutterTts tts) async {
    try {
      final englishVoices = await _getInstalledVoices(tts, 'en-US');
      if (englishVoices.isEmpty) return false;
      final voice = englishVoices.first;
      final voiceResult = await tts.setVoice({
        'name': voice['name']!,
        'locale': voice['locale']!,
      });
      if (voiceResult != true && voiceResult != 1) return false;
      final result = await tts.setLanguage('en-US');
      if (result != true && result != 1) return false;
      _activeLanguageTag = 'en-US';
      return true;
    } catch (error) {
      print('English TTS fallback unavailable: $error');
      return false;
    }
  }

  /// Speak text using text-to-speech
  ///
  /// [text] - Text to speak
  /// Returns true if speech started successfully
  Future<bool> speak(String text) async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) {
      print('Voice service not initialized');
      return false;
    }

    final completer = Completer<bool>();
    _speechQueue = _speechQueue.then((_) async {
      try {
        _isSpeaking = true;
        await tts.speak(text);
        completer.complete(true);
      } catch (error) {
        print('Speech error: $error');
        completer.complete(false);
      } finally {
        _isSpeaking = false;
      }
    });
    return completer.future;
  }

  Future<bool> speakTextInLanguage(String text, String languageTag) async {
    final originalTag = _activeLanguageTag;
    if (!await setLanguage(languageTag)) {
      await setLanguage(originalTag);
      return false;
    }
    final spoken = await speak(text);
    final restored = await setLanguage(originalTag);
    return spoken && restored;
  }

  Future<bool> speakNavigation(NavigationModel navigation) async {
    final key = '${navigation.action}|${navigation.reason}';
    final now = DateTime.now();
    if (_lastNavigationKey == key &&
        _lastNavigationAt != null &&
        now.difference(_lastNavigationAt!) < _navigationCooldown) {
      return false;
    }
    _lastNavigationKey = key;
    _lastNavigationAt = now;

    final action = navigation.action == 'CAUTION / SLOW DOWN'
        ? 'Caution. Slow down.'
        : '${navigation.action[0]}${navigation.action.substring(1).toLowerCase()}.';
    return speak(navigation.action == 'CONTINUE'
        ? 'Continue.'
        : '$action ${navigation.reason}.');
  }

  /// Stop current speech
  ///
  /// Returns true if speech stopped successfully
  Future<bool> stop() async {
    if (!_isInitialized || _flutterTts == null) {
      return false;
    }

    try {
      await _flutterTts!.stop();
      return true;
    } catch (e) {
      print('Stop speech error: $e');
      return false;
    }
  }

  /// Set speech rate (speed)
  ///
  /// [rate] - Speech rate (0.0 to 1.0, where 1.0 is normal)
  Future<bool> setSpeechRate(double rate) async {
    if (!_isInitialized || _flutterTts == null) {
      return false;
    }

    try {
      await _flutterTts!.setSpeechRate(rate);
      return true;
    } catch (e) {
      print('Set speech rate error: $e');
      return false;
    }
  }

  /// Set speech volume
  ///
  /// [volume] - Volume level (0.0 to 1.0)
  Future<bool> setVolume(double volume) async {
    if (!_isInitialized || _flutterTts == null) {
      return false;
    }

    try {
      await _flutterTts!.setVolume(volume);
      return true;
    } catch (e) {
      print('Set volume error: $e');
      return false;
    }
  }

  /// Check if voice service is ready
  bool isReady() {
    return _isInitialized && _flutterTts != null;
  }

  /// Get voice service status
  String getStatus() {
    if (_isInitialized) {
      return 'Voice service ready';
    } else {
      return 'Voice service not initialized';
    }
  }

  /// Dispose resources
  void dispose() {
    _flutterTts?.stop();
    _isInitialized = false;
  }
}
