import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:navigation_app/services/voice_service.dart';

const _ttsChannel = MethodChannel('flutter_tts');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  List<Map<String, String>> voices = [];

  setUp(() {
    calls.clear();
    voices = [
      {'name': 'English US', 'locale': 'en-US'},
      {'name': 'Telugu India', 'locale': 'te-IN'},
      {'name': 'Hindi India', 'locale': 'hi-IN'},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'getVoices':
          return voices;
        case 'isLanguageAvailable':
        case 'isLanguageInstalled':
          return true;
        case 'setVoice':
        case 'setLanguage':
        case 'setSpeechRate':
        case 'setVolume':
        case 'setPitch':
        case 'awaitSpeakCompletion':
        case 'speak':
        case 'stop':
          return 1;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_ttsChannel, null);
  });

  test('selects an exact installed Telugu voice and can restore English',
      () async {
    final service = VoiceService(textToSpeech: FlutterTts(), isAndroid: true);

    expect(await service.initialize(), isTrue);
    expect(await service.setLanguage('te-IN'), isTrue);
    expect(service.activeLanguageTag, 'te-IN');
    expect(
      calls.any(
        (call) =>
            call.method == 'setVoice' &&
            (call.arguments as Map)['locale'] == 'te-IN',
      ),
      isTrue,
    );
    expect(await service.setLanguage('en-US'), isTrue);
    expect(service.activeLanguageTag, 'en-US');
  });

  test('uses installed English voice when the selected locale is absent',
      () async {
    voices = [
      {'name': 'English US', 'locale': 'en-US'},
    ];
    final service = VoiceService(textToSpeech: FlutterTts(), isAndroid: true);

    expect(await service.initialize(), isTrue);
    expect(await service.setLanguage('te-IN'), isFalse);
    expect(service.activeLanguageTag, 'en-US');
    expect(
      calls.any(
        (call) =>
            call.method == 'setVoice' &&
            (call.arguments as Map)['locale'] == 'en-US',
      ),
      isTrue,
    );
  });

  test('refuses initialization when no installed English voice is listed',
      () async {
    voices = [];
    final service = VoiceService(textToSpeech: FlutterTts(), isAndroid: true);

    expect(await service.initialize(), isFalse);
    expect(service.isReady(), isFalse);
  });
}
