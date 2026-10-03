import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navigation_app/screens/language_selection_screen.dart';
import 'package:navigation_app/services/localization_service.dart';
import 'package:navigation_app/services/speech_recognition_service.dart';
import 'package:navigation_app/services/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpSelection(
    WidgetTester tester, {
    required _FakeVoiceService voice,
    required _FakeSpeechRecognitionService speech,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LanguageSelectionScreen(
          voiceService: voice,
          speechRecognitionService: speech,
          localizationService: LocalizationService(),
        ),
        routes: {'/home': (_) => const Text('Home route')},
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('automatically speaks English prompt and starts listening',
      (tester) async {
    final voice = _FakeVoiceService();
    final speech = _FakeSpeechRecognitionService();
    await pumpSelection(tester, voice: voice, speech: speech);

    expect(voice.spoken.first, contains('Welcome to AI Navigation Assistant'));
    expect(speech.listening, isTrue);
    expect(find.text('Choose Spoken Language'), findsOneWidget);
    expect(find.text('ENGLISH'), findsOneWidget);
    expect(find.text('TELUGU'), findsOneWidget);
    expect(find.text('HINDI'), findsOneWidget);
    expect(find.textContaining('తెలుగు'), findsNothing);
  });

  testWidgets('recognizes a native-language choice and confirms in English',
      (tester) async {
    final voice = _FakeVoiceService();
    final speech = _FakeSpeechRecognitionService();
    await pumpSelection(tester, voice: voice, speech: speech);

    await speech.recognize('హిందీ');
    await tester.pumpAndSettle();

    expect(voice.spoken, contains('Hindi selected.'));
    expect(
      voice.events.indexOf('speak:Hindi selected.'),
      lessThan(voice.events.indexOf('language:hi-IN')),
    );
    expect(find.text('Home route'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('selected_language'), 'hi');
  });

  testWidgets('unknown recognition remains in English language selection',
      (tester) async {
    final voice = _FakeVoiceService();
    final speech = _FakeSpeechRecognitionService();
    await pumpSelection(tester, voice: voice, speech: speech);

    await speech.recognize('unclear words');
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(voice.spoken.last, contains('Please say English, Telugu, or Hindi'));
    expect(find.text('ENGLISH'), findsOneWidget);
  });

  testWidgets('microphone denial announces accessible button fallback',
      (tester) async {
    final voice = _FakeVoiceService();
    final speech = _FakeSpeechRecognitionService()
      ..initialized = false
      ..initializationError = ('permission_denied', 'Denied');
    await pumpSelection(tester, voice: voice, speech: speech);

    expect(find.textContaining('Microphone access was denied'), findsOneWidget);
    expect(voice.spoken.last, contains('Microphone access was denied'));
    expect(find.text('TELUGU'), findsOneWidget);
  });

  testWidgets('recognition initialization failure keeps manual fallback',
      (tester) async {
    final voice = _FakeVoiceService();
    final speech = _FakeSpeechRecognitionService()..initialized = false;
    await pumpSelection(tester, voice: voice, speech: speech);

    expect(find.textContaining('Voice recognition is unavailable'),
        findsOneWidget);
    expect(find.text('HINDI'), findsOneWidget);
  });

  testWidgets('missing selected TTS voice explains English fallback',
      (tester) async {
    final voice = _FakeVoiceService()..unavailableLocales.add('te-IN');
    final speech = _FakeSpeechRecognitionService();
    await pumpSelection(tester, voice: voice, speech: speech);

    await tester.tap(find.text('TELUGU'));
    await tester.pumpAndSettle();

    expect(
      voice.spoken,
      anyElement(contains('selected language voice is not installed')),
    );
    expect(find.text('Home route'), findsOneWidget);
    expect(voice.activeLanguageTag, 'en-US');
  });
}

class _FakeVoiceService extends VoiceService {
  final List<String> spoken = [];
  final List<String> events = [];
  final Set<String> unavailableLocales = {};
  String _activeLanguageTag = 'en-US';

  @override
  String get activeLanguageTag => _activeLanguageTag;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> setLanguage(String languageTag) async {
    events.add('language:$languageTag');
    if (unavailableLocales.contains(languageTag)) return false;
    _activeLanguageTag = languageTag;
    return true;
  }

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    events.add('speak:$text');
    return true;
  }

  @override
  void dispose() {}
}

class _FakeSpeechRecognitionService extends SpeechRecognitionService {
  bool initialized = true;
  (String, String)? initializationError;
  bool listening = false;
  VoiceCommandHandler? _onResult;

  @override
  Future<bool> initialize({
    ValueChanged<String>? onStatusChanged,
    VoiceRecognitionErrorHandler? onError,
  }) async {
    final error = initializationError;
    if (error != null) await onError?.call(error.$1, error.$2);
    return initialized;
  }

  @override
  Future<bool> startListening(
    VoiceCommandHandler onResult, {
    String languageTag = 'en-US',
  }) async {
    _onResult = onResult;
    listening = initialized;
    return listening;
  }

  Future<void> recognize(String phrase) async {
    await _onResult?.call(phrase);
  }

  @override
  Future<void> stopListening() async {
    listening = false;
  }

  @override
  Future<void> setTtsSpeaking(bool speaking) async {}

  @override
  Future<void> setLanguage(String languageTag) async {}

  @override
  void dispose() {}
}
