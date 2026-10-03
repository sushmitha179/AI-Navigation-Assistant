import 'package:flutter/material.dart';

import '../l10n/assistant_language.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({
    super.key,
    this.initialLanguage,
    required this.onContinue,
  });

  final AssistantLanguage? initialLanguage;
  final Future<void> Function(AssistantLanguage language) onContinue;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  AssistantLanguage? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AssistantLocalizations(
      _selected ?? AssistantLanguage.english,
    );
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('chooseLanguage'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.text('languageHelp'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              for (final language in AssistantLanguage.values)
                RadioListTile<AssistantLanguage>(
                  value: language,
                  groupValue: _selected,
                  title: Text(language.nativeName),
                  subtitle: Text(_languageSubtitle(strings, language)),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _selected = value),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              const Spacer(),
              SizedBox(
                height: 60,
                child: FilledButton(
                  key: const ValueKey('language-continue'),
                  onPressed: _selected == null || _saving ? null : _continue,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : Text(strings.text('continue')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _languageSubtitle(
    AssistantLocalizations strings,
    AssistantLanguage language,
  ) {
    switch (language) {
      case AssistantLanguage.english:
        return strings.text('englishName');
      case AssistantLanguage.telugu:
        return strings.text('teluguName');
      case AssistantLanguage.hindi:
        return strings.text('hindiName');
    }
  }

  Future<void> _continue() async {
    final language = _selected;
    if (language == null) return;
    setState(() => _saving = true);
    try {
      await widget.onContinue(language);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class LanguageSelectionDialog extends StatefulWidget {
  const LanguageSelectionDialog({
    super.key,
    required this.initialLanguage,
  });

  final AssistantLanguage initialLanguage;

  @override
  State<LanguageSelectionDialog> createState() =>
      _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  late AssistantLanguage _selected = widget.initialLanguage;

  @override
  Widget build(BuildContext context) {
    final strings = AssistantLocalizations(_selected);
    return AlertDialog(
      title: Text(strings.text('chooseLanguage')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final language in AssistantLanguage.values)
            RadioListTile<AssistantLanguage>(
              value: language,
              groupValue: _selected,
              title: Text(language.nativeName),
              onChanged: (value) {
                if (value != null) setState(() => _selected = value);
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
              AssistantLocalizations(widget.initialLanguage).text('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(strings.text('continue')),
        ),
      ],
    );
  }
}
