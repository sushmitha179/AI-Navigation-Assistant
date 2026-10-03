import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:navigation_app/main.dart';
import 'package:navigation_app/screens/home_screen.dart';
import 'package:navigation_app/screens/language_selection_screen.dart';
import 'package:navigation_app/services/localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NavigationApp startup routing', () {
    testWidgets('first launch opens language selection', (tester) async {
      final localization = LocalizationService();
      await tester.pumpWidget(
        NavigationApp(
          localizationService: localization,
          languageSelectionBuilder: (_) =>
              const Text('language selection route'),
          homeBuilder: (_) => const Text('home route'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('language selection route'), findsOneWidget);
      expect(find.text('home route'), findsNothing);
      expect(localization.currentLanguage, isNull);
    });

    testWidgets('saved English, Telugu and Hindi preferences open home',
        (tester) async {
      for (final language in [
        (code: 'en', value: AppLanguage.english),
        (code: 'te', value: AppLanguage.telugu),
        (code: 'hi', value: AppLanguage.hindi),
      ]) {
        SharedPreferences.setMockInitialValues({
          'selected_language': language.code,
        });
        final localization = LocalizationService();
        await tester.pumpWidget(
          NavigationApp(
            localizationService: localization,
            languageSelectionBuilder: (_) =>
                const Text('language selection route'),
            homeBuilder: (_) => Text(
              'home route: ${localization.currentLanguage}',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('home route: ${language.value}'),
          findsOneWidget,
        );
        expect(find.text('language selection route'), findsNothing);
        expect(localization.currentLanguage, language.value);
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getString('selected_language'), language.code);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    });

    testWidgets('default startup builders preserve the language screens',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const NavigationApp());
      await tester.pumpAndSettle();
      expect(find.byType(LanguageSelectionScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}
