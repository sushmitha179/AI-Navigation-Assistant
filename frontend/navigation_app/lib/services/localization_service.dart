import 'package:shared_preferences/shared_preferences.dart'
    as shared_preferences;

enum AppLanguage {
  english,
  telugu,
  hindi,
}

class AppLanguageData {
  final String code;
  final String name;
  final String nativeName;
  final String ttsLanguage;
  final String speechRecognizerLanguage;

  const AppLanguageData({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.ttsLanguage,
    required this.speechRecognizerLanguage,
  });
}

class LocalizationService {
  static const String _storageKey = 'selected_language';

  static final Map<AppLanguage, AppLanguageData> _languageData = {
    AppLanguage.english: const AppLanguageData(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      ttsLanguage: 'en-US',
      speechRecognizerLanguage: 'en-US',
    ),
    AppLanguage.telugu: const AppLanguageData(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      ttsLanguage: 'te-IN',
      speechRecognizerLanguage: 'te-IN',
    ),
    AppLanguage.hindi: const AppLanguageData(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिंदी',
      ttsLanguage: 'hi-IN',
      speechRecognizerLanguage: 'hi-IN',
    ),
  };

  static final Map<AppLanguage, Map<String, String>> _messages = {
    AppLanguage.english: {
      'app_title': 'AI Navigation Assistant',
      'assistant_status': 'ASSISTANT STATUS',
      'assistant_ready': 'Assistant Ready',
      'assistant_running': 'Assistant Running',
      'assistant_stopped': 'Assistant Stopped',
      'waiting_to_start': 'Waiting to start...',
      'start_assistance': 'START ASSISTANCE',
      'stop_assistance': 'STOP ASSISTANCE',
      'navigation_message': 'NAVIGATION MESSAGE',
      'welcome_message':
          'AI Navigation Assistant is ready. Say start assistance to begin.',
      'assistance_started': 'Assistance started.',
      'assistance_stopped': 'Assistance stopped.',
      'connecting_backend': 'Connecting to navigation backend...',
      'backend_unavailable':
          'Backend unavailable. Check the phone and computer are on the same Wi-Fi network.',
      'connection_error': 'Connection error. Check backend is running.',
      'camera_unavailable': 'Camera unavailable. Check permissions.',
      'camera_error': 'Camera error',
      'navigation_backend_error': 'Navigation backend error',
      'speech_recognition_unavailable':
          'Speech recognition unavailable. Use touch controls.',
      'help_message':
          'Available commands: start assistance, stop assistance, help.',
      'language_selection_title': 'Select Language',
      'language_selection_subtitle': 'Choose your preferred language',
      'continue': 'Continue',
      'for_visually_impaired': 'For Visually Impaired People',
      'continue_action': 'Continue',
      'stop_action': 'Stop',
      'caution_action': 'Caution. Slow down.',
      'move_left_action': 'Move left',
      'move_right_action': 'Move right',
      'no_detected_obstacles': 'No detected obstacles',
      'change_language': 'Change Language',
      'start_before_read': 'Start assistance before reading a sign.',
      'could_not_capture':
          'I could not capture the sign. Hold the phone steady and say read sign to retry.',
      'could_not_read':
          'I could not read that sign clearly. Hold the phone steady and say read sign to retry.',
      'sign_says': 'The sign says',
      'no_recent_view':
          'I do not have a recent camera view. Start assistance and ask again.',
      'no_object_detected': 'No object was detected in the',
      'potential_obstacle': 'Potential obstacle on the',
      'objects_detected': 'Objects detected on the',
      'camera_view': 'Camera view',
      'not_confirm_route': 'This does not confirm the walking route is clear.',
      'camera_relative': 'This is camera-relative, not mapped route guidance.',
    },
    AppLanguage.telugu: {
      'app_title': 'AI నావిగేషన్ అసిస్టెంట్',
      'assistant_status': 'సహాయకుడి స్థితి',
      'assistant_ready': 'అసిస్టెంట్ సిద్ధంగా ఉంది',
      'assistant_running': 'సహాయం నడుస్తోంది',
      'assistant_stopped': 'సహాయం ఆగింది',
      'waiting_to_start': 'ప్రారంభించడానికి వేచి ఉంది...',
      'start_assistance': 'సహాయం ప్రారంభించు',
      'stop_assistance': 'సహాయం ఆగించు',
      'navigation_message': 'నావిగేషన్ సందేశం',
      'welcome_message':
          'AI నావిగేషన్ అసిస్టెంట్ సిద్ధంగా ఉంది. సహాయం ప్రారంభించడానికి చెప్పండి.',
      'assistance_started': 'సహాయం ప్రారంభించబడింది.',
      'assistance_stopped': 'సహాయం ఆగింది.',
      'connecting_backend': 'నావిగేషన్ బ్యాక్‌ఎండ్‌కు అనుసంధానిస్తోంది.',
      'backend_unavailable':
          'బ్యాక్‌ఎండ్ అందుబాటులో లేదు. ఫోన్ మరియు కంప్యూటర్ ఒకే Wi-Fi నెట్‌వర్క్‌లో ఉన్నాయో తనిఖీ చేయండి.',
      'connection_error':
          'అనుసంధానంలో లోపం. బ్యాక్‌ఎండ్ నడుస్తుందో తనిఖీ చేయండి.',
      'camera_unavailable': 'కెమెరా అందుబాటులో లేదు. అనుమతులను తనిఖీ చేయండి.',
      'camera_error': 'కెమెరా లోపం',
      'navigation_backend_error': 'నావిగేషన్ బ్యాకెండ్ లోపం',
      'speech_recognition_unavailable':
          'స్పీచ్ గుర్తింపు అందుబాటులో లేదు. టచ్ నియంత్రణలను ఉపయోగించండి.',
      'help_message':
          'సహాయం ప్రారంభించండి, సహాయం ఆపండి, బోర్డు చదవండి, ముందు లేదా ఎడమ లేదా కుడి వైపు ఏముందో అడగండి, సూచన మళ్లీ చెప్పండి లేదా సహాయం అని చెప్పండి.',
      'language_selection_title': 'భాషను ఎంచుకోండి',
      'language_selection_subtitle': 'మీ ఇష్టపడే భాషను ఎంచుకోండి',
      'continue': 'కొనసాగించు',
      'for_visually_impaired': 'దృష్టి లోపం ఉన్నవారి కోసం',
      'continue_action': 'కొనసాగించు',
      'stop_action': 'ఆగించు',
      'caution_action': 'జాగ్రత్త. నెమ్మదిగా కదలండి.',
      'move_left_action': 'ఎడమకు వెళ్లు',
      'move_right_action': 'కుడివైపు కదలండి',
      'no_detected_obstacles': 'అడ్డంకులు గుర్తించబడలేదు',
      'change_language': 'భాష మార్చు',
      'start_before_read': 'బోర్డు చదవడానికి ముందు సహాయం ప్రారంభించండి.',
      'could_not_capture':
          'బోర్డును చిత్రీకరించలేకపోయాను. ఫోన్‌ను స్థిరంగా ఉంచి బోర్డు చదవమని మళ్లీ చెప్పండి.',
      'could_not_read':
          'బోర్డును స్పష్టంగా చదవలేకపోయాను. ఫోన్‌ను స్థిరంగా ఉంచి మళ్లీ ప్రయత్నించండి.',
      'sign_says': 'బోర్డుపై ఇలా ఉంది',
      'no_recent_view':
          'తాజా కెమెరా దృశ్యం లేదు. సహాయం ప్రారంభించి మళ్లీ అడగండి.',
      'no_object_detected': 'ఏ వస్తువూ గుర్తించబడలేదు',
      'potential_obstacle': 'సంభావ్య అడ్డంకి',
      'objects_detected': 'గుర్తించిన వస్తువులు',
      'camera_view': 'కెమెరా వీక్షణ',
      'not_confirm_route': 'దీనివల్ల నడిచే మార్గం ఖాళీగా ఉందని నిర్ధారించబడదు.',
      'camera_relative':
          'ఇది కెమెరా దృశ్యానికి సంబంధించినది, మ్యాప్ చేసిన మార్గదర్శకం కాదు.',
    },
    AppLanguage.hindi: {
      'app_title': 'AI नेविगेशन सहायक',
      'assistant_status': 'सहायक की स्थिति',
      'assistant_ready': 'सहायक तैयार है',
      'assistant_running': 'सहायक चल रहा है',
      'assistant_stopped': 'सहायक रुका हुआ है',
      'waiting_to_start': 'शुरू करने की प्रतीक्षा...',
      'start_assistance': 'सहायता शुरू करें',
      'stop_assistance': 'सहायता रोकें',
      'navigation_message': 'नेविगेशन संदेश',
      'welcome_message':
          'AI नेविगेशन सहायक तैयार है। सहायता शुरू करने के लिए कहें।',
      'assistance_started': 'सहायता शुरू की गई।',
      'assistance_stopped': 'सहायता रोकी गई।',
      'connecting_backend': 'नेविगेशन बैकएंड से कनेक्ट हो रहा है...',
      'backend_unavailable':
          'बैकएंड उपलब्ध नहीं है। जांचें कि फोन और कंप्यूटर एक ही Wi-Fi नेटवर्क पर हैं।',
      'connection_error': 'कनेक्शन त्रुटि। जांचें कि बैकएंड चल रहा है।',
      'camera_unavailable': 'कैमरा उपलब्ध नहीं है। अनुमतियां जांचें।',
      'camera_error': 'कैमरा त्रुटि',
      'navigation_backend_error': 'नेविगेशन बैकएंड त्रुटि',
      'speech_recognition_unavailable':
          'स्पीच पहचान उपलब्ध नहीं है। टच नियंत्रण का उपयोग करें।',
      'help_message': 'उपलब्ध आदेश: सहायता शुरू करें, सहायता रोकें, सहायता।',
      'language_selection_title': 'भाषा चुनें',
      'language_selection_subtitle': 'अपनी पसंदीदा भाषा चुनें',
      'continue': 'जारी रखें',
      'for_visually_impaired': 'दृष्टिहीन लोगों के लिए',
      'continue_action': 'जारी रखें',
      'stop_action': 'रुकें',
      'caution_action': 'सावधान। धीरे चलें।',
      'move_left_action': 'बाएं जाएं',
      'move_right_action': 'दाएं जाएं',
      'no_detected_obstacles': 'कोई बाधा पता नहीं चली',
      'change_language': 'भाषा बदलें',
      'start_before_read': 'सहायता शुरू करने से पहले साइन पढ़ें।',
      'could_not_capture':
          'मैं साइन कैप्चर नहीं कर पाया। फोन स्थिर रखें और साइन पढ़ने के लिए कहें।',
      'could_not_read':
          'मैं उस साइन को स्पष्ट रूप से नहीं पढ़ पाया। फोन स्थिर रखें और साइन पढ़ने के लिए कहें।',
      'sign_says': 'साइन कहता है',
      'no_recent_view':
          'मेरे पास हाल का कैमरा दृश्य नहीं है। सहायता शुरू करें और फिर से पूछें।',
      'no_object_detected': 'में',
      'potential_obstacle': 'में',
      'objects_detected': 'में',
      'camera_view': 'कैमरा दृश्य',
      'not_confirm_route':
          'इससे यह पुष्टि नहीं होती कि चलने का रास्ता साफ़ है।',
      'camera_relative':
          'यह कैमरा-दृश्य पर आधारित है, नक्शे के रास्ते का मार्गदर्शन नहीं।',
    },
  };

  AppLanguage? _currentLanguage;

  Future<void> init() async {
    final prefs = await _getPrefs();
    final languageCode = prefs.getString(_storageKey);
    if (languageCode != null) {
      _currentLanguage = _languageData.entries
          .firstWhere(
            (entry) => entry.value.code == languageCode,
            orElse: () => _languageData.entries.first,
          )
          .key;
    } else {
      _currentLanguage = null; // Will show language selection
    }
  }

  AppLanguage? get currentLanguage => _currentLanguage;

  AppLanguageData getLanguageData(AppLanguage language) {
    return _languageData[language]!;
  }

  String getMessage(String key) {
    return _messages[AppLanguage.english]![key] ?? key;
  }

  String localizeNavigationAction(String action, String reason) {
    String speechMessage(String key) {
      final language = _currentLanguage ?? AppLanguage.english;
      return _messages[language]![key] ??
          _messages[AppLanguage.english]![key] ??
          key;
    }

    switch (action.toUpperCase()) {
      case 'CONTINUE':
        return speechMessage('continue_action');
      case 'STOP':
        return speechMessage('stop_action');
      case 'CAUTION / SLOW DOWN':
        return speechMessage('caution_action');
      case 'MOVE LEFT':
        return speechMessage('move_left_action');
      case 'MOVE RIGHT':
        return speechMessage('move_right_action');
      default:
        return '$action. $reason.';
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    final prefs = await _getPrefs();
    await prefs.setString(_storageKey, _languageData[language]!.code);
  }

  Future<void> clearLanguage() async {
    _currentLanguage = null;
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey);
  }

  Future<shared_preferences.SharedPreferences> _getPrefs() async {
    return await shared_preferences.SharedPreferences.getInstance();
  }

  bool isLanguageSelected() {
    return _currentLanguage != null;
  }
}
