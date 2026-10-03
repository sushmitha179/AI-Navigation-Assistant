import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navigation_app/models/detection_model.dart';
import 'package:navigation_app/models/navigation_model.dart';
import 'package:navigation_app/models/sign_reading.dart';
import 'package:navigation_app/screens/home_screen.dart';
import 'package:navigation_app/services/backend_service.dart';
import 'package:navigation_app/services/camera_service.dart';
import 'package:navigation_app/services/speech_recognition_service.dart';
import 'package:navigation_app/services/voice_service.dart';

const _voiceChannel = MethodChannel('voice_recognition');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

    testWidgets('saved locale keeps English UI and localizes voice commands',
        (WidgetTester tester) async {
      for (final language in [
        (
          code: 'te',
          status: 'ASSISTANT STATUS',
          command: 'సహాయం ప్రారంభించండి',
          running: 'Assistant Running',
          question: 'నా ముందు ఏముంది',
          object: 'వ్యక్తి',
          tag: 'te-IN',
        ),
        (
          code: 'hi',
          status: 'ASSISTANT STATUS',
          command: 'सहायता शुरू करें',
          running: 'Assistant Running',
          question: 'मेरे सामने क्या है',
          object: 'व्यक्ति',
          tag: 'hi-IN',
        ),
      ]) {
        SharedPreferences.setMockInitialValues({
          'selected_language': language.code,
        });
        final harness = _HomeScreenHarness()..voice.initializeResult = true;
        await tester.pumpWidget(harness.build());
        await tester.pumpAndSettle();

        expect(find.text(language.status), findsOneWidget);
        expect(find.text('START ASSISTANCE'), findsOneWidget);
        expect(find.text('STOP ASSISTANCE'), findsOneWidget);
        expect(find.text('ಸಹಾಯಕుడి స్థితి'), findsNothing);
        expect(harness.voice.requestedLanguageTag, language.tag);
        expect(harness.speech.startedLanguageTags, [language.tag]);
        expect(
          harness.voice.spoken.first,
          contains(language.code == 'te' ? 'సిద్ధంగా' : 'तैयार'),
        );

        await harness.speech.emit(language.command);
        await tester.pumpAndSettle();
        expect(find.text(language.running), findsOneWidget);

        await harness.camera.emitFrame();
        await tester.pumpAndSettle();
        expect(
          harness.voice.spoken.last,
          contains(language.code == 'te' ? 'ఆగండి' : 'रुकें'),
        );
        await harness.speech.emit(language.question);
        await tester.pumpAndSettle();
        expect(harness.voice.spoken.last, contains(language.object));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
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
          contains('Stop. person is very close ahead.'));
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
      expect(harness.voice.spoken.last, 'EXIT 24 HOURS');
      expect(harness.voice.spoken, contains('The sign says.'));
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
      expect(harness.hapticLevels, [true]);
    });

    testWidgets(
        'diagnostic control triggers the native high waveform without detection',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness();
      await tester.pumpWidget(harness.build(enableHapticDiagnostic: true));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('haptic-diagnostic')));
      await tester.pump();

      expect(harness.hapticLevels, [true]);
      expect(harness.backend.uploadCount, 0);
    });

    testWidgets('haptic failure does not prevent the spoken STOP warning',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()
        ..hapticFeedbackOverride = (_) async => throw StateError('unsupported');
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();
      await harness.camera.emitFrame();
      await tester.pump();

      expect(harness.voice.spoken.last,
          contains('Stop. person is very close ahead.'));
    });

    testWidgets('caution alert uses the distinct medium haptic',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()
        ..backend.navigation = const NavigationModel(
          action: 'CAUTION / SLOW DOWN',
          reason: 'Obstacle close ahead',
          priority: 'MEDIUM',
          relevantObject: 'box',
          detections: [
            DetectionModel(
              className: 'box',
              confidence: 0.9,
              collisionRisk: 'MEDIUM',
              horizontalPosition: 'CENTER',
              proximityCategory: 'CLOSE',
            ),
          ],
        );
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();
      await harness.camera.emitFrame();
      await tester.pump();

      expect(harness.hapticLevels, [false]);
      expect(harness.voice.spoken.last, contains('Caution'));
    });

    testWidgets('HIGH alert preempts a recent MEDIUM haptic',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()
        ..backend.navigation = const NavigationModel(
          action: 'CAUTION / SLOW DOWN',
          reason: 'Obstacle close ahead',
          priority: 'MEDIUM',
          relevantObject: 'box',
          detections: [
            DetectionModel(
              className: 'box',
              confidence: 0.9,
              collisionRisk: 'MEDIUM',
              horizontalPosition: 'CENTER',
              proximityCategory: 'CLOSE',
            ),
          ],
        );
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();
      await harness.camera.emitFrame();
      await tester.pump();

      harness.backend.navigation = const NavigationModel(
        action: 'STOP',
        reason: 'Person very close ahead',
        priority: 'HIGH',
        relevantObject: 'person',
        detections: [
          DetectionModel(
            className: 'person',
            confidence: 0.99,
            collisionRisk: 'HIGH',
            horizontalPosition: 'CENTER',
            proximityCategory: 'VERY CLOSE',
          ),
        ],
      );
      await harness.camera.emitFrame();
      await tester.pump();

      expect(harness.hapticLevels, [false, true]);
      expect(harness.voice.spoken.last,
          contains('Stop. person is very close ahead.'));
    });

    testWidgets('backend HIGH STOP result requests native HIGH waveform',
        (WidgetTester tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final hapticPriorities = <String>[];
      messenger.setMockMethodCallHandler(_voiceChannel, (call) async {
        switch (call.method) {
          case 'initialize':
          case 'startListening':
          case 'stopListening':
          case 'setTtsSpeaking':
          case 'requestCameraPermission':
          case 'stopHaptics':
            return true;
          case 'triggerHaptic':
            hapticPriorities.add(
              (call.arguments as Map)['priority'] as String,
            );
            return true;
          default:
            return null;
        }
      });
      addTearDown(
          () => messenger.setMockMethodCallHandler(_voiceChannel, null));

      final backend = _FakeBackendService();
      final camera = _FakeCameraService();
      final voice = _FakeVoiceService();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          skipSpeechPause: true,
          backendService: backend,
          cameraService: camera,
          voiceService: voice,
          speechRecognitionService: SpeechRecognitionService(),
        ),
      ));
      await tester.pump();
      await _sendNativeVoiceResult('start assistance');
      await tester.pump();
      await camera.emitFrame();
      await tester.pump();

      expect(hapticPriorities, ['high']);
      expect(find.byKey(const ValueKey('haptic-diagnostic')), findsNothing);
      expect(voice.spoken.last,
          contains('Stop. person is very close ahead.'));
    });

    testWidgets('backend MEDIUM CAUTION result requests native MEDIUM waveform',
        (WidgetTester tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final hapticPriorities = <String>[];
      messenger.setMockMethodCallHandler(_voiceChannel, (call) async {
        switch (call.method) {
          case 'initialize':
          case 'startListening':
          case 'stopListening':
          case 'setTtsSpeaking':
          case 'requestCameraPermission':
          case 'stopHaptics':
            return true;
          case 'triggerHaptic':
            hapticPriorities.add(
              (call.arguments as Map)['priority'] as String,
            );
            return true;
          default:
            return null;
        }
      });
      addTearDown(
          () => messenger.setMockMethodCallHandler(_voiceChannel, null));

      final backend = _FakeBackendService()
        ..navigation = const NavigationModel(
          action: 'CAUTION / SLOW DOWN',
          reason: 'Obstacle close ahead',
          priority: 'MEDIUM',
          relevantObject: 'box',
          detections: [
            DetectionModel(
              className: 'box',
              confidence: 0.9,
              collisionRisk: 'MEDIUM',
              horizontalPosition: 'CENTER',
              proximityCategory: 'CLOSE',
            ),
          ],
        );
      final camera = _FakeCameraService();
      final voice = _FakeVoiceService();
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          skipSpeechPause: true,
          backendService: backend,
          cameraService: camera,
          voiceService: voice,
          speechRecognitionService: SpeechRecognitionService(),
        ),
      ));
      await tester.pump();
      await _sendNativeVoiceResult('start assistance');
      await tester.pump();
      await camera.emitFrame();
      await tester.pump();

      expect(hapticPriorities, ['medium']);
      expect(voice.spoken.last, contains('Caution'));
    });

    testWidgets('scene narration prioritizes high-risk objects',
        (WidgetTester tester) async {
      final harness = _HomeScreenHarness()
        ..backend.navigation = const NavigationModel(
          action: 'CONTINUE',
          reason: 'Objects detected',
          priority: 'LOW',
          relevantObject: null,
          detections: [
            DetectionModel(
              className: 'chair',
              confidence: 0.85,
              collisionRisk: 'LOW',
              horizontalPosition: 'LEFT',
              proximityCategory: 'FAR',
            ),
            DetectionModel(
              className: 'person',
              confidence: 0.96,
              collisionRisk: 'HIGH',
              horizontalPosition: 'CENTER',
              proximityCategory: 'CLOSE',
            ),
            DetectionModel(
              className: 'bicycle',
              confidence: 0.8,
              collisionRisk: 'MEDIUM',
              horizontalPosition: 'RIGHT',
              proximityCategory: null,
            ),
          ],
        );
      await tester.pumpWidget(harness.build());
      await tester.pump();
      await harness.speech.emit('start');
      await tester.pump();
      await harness.camera.emitFrame();
      await tester.pump();

      final speech = harness.voice.spoken.last;
      expect(speech, contains('Nearby scene with high reported risk'));
      expect(speech.indexOf('person'), lessThan(speech.indexOf('bicycle')));
      expect(speech, isNot(contains('chair')));
      expect(speech, contains('depth is relative, not distance in meters'));
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
  final List<bool> hapticLevels = [];
  Future<void> Function(bool highRisk)? hapticFeedbackOverride;

  Widget build({bool enableHapticDiagnostic = false}) => MaterialApp(
        home: HomeScreen(
          skipSpeechPause: true,
          backendService: backend,
          cameraService: camera,
          voiceService: voice,
          speechRecognitionService: speech,
          enableHapticDiagnostic: enableHapticDiagnostic,
          hapticFeedback: hapticFeedbackOverride ??
              (highRisk) async => hapticLevels.add(highRisk),
        ),
      );
}

Future<void> _sendNativeVoiceResult(String text) async {
  final data = const StandardMethodCodec().encodeMethodCall(
    MethodCall('onRecognitionResult', text),
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(_voiceChannel.name, data, (_) {});
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
  bool initializeResult = false;
  String? requestedLanguageTag;
  String _activeLanguageTag = 'en-US';

  @override
  String get activeLanguageTag => _activeLanguageTag;

  @override
  Future<bool> initialize() async => initializeResult;

  @override
  Future<bool> setLanguage(String languageTag) async {
    requestedLanguageTag = languageTag;
    _activeLanguageTag = languageTag;
    return true;
  }

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
  final List<String> startedLanguageTags = [];

  @override
  Future<bool> initialize({
    ValueChanged<String>? onStatusChanged,
    VoiceRecognitionErrorHandler? onError,
  }) async {
    onStatusChanged?.call('Listening for voice commands');
    return true;
  }

  @override
  Future<bool> startListening(
    VoiceCommandHandler onResult, {
    String languageTag = 'en-US',
  }) async {
    _handler = onResult;
    startedLanguageTags.add(languageTag);
    return true;
  }

  @override
  Future<void> setTtsSpeaking(bool speaking) async {
    ttsStates.add(speaking);
  }

  @override
  Future<bool> stopRiskHaptics({bool force = false}) async => true;

  @override
  Future<void> requestCameraPermission() async {}

  Future<void> emit(String command) async => _handler?.call(command);

  @override
  void dispose() {}
}
