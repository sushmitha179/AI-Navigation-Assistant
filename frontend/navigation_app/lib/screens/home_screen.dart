import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/detection_model.dart';
import '../services/backend_service.dart';
import '../services/camera_service.dart';
import '../services/voice_service.dart';
import '../services/speech_recognition_service.dart';
import '../services/localization_service.dart';
import '../models/navigation_model.dart';
import '../l10n/assistant_language.dart';
import 'language_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.skipSpeechPause = false,
    this.backendService,
    this.cameraService,
    this.voiceService,
    this.speechRecognitionService,
    this.hapticFeedback,
    this.enableHapticDiagnostic = const bool.fromEnvironment('HAPTIC_TEST'),
  });

  @visibleForTesting
  final bool skipSpeechPause;

  @visibleForTesting
  final BackendService? backendService;

  @visibleForTesting
  final CameraService? cameraService;

  @visibleForTesting
  final VoiceService? voiceService;

  @visibleForTesting
  final SpeechRecognitionService? speechRecognitionService;

  @visibleForTesting
  final Future<void> Function(bool highRisk)? hapticFeedback;

  @visibleForTesting
  final bool enableHapticDiagnostic;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Assistant state
  bool _isAssistantRunning = false;
  bool _isStarting = false;
  String _statusMessage = '';
  String _navigationMessage = '';
  String _voiceControlStatus = 'Voice control starting';
  String _lastInstruction = 'No navigation instruction is available yet.';
  NavigationModel? _latestNavigation;
  String? _lastAnnouncedNavigationKey;
  DateTime? _lastNavigationAnnouncementAt;
  DateTime? _lastAnalysisErrorAnnouncementAt;
  DateTime? _latestNavigationAt;
  DateTime? _lastHapticAt;
  String? _lastHapticSignature;
  int _assistantGeneration = 0;
  AssistantLanguage _spokenLanguage = AssistantLanguage.english;

  // Voice services
  late final VoiceService _voiceService;
  late final SpeechRecognitionService _speechRecognitionService;
  late final BackendService _backendService;
  late final CameraService _cameraService;
  final LocalizationService _localizationService = LocalizationService();

  AssistantLanguage get _assistantLanguage {
    return switch (_localizationService.currentLanguage) {
      AppLanguage.telugu => AssistantLanguage.telugu,
      AppLanguage.hindi => AssistantLanguage.hindi,
      _ => AssistantLanguage.english,
    };
  }

  AssistantLocalizations get _assistantLocalizations =>
      AssistantLocalizations(_assistantLanguage);
  AssistantLocalizations get _spokenLocalizations =>
      AssistantLocalizations(_spokenLanguage);

  // Color constants for high contrast
  static const Color _primaryColor = Colors.blue;
  static const Color _startButtonColor = Colors.green;
  static const Color _stopButtonColor = Colors.red;
  static const Color _backgroundColor = Colors.white;

  Future<void> _reconfigureLanguageServices() async {
    await _localizationService.init();
    final lang = _localizationService.currentLanguage;
    final languageData = _localizationService.getLanguageData(
      lang ?? AppLanguage.english,
    );
    final voiceAvailable =
        await _voiceService.setLanguage(languageData.ttsLanguage);
    _spokenLanguage =
        voiceAvailable ? _assistantLanguage : AssistantLanguage.english;
    await _speechRecognitionService.stopListening();
    await _speechRecognitionService.setLanguage(
      languageData.speechRecognizerLanguage,
    );
    await _speechRecognitionService.startListening(
      _processVoiceCommand,
      languageTag: languageData.speechRecognizerLanguage,
    );
  }

  @override
  void initState() {
    super.initState();
    // Initialize backend service with configured URL
    const backendUrl = String.fromEnvironment(
      'BACKEND_URL',
      defaultValue: 'http://192.168.1.100:8000',
    );
    _backendService =
        widget.backendService ?? BackendService(baseUrl: backendUrl);
    _cameraService = widget.cameraService ?? CameraService();
    _voiceService = widget.voiceService ?? VoiceService();
    _speechRecognitionService =
        widget.speechRecognitionService ?? SpeechRecognitionService();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _localizationService.init();
    if (!mounted) return;
    setState(() {
      _statusMessage = _localizationService.getMessage('assistant_ready');
      _navigationMessage = _localizationService.getMessage('waiting_to_start');
    });
    await _initializeVoiceServices();
  }

  @override
  void dispose() {
    _cameraService.stop();
    _backendService.disconnect();
    _voiceService.dispose();
    _speechRecognitionService.dispose();
    super.dispose();
  }

  Future<void> _initializeVoiceServices() async {
    final ttsInitialized = await _voiceService.initialize();
    if (!mounted) return;
    final lang = _localizationService.currentLanguage;
    if (ttsInitialized && lang != null) {
      final langData = _localizationService.getLanguageData(lang);
      final voiceAvailable =
          await _voiceService.setLanguage(langData.ttsLanguage);
      _spokenLanguage =
          voiceAvailable ? _assistantLanguage : AssistantLanguage.english;
    }
    if (ttsInitialized) {
      if (!widget.skipSpeechPause) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted) return;
      await _speakWithPause(_spokenLocalizations.text('welcome'));
      if (lang != null && _spokenLanguage == AssistantLanguage.english) {
        await _speakWithPause(_spokenLocalizations.text('ttsFallback'));
      }
    }

    // Configure speech recognition language
    if (lang != null) {
      final langData = _localizationService.getLanguageData(lang);
      await _speechRecognitionService
          .setLanguage(langData.speechRecognizerLanguage);
    }

    final speechInitialized = await _speechRecognitionService.initialize(
      onStatusChanged: (status) {
        if (mounted) setState(() => _voiceControlStatus = status);
      },
      onError: (code, message) {
        if (code == 'language_fallback' && mounted) {
          setState(() => _voiceControlStatus =
              'Selected speech recognition is unavailable. English commands are also accepted.');
          unawaited(_speakWithPause(
            _spokenLocalizations.text('speechFallback'),
          ));
        }
      },
    );
    if (lang != null) {
      final langData = _localizationService.getLanguageData(lang);
      await _speechRecognitionService.startListening(
        _processVoiceCommand,
        languageTag: langData.speechRecognizerLanguage,
      );
    } else {
      await _speechRecognitionService.startListening(_processVoiceCommand);
    }
    if (mounted && !speechInitialized) {
      setState(() => _voiceControlStatus =
          'Microphone or speech recognition unavailable. Use the English controls.');
    }
  }

  Future<void> _speakWithPause(String text) async {
    await _speechRecognitionService.setTtsSpeaking(true);
    try {
      if (_voiceService.activeLanguageTag == 'en-US' &&
          _spokenLanguage != AssistantLanguage.english) {
        await _voiceService.setLanguage('en-US');
        _spokenLanguage = AssistantLanguage.english;
      }
      await _voiceService.speak(text);
      if (!widget.skipSpeechPause) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      await _speechRecognitionService.setTtsSpeaking(false);
    }
  }

  Future<void> _processVoiceCommand(String command) async {
    final localized = _assistantLocalizations;
    const english = AssistantLocalizations(AssistantLanguage.english);
    debugPrint('[voice] HomeScreen recognized text: "$command"');
    if (localized.isChangeLanguage(command) ||
        english.isChangeLanguage(command)) {
      await _changeLanguage();
    } else if (localized.isStop(command) || english.isStop(command)) {
      debugPrint('[voice] Dispatching stop-assistance command');
      await _stopAssistant();
    } else if (localized.isRepeat(command) || english.isRepeat(command)) {
      await _speakWithPause(_lastInstruction);
    } else if (localized.isReadSign(command) || english.isReadSign(command)) {
      await _readSign();
    } else if (_isSceneQuestion(command) || _isEnglishSceneQuestion(command)) {
      await _answerSceneQuestion(command);
    } else if (localized.isStart(command) || english.isStart(command)) {
      debugPrint('[voice] Dispatching start-assistance command');
      await _startAssistant();
    } else if (localized.isHelp(command) || english.isHelp(command)) {
      await _speakHelp();
    }
  }

  Future<void> _speakHelp() async {
    await _speakWithPause(_spokenLocalizations.text('help'));
  }

  bool _isEnglishSceneQuestion(String command) {
    const english = AssistantLocalizations(AssistantLanguage.english);
    return english.questionPosition(command) != null ||
        english.isObstacleQuestion(command);
  }

  Future<void> _changeLanguage() async {
    if (_isAssistantRunning || _isStarting) {
      await _stopAssistant();
    }
    await _speechRecognitionService.stopListening();
    await _voiceService.setLanguage('en-US');
    _spokenLanguage = AssistantLanguage.english;
    await _speakWithPause(
      'Changing spoken language. Say English, Telugu, or Hindi.',
    );
    if (!mounted) return;
    await Navigator.of(context).push<AssistantLanguage>(
      MaterialPageRoute(
        builder: (_) => LanguageSelectionScreen(
          voiceService: _voiceService,
          speechRecognitionService: _speechRecognitionService,
          localizationService: _localizationService,
        ),
      ),
    );
    if (!mounted) return;
    await _reconfigureLanguageServices();
    if (mounted) {
      setState(() {
        _statusMessage = _localizationService.getMessage('assistant_ready');
        _navigationMessage =
            _localizationService.getMessage('waiting_to_start');
      });
    }
  }

  Future<void> _speakRecognizedText(String text) async {
    final languageTag = _textLocale(text);
    if (languageTag == null) {
      await _speakWithPause(
          _spokenLocalizations.text('spokenTextVoiceMissing'));
      return;
    }
    await _speechRecognitionService.setTtsSpeaking(true);
    try {
      final success =
          await _voiceService.speakTextInLanguage(text, languageTag);
      if (!success) {
        final currentLanguage = _localizationService.currentLanguage;
        final restored = await _voiceService.setLanguage(
          _localizationService
              .getLanguageData(currentLanguage ?? AppLanguage.english)
              .ttsLanguage,
        );
        _spokenLanguage =
            restored ? _assistantLanguage : AssistantLanguage.english;
        await _voiceService.speak(
          _spokenLocalizations.text('spokenTextVoiceMissing'),
        );
      }
    } finally {
      await _speechRecognitionService.setTtsSpeaking(false);
    }
  }

  String? _textLocale(String text) {
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) return 'te-IN';
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) return 'hi-IN';
    if (RegExp(r'[A-Za-z]').hasMatch(text)) return 'en-US';
    return null;
  }

  Future<void> _runHapticDiagnostic() async {
    await _sendHaptic(
      true,
      'diagnostic-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<void> _sendHaptic(bool highRisk, String signature) async {
    try {
      final testHaptic = widget.hapticFeedback;
      if (testHaptic != null) {
        await testHaptic(highRisk);
      } else {
        final started = await _speechRecognitionService.triggerRiskHaptic(
          highRisk: highRisk,
          signature: signature,
        );
        if (!started) debugPrint('[haptics] Device did not start vibration');
      }
    } catch (error) {
      debugPrint('[haptics] Vibration feedback unavailable: $error');
    }
  }

  bool _isSceneQuestion(String command) {
    final localizations = _assistantLocalizations;
    return localizations.questionPosition(command) != null ||
        localizations.isObstacleQuestion(command);
  }

  Future<void> _readSign() async {
    if (!_isAssistantRunning) {
      await _speakWithPause(_spokenLocalizations.text('readSignStart'));
      return;
    }
    final generation = _assistantGeneration;
    final image = await _cameraService.captureSnapshot();
    if (image == null ||
        !_isAssistantRunning ||
        generation != _assistantGeneration) {
      if (!_isAssistantRunning || generation != _assistantGeneration) return;
      await _speakWithPause(
        _spokenLocalizations.text('captureRetry'),
      );
      return;
    }
    try {
      final reading = await _backendService.readSign(image);
      if (!mounted ||
          !_isAssistantRunning ||
          generation != _assistantGeneration) {
        return;
      }
      if (reading.text.trim().isEmpty || reading.confidence < 0.60) {
        await _speakWithPause(
          _spokenLocalizations.text('ocrRetry'),
        );
        return;
      }
      await _speakWithPause(_spokenLocalizations.text('signSaysPrefix'));
      await _speakRecognizedText(reading.text);
    } catch (error) {
      debugPrint('[ocr] Sign reading failed: $error');
      await _speakWithPause(
        _spokenLocalizations.text('ocrUnavailable'),
      );
    }
  }

  Future<void> _answerSceneQuestion(String command) async {
    final localizations = _assistantLocalizations;
    final normalized = localizations.normalizeCommand(command);
    final words = normalized.split(' ');
    final navigation = _latestNavigation;
    final navigationAt = _latestNavigationAt;
    if (!_isAssistantRunning ||
        navigation == null ||
        navigationAt == null ||
        DateTime.now().difference(navigationAt) > const Duration(seconds: 6)) {
      await _speakWithPause(
        _spokenLocalizations.text('questionUnavailable'),
      );
      return;
    }

    final asksObstacle = localizations.isObstacleQuestion(command);
    final questionPosition = localizations.questionPosition(command);
    final position = switch (questionPosition) {
      SceneQuestionPosition.left => 'LEFT',
      SceneQuestionPosition.right => 'RIGHT',
      _ => words.contains('left')
          ? 'LEFT'
          : words.contains('right')
              ? 'RIGHT'
              : 'CENTER',
    };
    final matches = questionPosition == SceneQuestionPosition.nearby
        ? navigation.detections
        : navigation.detections
            .where((detection) =>
                detection.horizontalPosition.toUpperCase() == position)
            .toList(growable: false);

    if (matches.isEmpty) {
      final area = _cameraArea(position);
      await _speakWithPause(
        _spokenLocalizations.text(
          'noObjectAtArea',
          {'area': area},
        ),
      );
      return;
    }

    final descriptions = matches.take(3).map(_describeDetection).join('. ');
    if (asksObstacle) {
      final area = _cameraArea(position);
      final risks = matches
          .map((detection) => detection.collisionRisk.toUpperCase())
          .toSet();
      final hasRisk = risks.any((risk) => risk == 'HIGH' || risk == 'MEDIUM');
      await _speakWithPause(
        _spokenLocalizations.text(
          hasRisk ? 'obstacleAtArea' : 'lowRiskAtArea',
          {'area': area, 'objects': descriptions},
        ),
      );
      return;
    }

    await _speakWithPause(
      _spokenLocalizations.text('cameraSummary', {'objects': descriptions}),
    );
  }

  String _cameraArea(String position) {
    if (_spokenLanguage != AssistantLanguage.english) {
      return _spokenLocalizations.area(switch (position) {
        'LEFT' => SceneQuestionPosition.left,
        'RIGHT' => SceneQuestionPosition.right,
        _ => SceneQuestionPosition.front,
      });
    }
    switch (position) {
      case 'LEFT':
        return 'left side of the current camera view';
      case 'RIGHT':
        return 'right side of the current camera view';
      default:
        return 'center of the current camera view';
    }
  }

  String _describeDetection(DetectionModel detection) {
    final position = detection.horizontalPosition.toUpperCase();
    final area = _cameraArea(position);
    if (_spokenLanguage != AssistantLanguage.english) {
      final localizations = _spokenLocalizations;
      return localizations.text('detection', {
        'object': localizations.objectName(detection.className),
        'area': area,
        'risk': localizations.risk(detection.collisionRisk),
        'proximity': localizations.proximity(detection.proximityCategory),
      });
    }
    final risk = detection.collisionRisk.trim().toUpperCase();
    final riskText = const {'HIGH', 'MEDIUM', 'LOW'}.contains(risk)
        ? '${risk.toLowerCase()} reported risk'
        : 'risk unavailable';
    final proximity = detection.proximityCategory?.trim().toUpperCase();
    final proximityText =
        const {'VERY CLOSE', 'CLOSE', 'MEDIUM', 'FAR'}.contains(proximity)
            ? 'relative proximity ${proximity!.toLowerCase()}'
            : 'relative depth unavailable';
    return '${detection.className} at the $area, $riskText, $proximityText';
  }

  Future<void> _toggleAssistant() async {
    if (_isStarting) return;
    if (_isAssistantRunning) {
      await _stopAssistant();
    } else {
      await _startAssistant();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          _localizationService.getMessage('app_title'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 2,
      ),
      body: SafeArea(
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Navigation assistance screen',
          value: _statusMessage,
          hint: _isAssistantRunning
              ? 'Tap the screen to stop assistance'
              : 'Tap the screen to start assistance',
          onTap: _toggleAssistant,
          child: GestureDetector(
            key: const ValueKey('assistance-tap-surface'),
            behavior: HitTestBehavior.opaque,
            onTap: _toggleAssistant,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusSection(),
                    const SizedBox(height: 20),
                    _buildNavigationMessageSection(),
                    const SizedBox(height: 24),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Column(
                        children: [
                          _buildControlButtons(),
                          if (widget.enableHapticDiagnostic)
                            TextButton.icon(
                              key: const ValueKey('haptic-diagnostic'),
                              onPressed: _runHapticDiagnostic,
                              icon: const Icon(Icons.vibration),
                              label: const Text('Test vibration'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Semantics(
      label: 'Assistant status',
      value: _statusMessage,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _isAssistantRunning
              ? Colors.green.shade100
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isAssistantRunning ? Colors.green : Colors.grey,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              _localizationService.getMessage('assistant_status'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage.isNotEmpty
                  ? _statusMessage
                  : _localizationService.getMessage('assistant_ready'),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _isAssistantRunning
                    ? Colors.green.shade800
                    : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _voiceControlStatus,
              key: const ValueKey('voice-control-status'),
              style: const TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationMessageSection() {
    return Semantics(
      label: 'Navigation message',
      value: _navigationMessage,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _localizationService.getMessage('navigation_message'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _navigationMessage.isNotEmpty
                  ? _navigationMessage
                  : _localizationService.getMessage('waiting_to_start'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        // START Button
        Semantics(
          button: true,
          label: 'Start assistance',
          hint: 'Double tap to start navigation assistance',
          child: SizedBox(
            height: 72,
            child: ElevatedButton(
              onPressed: _isAssistantRunning ? null : _startAssistant,
              style: ElevatedButton.styleFrom(
                backgroundColor: _startButtonColor,
                disabledBackgroundColor: Colors.grey,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _localizationService.getMessage('start_assistance'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // STOP Button
        Semantics(
          button: true,
          label: 'Stop assistance',
          hint: 'Double tap to stop navigation assistance',
          child: SizedBox(
            height: 72,
            child: ElevatedButton(
              onPressed: _isAssistantRunning ? _stopAssistant : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _stopButtonColor,
                disabledBackgroundColor: Colors.grey,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _localizationService.getMessage('stop_assistance'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(thickness: 2),
        const SizedBox(height: 16),
        const Text(
          'AI-Powered Intelligent Navigation Assistant',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'For visually impaired people',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: 'Change spoken language',
          hint: 'Double tap to change language',
          child: TextButton(
            onPressed: _changeLanguage,
            child: const Text(
              'CHANGE SPOKEN LANGUAGE',
              style: TextStyle(
                fontSize: 18,
                color: Colors.blue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startAssistant() async {
    if (_isAssistantRunning || _isStarting) return;
    final generation = ++_assistantGeneration;
    _latestNavigation = null;
    _latestNavigationAt = null;
    _lastAnnouncedNavigationKey = null;
    _lastNavigationAnnouncementAt = null;
    setState(() {
      _isStarting = true;
      _statusMessage = 'Assistant Starting';
      _navigationMessage =
          _localizationService.getMessage('connecting_backend');
    });

    try {
      await _speechRecognitionService.requestCameraPermission();
      if (!_isCurrentStart(generation)) return;

      final connected = await _backendService.connect();
      if (!_isCurrentStart(generation)) return;
      if (!connected) {
        throw StateError(
            _localizationService.getMessage('backend_unavailable'));
      }

      final cameraStarted = await _cameraService.start(
        onFrame: (frame) => _analyzeFrame(frame, generation),
      );
      if (!_isCurrentStart(generation)) {
        await _cameraService.stop();
        return;
      }
      if (!cameraStarted) {
        throw StateError(_localizationService.getMessage('camera_unavailable'));
      }

      setState(() {
        _isStarting = false;
        _isAssistantRunning = true;
        _statusMessage = _localizationService.getMessage('assistant_running');
        _navigationMessage = 'Assistance started. Waiting for instructions...';
      });
      await _speakWithPause(_spokenLocalizations.text('started'));
    } catch (error) {
      if (_isCurrentStart(generation)) {
        await _cameraService.stop();
        await _backendService.disconnect();
        if (mounted && generation == _assistantGeneration) {
          setState(() {
            _isStarting = false;
            _isAssistantRunning = false;
            _statusMessage = 'Assistant Error';
            _navigationMessage =
                '${_localizationService.getMessage('camera_error')}: $error';
          });
          await _speakWithPause(_spokenLocalizations.text('startFailed'));
        }
      }
    } finally {
      if (mounted && generation == _assistantGeneration && _isStarting) {
        setState(() => _isStarting = false);
      }
    }
  }

  bool _isCurrentStart(int generation) {
    return mounted && generation == _assistantGeneration && _isStarting;
  }

  Future<void> _analyzeFrame(Uint8List frame, int generation) async {
    if (!_isAssistantRunning || generation != _assistantGeneration) return;
    try {
      final navigation = await _backendService.processFrame(frame);
      if (!mounted ||
          !_isAssistantRunning ||
          generation != _assistantGeneration) {
        return;
      }
      _latestNavigation = navigation;
      _latestNavigationAt = DateTime.now();
      setState(() => _navigationMessage = navigation.reason);
      await _announceNavigation(navigation);
    } catch (error) {
      if (mounted &&
          _isAssistantRunning &&
          generation == _assistantGeneration) {
        _latestNavigation = null;
        _latestNavigationAt = null;
        setState(() => _navigationMessage = 'Navigation backend error: $error');
        final now = DateTime.now();
        if (_lastAnalysisErrorAnnouncementAt == null ||
            now.difference(_lastAnalysisErrorAnnouncementAt!) >=
                const Duration(seconds: 15)) {
          _lastAnalysisErrorAnnouncementAt = now;
          await _speakWithPause(
              _spokenLocalizations.text('analysisUnavailable'));
        }
      }
    }
  }

  Future<void> _announceNavigation(NavigationModel navigation) async {
    final detections = navigation.detections
        .map((detection) =>
            '${detection.className}|${detection.horizontalPosition}|${detection.collisionRisk}|${detection.proximityCategory}')
        .toList()
      ..sort();
    final signature = '${navigation.action}|${detections.join(';')}';
    final highRisk = navigation.action == 'STOP' ||
        navigation.priority.toUpperCase() == 'HIGH' ||
        navigation.detections.any((detection) =>
            detection.collisionRisk.toUpperCase() == 'HIGH' ||
            detection.proximityCategory?.toUpperCase() == 'VERY CLOSE');
    final mediumRisk = !highRisk &&
        (navigation.action == 'CAUTION / SLOW DOWN' ||
            navigation.priority.toUpperCase() == 'MEDIUM' ||
            navigation.detections.any((detection) =>
                detection.collisionRisk.toUpperCase() == 'MEDIUM'));
    final urgent = highRisk || mediumRisk;
    final now = DateTime.now();
    final elapsed = _lastNavigationAnnouncementAt == null
        ? null
        : now.difference(_lastNavigationAnnouncementAt!);
    final sameScene = signature == _lastAnnouncedNavigationKey;
    if (sameScene &&
        elapsed != null &&
        elapsed < Duration(seconds: urgent ? 4 : 12)) {
      return;
    }
    if (!urgent && elapsed != null && elapsed < const Duration(seconds: 6)) {
      return;
    }

    final announcement = navigation.action == 'CONTINUE'
        ? _describeCurrentScene(navigation)
        : '${_spokenLocalizations.navigationInstruction(
            navigation.action,
            _relevantObjectName(navigation),
          )} ${_spokenLocalizations.text('routeDisclaimer')}';

    _lastAnnouncedNavigationKey = signature;
    _lastNavigationAnnouncementAt = now;
    _lastInstruction = announcement;
    if (highRisk) {
      unawaited(_playRiskHaptic(true, 'high|$signature'));
    } else if (mediumRisk) {
      unawaited(_playRiskHaptic(false, 'medium|$signature'));
    } else if (_lastHapticAt != null) {
      // Clear obsolete lower-priority feedback, but native code protects an
      // active HIGH pattern from a non-forced stop request.
      unawaited(_speechRecognitionService.stopRiskHaptics());
    }
    await _speakWithPause(announcement);
  }

  Future<void> _playRiskHaptic(bool highRisk, String signature) async {
    final now = DateTime.now();
    if (_lastHapticSignature == signature &&
        _lastHapticAt != null &&
        now.difference(_lastHapticAt!) < const Duration(seconds: 4)) {
      return;
    }
    final lastWasHigh = _lastHapticSignature?.startsWith('high|') == true;
    if (_lastHapticAt != null &&
        now.difference(_lastHapticAt!) < const Duration(seconds: 3) &&
        (!highRisk || lastWasHigh)) {
      return;
    }
    _lastHapticAt = now;
    _lastHapticSignature = signature;
    await _sendHaptic(highRisk, signature);
  }

  String _describeCurrentScene(NavigationModel navigation) {
    if (navigation.detections.isEmpty) {
      return _spokenLocalizations.text('emptySummary');
    }
    final detections = [...navigation.detections]..sort((first, second) {
        final riskDifference =
            _riskRank(second.collisionRisk) - _riskRank(first.collisionRisk);
        if (riskDifference != 0) return riskDifference;
        return _proximityRank(second.proximityCategory) -
            _proximityRank(first.proximityCategory);
      });
    final selected = detections.take(2).toList(growable: false);
    final descriptions = selected.map(_describeDetection).join('. ');
    final hasReportedHazard = selected.any((detection) {
      final risk = detection.collisionRisk.toUpperCase();
      return risk == 'HIGH' || risk == 'MEDIUM';
    });
    if (hasReportedHazard) {
      return _spokenLocalizations.text('hazardSummary', {
        'risk': _spokenLocalizations.risk(selected.first.collisionRisk),
        'objects': descriptions,
      });
    }
    return _spokenLocalizations.text(
      'detectedSummary',
      {'objects': descriptions},
    );
  }

  String _relevantObjectName(NavigationModel navigation) {
    final relevantName = navigation.relevantObject;
    for (final detection in navigation.detections) {
      if (relevantName != null && detection.className == relevantName) {
        return _spokenLocalizations.objectName(detection.className);
      }
    }
    if (relevantName != null && relevantName != 'multiple obstacles') {
      return _spokenLocalizations.objectName(relevantName);
    }
    return _spokenLocalizations.objectName('obstacle');
  }

  int _riskRank(String risk) {
    switch (risk.toUpperCase()) {
      case 'HIGH':
        return 3;
      case 'MEDIUM':
        return 2;
      case 'LOW':
        return 1;
      default:
        return 0;
    }
  }

  int _proximityRank(String? proximity) {
    switch (proximity?.trim().toUpperCase()) {
      case 'VERY CLOSE':
        return 4;
      case 'CLOSE':
        return 3;
      case 'MEDIUM':
        return 2;
      case 'FAR':
        return 1;
      default:
        return 0;
    }
  }

  Future<void> _stopAssistant() async {
    if (!_isAssistantRunning && !_isStarting) return;
    ++_assistantGeneration;
    setState(() {
      _isStarting = false;
      _isAssistantRunning = false;
      _statusMessage = _localizationService.getMessage('assistant_stopped');
      _navigationMessage = 'Assistance stopped. Ready to start again.';
    });
    _latestNavigation = null;
    _latestNavigationAt = null;
    await Future.wait([
      _cameraService.stop(),
      _backendService.disconnect(),
      _voiceService.stop(),
      _speechRecognitionService.stopRiskHaptics(force: true),
    ]);
    await _speakWithPause(_spokenLocalizations.text('stopped'));
  }
}
