import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/models/detection_model.dart';
import 'package:navigation_app/models/navigation_model.dart';
import 'package:navigation_app/models/sign_reading.dart';
import 'package:navigation_app/screens/home_screen.dart';
import 'package:navigation_app/services/backend_service.dart';
import 'package:navigation_app/services/camera_service.dart';
import 'package:navigation_app/services/speech_recognition_service.dart';
import 'package:navigation_app/services/voice_service.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    testWidgets('HomeScreen renders correctly', (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      expect(find.text('AI Navigation Assistant'), findsOneWidget);
      expect(find.text('ASSISTANT STATUS'), findsOneWidget);
      expect(find.text('Assistant Ready'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'START ASSISTANCE'),
          findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'STOP ASSISTANCE'),
          findsOneWidget);
      expect(find.text('Listening for voice commands'), findsOneWidget);
    });

    testWidgets('START button changes status to Assistant Running',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      // Tap START button
      await tester.tap(find.widgetWithText(ElevatedButton, 'START ASSISTANCE'));
      await tester.pump();

      // Verify status changed
      expect(find.text('Assistant Running'), findsOneWidget);
      expect(find.text('Assistant Ready'), findsNothing);
    });

    testWidgets('STOP button changes status to Assistant Stopped',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      // First start the assistant
      await tester.tap(find.widgetWithText(ElevatedButton, 'START ASSISTANCE'));
      await tester.pump();

      // Then stop it
      await tester.tap(find.widgetWithText(ElevatedButton, 'STOP ASSISTANCE'));
      await tester.pump();

      // Verify status changed back
      expect(find.text('Assistant Stopped'), findsOneWidget);
      expect(find.text('Assistant Running'), findsNothing);
    });

    testWidgets('START button is disabled when assistant is running',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      // Start the assistant
      await tester.tap(find.widgetWithText(ElevatedButton, 'START ASSISTANCE'));
      await tester.pump();

      // Verify START button is disabled by checking if tapping has no effect
      await tester.tap(find.widgetWithText(ElevatedButton, 'START ASSISTANCE'));
      await tester.pump();

      // Status should still be "Assistant Running" (not changed again)
      expect(find.text('Assistant Running'), findsOneWidget);
    });

    testWidgets('STOP button is disabled when assistant is not running',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      // Verify STOP button is disabled initially by checking if tapping has no effect
      await tester.tap(find.widgetWithText(ElevatedButton, 'STOP ASSISTANCE'));
      await tester.pump();

      // Status should still be "Assistant Ready" (not changed)
      expect(find.text('Assistant Ready'), findsOneWidget);
      expect(harness.backend.connectCount, 0);
    });

    testWidgets('voice start and stop commands work repeatedly',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      await harness.speech.emit('Start assistance');
      await tester.pump();
      expect(find.text('Assistant Running'), findsOneWidget);
      await harness.speech.emit('Stop assistance');
      await tester.pump();
      expect(find.text('Assistant Stopped'), findsOneWidget);
      await harness.speech.emit('Start assistance');
      await tester.pump();
      expect(find.text('Assistant Running'), findsOneWidget);
      await harness.speech.emit('Stop assistance');
      await tester.pump();

      expect(harness.camera.startCount, 2);
      expect(harness.backend.connectCount, 2);
      expect(harness.camera.stopCount, 2);
      expect(harness.backend.disconnectCount, 2);
    });

    testWidgets('voice stop assistance invokes the shared stop path',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('Start assistance');
      await tester.pump();

      await harness.speech.emit('Stop assistance');
      await tester.pump();

      expect(find.text('Assistant Stopped'), findsOneWidget);
      expect(harness.camera.stopCount, 1);
      expect(harness.backend.disconnectCount, 1);
    });

    testWidgets('voice stop matching handles punctuation and phrase variants',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      for (final command in [
        'Start assistance',
        '  STOP!!!  ',
        'start',
        'stop navigation'
      ]) {
        await harness.speech.emit(command);
        await tester.pump();
      }

      expect(find.text('Assistant Stopped'), findsOneWidget);
      expect(harness.camera.startCount, 2);
      expect(harness.camera.stopCount, 2);
    });

    testWidgets('tapping the screen starts assistance',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      await tester.tap(find.text('ASSISTANT STATUS'));
      await tester.pump();

      expect(find.text('Assistant Running'), findsOneWidget);
      expect(harness.backend.connectCount, 1);
      expect(harness.camera.startCount, 1);
    });

    testWidgets('tapping the screen stops assistance and blocks uploads',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await tester.tap(find.text('ASSISTANT STATUS'));
      await tester.pump();

      await tester.tap(find.text('NAVIGATION MESSAGE'));
      await tester.pump();
      final uploadsAtStop = harness.backend.uploadCount;
      await harness.camera.emitFrame();

      expect(find.text('Assistant Stopped'), findsOneWidget);
      expect(harness.camera.stopCount, 1);
      expect(harness.backend.disconnectCount, 1);
      expect(harness.backend.uploadCount, uploadsAtStop);
    });

    testWidgets('repeated screen taps alternate start and stop',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      for (var cycle = 0; cycle < 2; cycle++) {
        await tester.tap(find.text('ASSISTANT STATUS'));
        await tester.pump();
        expect(find.text('Assistant Running'), findsOneWidget);
        await tester.tap(find.text('NAVIGATION MESSAGE'));
        await tester.pump();
        expect(find.text('Assistant Stopped'), findsOneWidget);
      }

      expect(harness.camera.startCount, 2);
      expect(harness.camera.stopCount, 2);
    });

    testWidgets('tap on disabled stop button does not start assistance',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'STOP ASSISTANCE'));
      await tester.pump();

      expect(find.text('Assistant Ready'), findsOneWidget);
      expect(harness.backend.connectCount, 0);
    });

    testWidgets('failed camera startup never announces running',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()..camera.startResult = false;
      await tester.pumpWidget(harness.build());
      await tester.pump();

      await harness.speech.emit('start');
      await tester.pump();

      expect(find.text('Assistant Error'), findsOneWidget);
      expect(harness.voice.spoken, isNot(contains('Assistance started.')));
    });

    testWidgets('repeat instruction speaks the latest navigation instruction',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start assistance');
      await tester.pump();
      await harness.camera.emitFrame();
      await tester.pump();

      await harness.speech.emit('Repeat instruction');
      await tester.pump();

      expect(harness.voice.spoken.last,
          contains('Warning. Stop. Obstacle ahead.'));
    });

    testWidgets('read sign captures once and speaks confident OCR text',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start assistance');
      await tester.pump();

      await harness.speech.emit('Read sign');
      await tester.pump();

      expect(harness.camera.snapshotCount, 1);
      expect(harness.backend.signReadCount, 1);
      expect(harness.voice.spoken.last, 'The sign says: EXIT 24 HOURS.');
      expect(harness.speech.ttsStates.last, isFalse);
    });

    testWidgets('low-confidence OCR gives a spoken retry instruction',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()
        ..backend.signReading =
            const SignReading(text: 'UNCLEAR', confidence: 0.3, wordCount: 1);
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();

      await harness.speech.emit('Read sign');
      await tester.pump();

      expect(harness.voice.spoken.last,
          contains('could not read that sign clearly'));
    });

    testWidgets('scene questions use current detections and camera positions',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();
      await harness.camera.emitFrame();
      await tester.pump();

      await harness.speech.emit('What is in front of me?');
      await tester.pump();
      expect(harness.voice.spoken.last, contains('person'));
      expect(harness.voice.spoken.last,
          contains('center of the current camera view'));
      expect(harness.voice.spoken.last, contains('not a mapped route'));

      await harness.speech.emit('What is on my left?');
      await tester.pump();
      expect(harness.voice.spoken.last, contains('chair'));
      expect(harness.voice.spoken.last,
          contains('left side of the current camera view'));

      await harness.speech.emit('What is on my right?');
      await tester.pump();
      expect(harness.voice.spoken.last, contains('bicycle'));
      expect(harness.voice.spoken.last,
          contains('right side of the current camera view'));

      await harness.speech.emit('Is there an obstacle ahead?');
      await tester.pump();
      expect(harness.voice.spoken.last, contains('Potential obstacle'));
      expect(harness.voice.spoken.last,
          contains('center of the current camera view'));

      await harness.speech.emit('Is there an obstacle on my left?');
      await tester.pump();
      expect(harness.voice.spoken.last,
          contains('left side of the current camera view'));
      expect(harness.voice.spoken.last,
          isNot(contains('center of the current camera view')));

      await harness.speech.emit('Is there an obstacle on my right?');
      await tester.pump();
      expect(harness.voice.spoken.last,
          contains('right side of the current camera view'));
    });

    testWidgets('scene question reports unavailable data instead of guessing',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()
        ..backend.navigation = const NavigationModel(
          action: 'CONTINUE',
          reason: 'No detected obstacles',
          priority: 'LOW',
          relevantObject: null,
          detections: [],
        );
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();
      await harness.camera.emitFrame();
      await tester.pump();

      await harness.speech.emit('What is on my left?');
      await tester.pump();

      expect(harness.voice.spoken.last, contains('No object was detected'));
      expect(harness.voice.spoken.last, contains('does not confirm'));
    });

    testWidgets('identical urgent navigation alert is not repeated each frame',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();

      await harness.camera.emitFrame();
      await tester.pump();
      final spokenAfterFirstWarning = harness.voice.spoken.length;
      await harness.camera.emitFrame();
      await tester.pump();

      expect(harness.voice.spoken.length, spokenAfterFirstWarning);
    });

    testWidgets('help command describes supported voice commands',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();

      await harness.speech.emit('help');

      expect(harness.voice.spoken.single, contains('start assistance'));
      expect(harness.voice.spoken.single, contains('read sign'));
      expect(harness.voice.spoken.single, contains('repeat instruction'));
    });

    testWidgets('backend analysis failure is announced as unavailable',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()..backend.failFrameAnalysis = true;
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();

      await harness.camera.emitFrame();
      await tester.pump();

      expect(harness.voice.spoken.last, contains('analysis is unavailable'));
      expect(harness.voice.spoken.last, isNot(contains('Continue.')));
    });

    testWidgets('late camera frames do not upload after stopping',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();
      final frameCallback = harness.camera.onFrame!;
      await harness.speech.emit('stop');
      await tester.pump();

      await frameCallback(Uint8List(0));
      await tester.pump();

      expect(harness.backend.uploadCount, 0);
      expect(find.text('Assistant Stopped'), findsOneWidget);
    });

    testWidgets('stop during backend startup prevents later camera startup',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()
        ..backend.connectCompleter = Completer<bool>();
      await tester.pumpWidget(harness.build());
      await tester.pump();
      final starting = harness.speech.emit('start');
      await tester.pump();
      await harness.speech.emit('stop');
      await tester.pump();
      harness.backend.connectCompleter!.complete(true);
      await starting;
      await tester.pump();

      expect(harness.camera.startCount, 0);
      expect(find.text('Assistant Stopped'), findsOneWidget);
    });
  });
}

class _HomeScreenHarness {
  final backend = _FakeBackendService();
  final camera = _FakeCameraService();
  final voice = _FakeVoiceService();
  final speech = _FakeSpeechRecognitionService();

  Widget build() => MaterialApp(
        home: HomeScreen(
          skipSpeechPause: true,
          backendService: backend,
          cameraService: camera,
          voiceService: voice,
          speechRecognitionService: speech,
        ),
      );
}

class _FakeBackendService extends BackendService {
  _FakeBackendService() : super(baseUrl: 'http://localhost');

  int connectCount = 0;
  int disconnectCount = 0;
  int uploadCount = 0;
  int signReadCount = 0;
  Completer<bool>? connectCompleter;
  NavigationModel navigation = const NavigationModel(
    action: 'STOP',
    reason: 'Obstacle ahead',
    priority: 'HIGH',
    relevantObject: 'person',
    detections: [
      DetectionModel(
        className: 'person',
        confidence: 0.95,
        collisionRisk: 'HIGH',
        horizontalPosition: 'CENTER',
        proximityCategory: 'CLOSE',
      ),
      DetectionModel(
        className: 'chair',
        confidence: 0.8,
        collisionRisk: 'LOW',
        horizontalPosition: 'LEFT',
        proximityCategory: null,
      ),
      DetectionModel(
        className: 'bicycle',
        confidence: 0.82,
        collisionRisk: 'MEDIUM',
        horizontalPosition: 'RIGHT',
        proximityCategory: null,
      ),
    ],
  );
  SignReading signReading =
      const SignReading(text: 'EXIT 24 HOURS', confidence: 0.91, wordCount: 3);
  bool failFrameAnalysis = false;

  @override
  Future<bool> connect() {
    connectCount++;
    return connectCompleter?.future ?? Future<bool>.value(true);
  }

  @override
  Future<bool> disconnect() async {
    disconnectCount++;
    return true;
  }

  @override
  Future<NavigationModel> processFrame(Uint8List frameData) async {
    uploadCount++;
    if (failFrameAnalysis) throw StateError('backend offline');
    return navigation;
  }

  @override
  Future<SignReading> readSign(Uint8List imageBytes) async {
    signReadCount++;
    return signReading;
  }
}

class _FakeCameraService extends CameraService {
  int startCount = 0;
  int stopCount = 0;
  int snapshotCount = 0;
  bool startResult = true;
  Future<void> Function(Uint8List frame)? onFrame;

  @override
  Future<bool> start({
    required Future<void> Function(Uint8List frame) onFrame,
    Duration interval = const Duration(seconds: 2),
  }) async {
    startCount++;
    this.onFrame = onFrame;
    return startResult;
  }

  @override
  Future<bool> stop() async {
    stopCount++;
    return true;
  }

  @override
  Future<Uint8List?> captureSnapshot({
    Duration waitTimeout = const Duration(seconds: 8),
  }) async {
    snapshotCount++;
    return Uint8List.fromList([1, 2, 3]);
  }

  Future<void> emitFrame() async => onFrame?.call(Uint8List(0));
}

class _FakeVoiceService extends VoiceService {
  final List<String> spoken = [];

  @override
  Future<bool> initialize() async => false;

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<bool> stop() async => true;

  @override
  void dispose() {}
}

class _FakeSpeechRecognitionService extends SpeechRecognitionService {
  VoiceCommandHandler? _handler;
  final List<bool> ttsStates = [];

  @override
  Future<bool> initialize({ValueChanged<String>? onStatusChanged}) async {
    onStatusChanged?.call('Listening for voice commands');
    return true;
  }

  @override
  Future<bool> startListening(VoiceCommandHandler onResult) async {
    _handler = onResult;
    return true;
  }

  @override
  Future<void> setTtsSpeaking(bool speaking) async {
    ttsStates.add(speaking);
  }

  @override
  Future<void> requestCameraPermission() async {}

  Future<void> emit(String command) async => _handler?.call(command);

  @override
  void dispose() {}
}
