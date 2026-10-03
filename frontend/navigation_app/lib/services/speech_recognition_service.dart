import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef VoiceCommandHandler = FutureOr<void> Function(String command);

class SpeechRecognitionService {
  static const MethodChannel _channel = MethodChannel('voice_recognition');

  bool _isInitialized = false;
  bool _isListening = false;
  bool _shouldListen = false;
  bool _isTtsSpeaking = false;
  bool _startInProgress = false;
  bool _disposed = false;
  Timer? _restartTimer;
  VoiceCommandHandler? _onResult;
  ValueChanged<String>? _onStatusChanged;

  Future<bool> initialize({ValueChanged<String>? onStatusChanged}) async {
    _disposed = false;
    _onStatusChanged = onStatusChanged;
    _channel.setMethodCallHandler(_handleNativeCall);
    _setStatus('Initializing voice control');
    try {
      _isInitialized = await _channel.invokeMethod<bool>('initialize') ?? false;
    } on MissingPluginException {
      _isInitialized = false;
    } on PlatformException catch (error) {
      _isInitialized = false;
      _setStatus('Voice control error: ${error.message ?? error.code}');
    }
    if (_isInitialized) {
      _setStatus('Ready to listen');
      if (_shouldListen && !_isTtsSpeaking) {
        await _startListeningIfNeeded();
      }
    } else if (!_disposed) {
      _setStatus(
          'Microphone permission required or speech recognition unavailable');
    }
    return _isInitialized;
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (_disposed) return;
    switch (call.method) {
      case 'onRecognitionResult':
        _isListening = false;
        final text = call.arguments as String?;
        debugPrint('[voice] Android exact recognition result: "${text ?? ''}"');
        if (text != null && text.trim().isNotEmpty) {
          try {
            debugPrint('[voice] Dispatching command to HomeScreen');
            await _onResult?.call(text.toLowerCase());
          } finally {
            await _startListeningIfNeeded();
          }
        } else {
          await _startListeningIfNeeded();
        }
      case 'onRecognitionError':
        _isListening = false;
        final error = call.arguments;
        final code =
            error is Map ? error['code']?.toString() : error?.toString();
        final message = error is Map ? error['message']?.toString() : null;
        debugPrint('[voice] Android recognition error: $code ${message ?? ''}');
        if (code == 'permission_denied' || code == 'unavailable') {
          _isInitialized = false;
          _setStatus(message ?? 'Speech recognition unavailable');
        } else {
          _setStatus(
              message ?? 'Listening paused; restarting speech recognition');
          _scheduleRestart();
        }
      case 'onRecognitionState':
        final state = call.arguments?.toString() ?? 'ready';
        _isListening = state == 'listening';
        if (state == 'permission_denied' || state == 'unavailable') {
          _isInitialized = false;
        }
        _setStatus(_statusForNativeState(state));
      case 'onPermissionResult':
        final granted = call.arguments == true;
        _isInitialized = granted;
        _setStatus(
            granted ? 'Ready to listen' : 'Microphone permission denied');
        if (granted && _shouldListen && !_isTtsSpeaking) {
          await _startListeningIfNeeded();
        }
      case 'onListening':
        _isListening = call.arguments == true;
        _setStatus(
            _isListening ? 'Listening for voice commands' : 'Ready to listen');
    }
  }

  String _statusForNativeState(String state) {
    switch (state) {
      case 'listening':
        return 'Listening for voice commands';
      case 'processing':
        return 'Processing voice command';
      case 'permission_denied':
        return 'Microphone permission denied';
      case 'unavailable':
        return 'Speech recognition unavailable';
      case 'error':
        return 'Speech recognition restarting';
      default:
        return _isTtsSpeaking ? 'Speaking' : 'Ready to listen';
    }
  }

  void _setStatus(String status) {
    if (!_disposed) _onStatusChanged?.call(status);
  }

  Future<bool> startListening(VoiceCommandHandler onResult) async {
    _onResult = onResult;
    _shouldListen = true;
    if (!_isInitialized || _isTtsSpeaking) return false;
    return _startListeningIfNeeded();
  }

  Future<bool> _startListeningIfNeeded() async {
    if (!_shouldListen ||
        !_isInitialized ||
        _isTtsSpeaking ||
        _isListening ||
        _startInProgress ||
        _disposed) {
      return _isListening;
    }
    _startInProgress = true;
    try {
      debugPrint('[voice] Requesting Android recognition session');
      _isListening =
          await _channel.invokeMethod<bool>('startListening') ?? false;
      if (_isListening) _setStatus('Listening for voice commands');
      debugPrint('[voice] Android startListening accepted=$_isListening');
      if (!_isListening && _shouldListen) _scheduleRestart();
      return _isListening;
    } on MissingPluginException {
      _isInitialized = false;
      _setStatus('Speech recognition unavailable');
      return false;
    } on PlatformException catch (error) {
      _isListening = false;
      _setStatus('Speech recognition error: ${error.message ?? error.code}');
      if (_shouldListen) _scheduleRestart();
      return false;
    } finally {
      _startInProgress = false;
    }
  }

  void _scheduleRestart() {
    if (_restartTimer?.isActive == true ||
        !_shouldListen ||
        !_isInitialized ||
        _isTtsSpeaking ||
        _disposed) {
      return;
    }
    _restartTimer = Timer(const Duration(milliseconds: 500), () {
      _restartTimer = null;
      _startListeningIfNeeded();
    });
  }

  Future<void> stopListening() async {
    _shouldListen = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    _isListening = false;
    if (!_isInitialized) return;
    try {
      await _channel.invokeMethod<bool>('stopListening');
    } on PlatformException {
      _setStatus('Ready to listen');
    }
  }

  Future<void> setTtsSpeaking(bool speaking) async {
    _isTtsSpeaking = speaking;
    if (speaking) {
      _restartTimer?.cancel();
      _restartTimer = null;
    }
    if (_isInitialized) {
      try {
        await _channel.invokeMethod<void>('setTtsSpeaking', speaking);
      } on PlatformException {
        // A failed pause must not prevent the Flutter recognition state recovering.
      }
    }
    if (speaking) {
      _isListening = false;
      _setStatus('Speaking');
    } else {
      await _startListeningIfNeeded();
    }
  }

  Future<void> requestCameraPermission() async {
    if (!_isInitialized) return;
    try {
      await _channel.invokeMethod<void>('requestCameraPermission');
    } on PlatformException {
      // Camera permission is also requested by CameraController.
    }
  }

  bool isReady() => _isInitialized;

  bool isListening() => _isListening;

  String getStatus() {
    if (!_isInitialized) return 'Speech recognition unavailable';
    return _isListening ? 'Listening for voice commands' : 'Ready to listen';
  }

  void dispose() {
    _disposed = true;
    _shouldListen = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    _onResult = null;
    _onStatusChanged = null;
    _isListening = false;
    _isInitialized = false;
    _channel.setMethodCallHandler(null);
    _channel.invokeMethod<void>('stopListening');
  }
}
