import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navigation_app/services/localization_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LocalizationService', () {
    late LocalizationService localizationService;

    setUp(() {
      localizationService = LocalizationService();
    });

    test('getMessage returns English message when no language set', () async {
      await localizationService.init();
      expect(localizationService.currentLanguage, isNull);
      expect(
        localizationService.getMessage('welcome_message'),
        'AI Navigation Assistant is ready. Say start assistance to begin.',
      );
    });

    test('getMessage returns localized message for English', () async {
      await localizationService.setLanguage(AppLanguage.english);
      expect(
        localizationService.getMessage('welcome_message'),
        'AI Navigation Assistant is ready. Say start assistance to begin.',
      );
    });

    test('visual messages remain English after selecting Telugu', () async {
      await localizationService.setLanguage(AppLanguage.telugu);
      expect(
        localizationService.getMessage('assistant_status'),
        'ASSISTANT STATUS',
      );
      expect(localizationService.getMessage('start_assistance'), 'START ASSISTANCE');
    });

    test('visual messages remain English after selecting Hindi', () async {
      await localizationService.setLanguage(AppLanguage.hindi);
      expect(
        localizationService.getMessage('language_selection_title'),
        'Select Language',
      );
    });

    test('getMessage returns key when message not found', () async {
      await localizationService.setLanguage(AppLanguage.english);
      expect(
        localizationService.getMessage('nonexistent_key'),
        'nonexistent_key',
      );
    });

    test('getLanguageData returns correct data for English', () {
      final data = localizationService.getLanguageData(AppLanguage.english);
      expect(data.code, 'en');
      expect(data.name, 'English');
      expect(data.nativeName, 'English');
      expect(data.ttsLanguage, 'en-US');
      expect(data.speechRecognizerLanguage, 'en-US');
    });

    test('getLanguageData returns correct data for Telugu', () {
      final data = localizationService.getLanguageData(AppLanguage.telugu);
      expect(data.code, 'te');
      expect(data.name, 'Telugu');
      expect(data.nativeName, 'తెలుగు');
      expect(data.ttsLanguage, 'te-IN');
      expect(data.speechRecognizerLanguage, 'te-IN');
    });

    test('getLanguageData returns correct data for Hindi', () {
      final data = localizationService.getLanguageData(AppLanguage.hindi);
      expect(data.code, 'hi');
      expect(data.name, 'Hindi');
      expect(data.nativeName, 'हिंदी');
      expect(data.ttsLanguage, 'hi-IN');
      expect(data.speechRecognizerLanguage, 'hi-IN');
    });

    test('localizeNavigationAction returns localized action', () async {
      await localizationService.setLanguage(AppLanguage.english);
      expect(
        localizationService.localizeNavigationAction(
            'CONTINUE', 'No detected obstacles'),
        'Continue',
      );
      expect(
        localizationService.localizeNavigationAction('STOP', 'Obstacle ahead'),
        'Stop',
      );
      expect(
        localizationService.localizeNavigationAction(
            'CAUTION / SLOW DOWN', 'Slow down'),
        'Caution. Slow down.',
      );
      expect(
        localizationService.localizeNavigationAction(
            'MOVE LEFT', 'Left side obstacle'),
        'Move left',
      );
      expect(
        localizationService.localizeNavigationAction(
            'MOVE RIGHT', 'Right side obstacle'),
        'Move right',
      );
    });

    test('localizeNavigationAction returns Telugu action', () async {
      await localizationService.setLanguage(AppLanguage.telugu);
      expect(
        localizationService.localizeNavigationAction(
            'CONTINUE', 'No detected obstacles'),
        'కొనసాగించు',
      );
      expect(
        localizationService.localizeNavigationAction('STOP', 'Obstacle ahead'),
        'ఆగించు',
      );
    });

    test('localizeNavigationAction returns Hindi action', () async {
      await localizationService.setLanguage(AppLanguage.hindi);
      expect(
        localizationService.localizeNavigationAction(
            'CONTINUE', 'No detected obstacles'),
        'जारी रखें',
      );
      expect(
        localizationService.localizeNavigationAction('STOP', 'Obstacle ahead'),
        'रुकें',
      );
    });

    test('isLanguageSelected returns false when no language set', () async {
      await localizationService.init();
      expect(localizationService.isLanguageSelected(), false);
    });

    test('isLanguageSelected returns true when language set', () async {
      await localizationService.setLanguage(AppLanguage.english);
      expect(localizationService.isLanguageSelected(), true);
    });

    test('clearLanguage removes stored language', () async {
      await localizationService.setLanguage(AppLanguage.english);
      expect(localizationService.isLanguageSelected(), true);
      await localizationService.clearLanguage();
      expect(localizationService.isLanguageSelected(), false);
    });
  });
}
