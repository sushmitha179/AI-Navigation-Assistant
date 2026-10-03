import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/detection_model.dart';
import '../services/backend_service.dart';
import '../services/camera_service.dart';
import '../services/voice_service.dart';
import '../services/speech_recognition_service.dart';
import '../models/navigation_model.dart';

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
  String _statusMessage = 'Assistant Ready';
  String _navigationMessage = 'Waiting to start...';
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

  // Voice services
  late final VoiceService _voiceService;
  late final SpeechRecognitionService _speechRecognitionService;
  late final BackendService _backendService;
  late final CameraService _cameraService;

  // Color constants for high contrast
  static const Color _primaryColor = Colors.blue;
  static const Color _startButtonColor = Colors.green;
  static const Color _stopButtonColor = Colors.red;
  static const Color _backgroundColor = Colors.white;

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
    _initializeVoiceServices();
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
    if (ttsInitialized) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await _speakWithPause(
        'AI Navigation Assistant is ready. Say start assistance to begin.',
      );
    }

    final speechInitialized = await _speechRecognitionService.initialize(
      onStatusChanged: (status) {
        if (mounted) setState(() => _voiceControlStatus = status);
      },
    );
    await _speechRecognitionService.startListening(_processVoiceCommand);
    if (mounted && !speechInitialized) {
      setState(() => _voiceControlStatus =
          'Microphone permission required or speech recognition unavailable');
    }
  }

  Future<void> _speakWithPause(String text) async {
    await _speechRecognitionService.setTtsSpeaking(true);
    try {
      await _voiceService.speak(text);
      if (!widget.skipSpeechPause) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      await _speechRecognitionService.setTtsSpeaking(false);
    }
  }

  Future<void> _processVoiceCommand(String command) async {
    final normalized = command
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    final words = normalized.split(' ');
    debugPrint('[voice] HomeScreen recognized text: "$command"');
    if (words.contains('stop')) {
      debugPrint('[voice] Dispatching stop-assistance command');
      await _stopAssistant();
    } else if (normalized.contains('repeat instruction') ||
        words.contains('repeat')) {
      await _speakWithPause(_lastInstruction);
    } else if (words.contains('read') &&
        (words.contains('sign') || words.contains('text'))) {
      await _readSign();
    } else if (_isSceneQuestion(words)) {
      await _answerSceneQuestion(words);
    } else if (words.contains('start')) {
      debugPrint('[voice] Dispatching start-assistance command');
      await _startAssistant();
    } else if (words.contains('help')) {
      await _speakHelp();
    }
  }

  Future<void> _speakHelp() async {
    await _speakWithPause(
      'Available commands: start assistance, stop assistance, read sign, ask what is in front, left, or right, repeat instruction, and help.',
    );
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

  bool _isSceneQuestion(List<String> words) {
    final asksAboutObjects =
        words.contains('what') || words.contains('see') || words.contains('is');
    final asksObstacle = words.contains('obstacle');
    final hasDirection = words.any(
      (word) => {'front', 'ahead', 'left', 'right'}.contains(word),
    );
    return asksObstacle || (asksAboutObjects && hasDirection);
  }

  Future<void> _readSign() async {
    if (!_isAssistantRunning) {
      await _speakWithPause('Start assistance before reading a sign.');
      return;
    }
    final generation = _assistantGeneration;
    final image = await _cameraService.captureSnapshot();
    if (image == null ||
        !_isAssistantRunning ||
        generation != _assistantGeneration) {
      if (!_isAssistantRunning || generation != _assistantGeneration) return;
      await _speakWithPause(
        'I could not capture the sign. Hold the phone steady and say read sign to retry.',
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
          'I could not read that sign clearly. Hold the phone steady and say read sign to retry.',
        );
        return;
      }
      await _speakWithPause('The sign says: ${reading.text}.');
    } catch (error) {
      debugPrint('[ocr] Sign reading failed: $error');
      await _speakWithPause(
        'Sign reading is unavailable. Check the backend connection and try again.',
      );
    }
  }

  Future<void> _answerSceneQuestion(List<String> words) async {
    final navigation = _latestNavigation;
    final navigationAt = _latestNavigationAt;
    if (!_isAssistantRunning ||
        navigation == null ||
        navigationAt == null ||
        DateTime.now().difference(navigationAt) > const Duration(seconds: 6)) {
      await _speakWithPause(
        'I do not have a recent camera view. Start assistance and ask again.',
      );
      return;
    }

    final asksObstacle = words.contains('obstacle');
    final position = words.contains('left')
        ? 'LEFT'
        : words.contains('right')
            ? 'RIGHT'
            : 'CENTER';
    final matches = navigation.detections
        .where((detection) =>
            detection.horizontalPosition.toUpperCase() == position)
        .toList(growable: false);

    if (matches.isEmpty) {
      final area = _cameraArea(position);
      await _speakWithPause(
        'No object was detected in the $area. This does not confirm the walking route is clear.',
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
        hasRisk
            ? 'Potential obstacle on the $area. $descriptions. This is camera-relative, not mapped route guidance.'
            : 'Objects detected on the $area, with low reported collision risk. $descriptions. This does not confirm the route is clear.',
      );
      return;
    }

    await _speakWithPause(
      'Camera view: $descriptions. Positions are relative to the image, not a mapped route.',
    );
  }

  String _cameraArea(String position) {
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
        title: const Text(
          'AI Navigation Assistant',
          style: TextStyle(
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
          label: 'Assistance screen',
          value: _statusMessage,
          hint:
              'Tap the screen to ${_isAssistantRunning ? 'stop' : 'start'} assistance',
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
            const Text(
              'ASSISTANT STATUS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _statusMessage,
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
            const Text(
              'NAVIGATION MESSAGE',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _navigationMessage,
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
              child: const Text(
                'START ASSISTANCE',
                style: TextStyle(
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
              child: const Text(
                'STOP ASSISTANCE',
                style: TextStyle(
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
    return const Column(
      children: [
        Divider(thickness: 2),
        SizedBox(height: 16),
        Text(
          'AI-Powered Intelligent Navigation Assistant',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'For Visually Impaired People',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
          textAlign: TextAlign.center,
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
      _navigationMessage = 'Connecting to navigation backend...';
    });

    try {
      await _speechRecognitionService.requestCameraPermission();
      if (!_isCurrentStart(generation)) return;

      final connected = await _backendService.connect();
      if (!_isCurrentStart(generation)) return;
      if (!connected) {
        throw StateError('Backend unavailable. Check the network connection.');
      }

      final cameraStarted = await _cameraService.start(
        onFrame: (frame) => _analyzeFrame(frame, generation),
      );
      if (!_isCurrentStart(generation)) {
        await _cameraService.stop();
        return;
      }
      if (!cameraStarted) {
        throw StateError('Camera unavailable. Check camera permissions.');
      }

      setState(() {
        _isStarting = false;
        _isAssistantRunning = true;
        _statusMessage = 'Assistant Running';
        _navigationMessage = 'Assistance started. Waiting for instructions...';
      });
      await _speakWithPause('Assistance started.');
    } catch (error) {
      if (_isCurrentStart(generation)) {
        await _cameraService.stop();
        await _backendService.disconnect();
        if (mounted && generation == _assistantGeneration) {
          setState(() {
            _isStarting = false;
            _isAssistantRunning = false;
            _statusMessage = 'Assistant Error';
            _navigationMessage = 'Unable to start assistance: $error';
          });
          await _speakWithPause('Unable to start assistance. $error');
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
            'Navigation analysis is unavailable. Do not rely on guidance until the connection recovers.',
          );
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

    final actionText = navigation.action == 'CAUTION / SLOW DOWN'
        ? 'Caution. Slow down.'
        : '${navigation.action[0]}${navigation.action.substring(1).toLowerCase()}.';
    final announcement = urgent
        ? 'Warning. $actionText ${navigation.reason}. ${_describeCurrentScene(navigation)}'
        : navigation.action == 'CONTINUE'
            ? _describeCurrentScene(navigation)
            : 'Camera-based suggestion: $actionText ${navigation.reason}. This is not a mapped route.';

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
      return 'No objects were detected in the current camera view. This does not confirm the walking route is clear.';
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
    return hasReportedHazard
        ? 'Nearby ${selected.first.collisionRisk.toLowerCase()}-risk scene: $descriptions. Positions are image-relative; depth is relative, not distance in meters.'
        : 'Detected in the camera view: $descriptions. Positions are image-relative; this does not confirm the route is clear.';
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
      _statusMessage = 'Assistant Stopped';
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
    await _speakWithPause('Assistance stopped.');
  }
}
