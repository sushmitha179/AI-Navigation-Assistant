import 'package:flutter_test/flutter_test.dart';
import 'package:navigation_app/l10n/assistant_language.dart';

void main() {
  group('Assistant spoken language localization', () {
    test('matches English and native script language names', () {
      const localizations = AssistantLocalizations(AssistantLanguage.english);

      expect(localizations.matchLanguageChoice('English'),
          AssistantLanguage.english);
      expect(localizations.matchLanguageChoice('తెలుగు'),
          AssistantLanguage.telugu);
      expect(localizations.matchLanguageChoice('तेलुगु'),
          AssistantLanguage.telugu);
      expect(
          localizations.matchLanguageChoice('हिंदी'), AssistantLanguage.hindi);
      expect(localizations.matchLanguageChoice('maybe'), isNull);
    });

    test('provides translated Telugu navigation instructions', () {
      const localizations = AssistantLocalizations(AssistantLanguage.telugu);

      expect(
        localizations.navigationInstruction(
          'STOP',
          localizations.objectName('person'),
        ),
        contains('ఆగండి'),
      );
      expect(
        localizations.navigationInstruction('MOVE RIGHT', 'వస్తువు'),
        contains('కుడివైపు'),
      );
    });

    test('provides translated Hindi navigation instructions', () {
      const localizations = AssistantLocalizations(AssistantLanguage.hindi);

      expect(
        localizations.navigationInstruction(
          'STOP',
          localizations.objectName('person'),
        ),
        contains('रुकें'),
      );
      expect(
        localizations.navigationInstruction('MOVE LEFT', 'वस्तु'),
        contains('बाईं ओर'),
      );
    });

    test('uses translated generic object names for unknown classes', () {
      expect(
        const AssistantLocalizations(AssistantLanguage.telugu)
            .objectName('unmapped-class'),
        'వస్తువు',
      );
      expect(
        const AssistantLocalizations(AssistantLanguage.hindi)
            .objectName('unmapped-class'),
        'वस्तु',
      );
    });

    test('localized help includes the spoken language-change command', () {
      expect(
        const AssistantLocalizations(AssistantLanguage.english).text('help'),
        contains('change language'),
      );
      expect(
        const AssistantLocalizations(AssistantLanguage.telugu).text('help'),
        contains('భాష మార్చండి'),
      );
      expect(
        const AssistantLocalizations(AssistantLanguage.hindi).text('help'),
        contains('भाषा बदलें'),
      );
    });
  });
}
