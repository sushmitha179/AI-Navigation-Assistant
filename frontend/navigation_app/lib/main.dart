import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/language_selection_screen.dart';
import 'services/localization_service.dart';

void main() {
  runApp(const NavigationApp());
}

class NavigationApp extends StatefulWidget {
  const NavigationApp({
    super.key,
    this.localizationService,
    this.homeBuilder,
    this.languageSelectionBuilder,
  });

  @visibleForTesting
  final LocalizationService? localizationService;

  @visibleForTesting
  final WidgetBuilder? homeBuilder;

  @visibleForTesting
  final WidgetBuilder? languageSelectionBuilder;

  @override
  State<NavigationApp> createState() => _NavigationAppState();
}

class _NavigationAppState extends State<NavigationApp> {
  late final LocalizationService _localizationService =
      widget.localizationService ?? LocalizationService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeLocalization();
  }

  Future<void> _initializeLocalization() async {
    await _localizationService.init();
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Navigation Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _isInitialized
          ? _buildStartupScreen(context)
          : const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
      routes: {
        '/home': (context) =>
            widget.homeBuilder?.call(context) ?? const HomeScreen(),
        '/language': (context) => widget.languageSelectionBuilder
                ?.call(context) ??
            const LanguageSelectionScreen(),
      },
    );
  }

  Widget _buildStartupScreen(BuildContext context) {
    if (_localizationService.isLanguageSelected()) {
      return widget.homeBuilder?.call(context) ?? const HomeScreen();
    }
    return widget.languageSelectionBuilder?.call(context) ??
        const LanguageSelectionScreen();
  }
}
