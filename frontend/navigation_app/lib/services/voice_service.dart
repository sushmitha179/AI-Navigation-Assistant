import 'dart:io' show Platform;

import 'package:flutter_tts/flutter_tts.dart';
import '../models/navigation_model.dart';

/// Voice service for text-to-speech functionality.
///
/// This service handles text-to-speech to provide audio feedback
/// for visually impaired users.
class VoiceService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  String _activeLanguageTag = 'en-US';
  String? _lastNavigationKey;
  DateTime? _lastNavigationAt;
  static const Duration _navigationCooldown = Duration(seconds: 3);

  /// Initialize the voice service
  ///
  /// Returns true if initialization successful
  Future<bool> initialize() async {
    try {
      _flutterTts = FlutterTts();

      // Set default speech parameters
      await _flutterTts!
          .setSpeechRate(0.5); // Slower rate for better comprehension
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      await _flutterTts!.setLanguage(_activeLanguageTag);
      await _flutterTts!.awaitSpeakCompletion(true);

      _isInitialized = true;
      return true;
    } catch (e) {
      print('Voice service initialization error: $e');
      return false;
    }
  }

  String get activeLanguageTag => _activeLanguageTag;

  Future<bool> setLanguage(String languageTag) async {
    final tts = _flutterTts;
    if (!_isInitialized || tts == null) return false;
    try {
      if (Platform.isAndroid &&
          await tts.isLanguageInstalled(languageTag) != true) {
        await _useEnglishFallback(tts);
        return false;
      }
      if (await tts.isLanguageAvailable(languageTag) != true) {
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

  Future<void> _useEnglishFallback(FlutterTts tts) async {
    try {
      await tts.setLanguage('en-US');
      _activeLanguageTag = 'en-US';
    } catch (error) {
      print('English TTS fallback unavailable: $error');
    }
  }

  /// Speak text using text-to-speech
  ///
  /// [text] - Text to speak
  /// Returns true if speech started successfully
  Future<bool> speak(String text) async {
    if (!_isInitialized || _flutterTts == null) {
      print('Voice service not initialized');
      return false;
    }

    try {
      await _flutterTts!.speak(text);
      return true;
    } catch (e) {
      print('Speech error: $e');
      return false;
    }
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
