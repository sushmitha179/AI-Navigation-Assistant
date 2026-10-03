import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/services/speech_recognition_service.dart';

const _channel = MethodChannel('voice_recognition');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var startCount = 0;
  var initializeResult = true;
  final hapticCalls = <MethodCall>[];

  setUp(() {
    startCount = 0;
    initializeResult = true;
    hapticCalls.clear();
    messenger.setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'initialize':
          return initializeResult;
        case 'startListening':
          startCount++;
          return true;
        case 'stopListening':
          return true;
        case 'setTtsSpeaking':
          return true;
        case 'triggerHaptic':
          hapticCalls.add(call);
          return true;
        case 'stopHaptics':
          hapticCalls.add(call);
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
  });

  test('recognition errors recreate listening without overlapping starts',
      () async {
    final service = SpeechRecognitionService();
    await service.initialize();
    await service.startListening((_) {});
    await service.startListening((_) {});

    expect(startCount, 1);

    await _sendNativeCall('onRecognitionError', {
      'code': '6',
      'message': 'Speech recognition timed out; restarting',
    });
    await Future<void>.delayed(const Duration(milliseconds: 550));

    expect(startCount, 2);
    expect(service.isListening(), isTrue);
    service.dispose();
  });

  test('recognition results dispatch commands and start the next session',
      () async {
    final commands = <String>[];
    final service = SpeechRecognitionService();
    await service.initialize();
    await service.startListening(commands.add);

    await _sendNativeCall('onRecognitionResult', 'Stop assistance');

    expect(commands, ['stop assistance']);
    expect(startCount, 2);
    expect(service.isListening(), isTrue);
    service.dispose();
  });

  test('TTS pauses recognition and resumes it after speech completion',
      () async {
    final service = SpeechRecognitionService();
    await service.initialize();
    await service.startListening((_) {});

    await service.setTtsSpeaking(true);
    expect(startCount, 1);
    expect(service.isListening(), isFalse);

    await service.setTtsSpeaking(false);
    expect(startCount, 2);
    expect(service.isListening(), isTrue);
    service.dispose();
  });

  test('permission grant resumes a previously requested listener', () async {
    initializeResult = false;
    final service = SpeechRecognitionService();
    expect(await service.initialize(), isFalse);
    await service.startListening((_) {});

    await _sendNativeCall('onPermissionResult', true);

    expect(service.isReady(), isTrue);
    expect(service.isListening(), isTrue);
    expect(startCount, 1);
    service.dispose();
  });

  test('permission denial reports unavailable and does not restart', () async {
    final service = SpeechRecognitionService();
    await service.initialize();
    await service.startListening((_) {});

    await _sendNativeCall('onRecognitionError', {
      'code': 'permission_denied',
      'message': 'Microphone permission denied',
    });

    expect(service.isReady(), isFalse);
    expect(startCount, 1);
    service.dispose();
  });

  test('risk haptics send distinct priorities and allow forced cancellation',
      () async {
    final service = SpeechRecognitionService();

    expect(
      await service.triggerRiskHaptic(
        highRisk: true,
        signature: 'person|CENTER|HIGH',
      ),
      isTrue,
    );
    expect(
      await service.triggerRiskHaptic(
        highRisk: false,
        signature: 'box|CENTER|MEDIUM',
      ),
      isTrue,
    );
    expect(await service.stopRiskHaptics(force: true), isTrue);

    expect(hapticCalls[0].method, 'triggerHaptic');
    expect((hapticCalls[0].arguments as Map)['priority'], 'high');
    expect(hapticCalls[1].method, 'triggerHaptic');
    expect((hapticCalls[1].arguments as Map)['priority'], 'medium');
    expect(hapticCalls[2].method, 'stopHaptics');
    expect((hapticCalls[2].arguments as Map)['force'], isTrue);
    service.dispose();
  });
}

Future<void> _sendNativeCall(String method, Object? arguments) async {
  final data = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(_channel.name, data, (_) {});
}
