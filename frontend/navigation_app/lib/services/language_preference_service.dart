import 'package:flutter/services.dart';

import '../l10n/assistant_language.dart';

class LanguagePreferenceService {
  LanguagePreferenceService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('voice_recognition');

  final MethodChannel _channel;

  Future<AssistantLanguage?> load() async {
    try {
      final code = await _channel.invokeMethod<String>('getSelectedLanguage');
      return AssistantLanguage.fromStorageCode(code);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> save(AssistantLanguage language) async {
    try {
      return await _channel.invokeMethod<bool>(
            'setSelectedLanguage',
            {'code': language.storageCode},
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
