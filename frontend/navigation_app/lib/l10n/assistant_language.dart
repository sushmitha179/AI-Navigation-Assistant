enum AssistantLanguage {
  english('en', 'English', 'en-US'),
  telugu('te', 'తెలుగు', 'te-IN'),
  hindi('hi', 'हिंदी', 'hi-IN');

  const AssistantLanguage(this.storageCode, this.nativeName, this.localeTag);

  final String storageCode;
  final String nativeName;
  final String localeTag;

  static AssistantLanguage? fromStorageCode(String? code) {
    for (final language in values) {
      if (language.storageCode == code) return language;
    }
    return null;
  }
}

enum SceneQuestionPosition { front, left, right, nearby }

class AssistantLocalizations {
  const AssistantLocalizations(this.language);

  final AssistantLanguage language;

  static final Map<AssistantLanguage, Map<String, String>> _messages = {
    AssistantLanguage.english: {
      'appTitle': 'AI Navigation Assistant',
      'assistantStatus': 'ASSISTANT STATUS',
      'navigationMessage': 'NAVIGATION MESSAGE',
      'statusReady': 'Assistant Ready',
      'statusStarting': 'Assistant Starting',
      'statusRunning': 'Assistant Running',
      'statusStopped': 'Assistant Stopped',
      'statusError': 'Assistant Error',
      'waiting': 'Waiting to start...',
      'voiceStarting': 'Voice control starting',
      'voiceListening': 'Listening for voice commands',
      'voiceUnavailable': 'Microphone or speech recognition unavailable',
      'screenLabel': 'Assistance screen',
      'tapStart': 'Tap the screen to start assistance',
      'tapStop': 'Tap the screen to stop assistance',
      'startLabel': 'Start assistance',
      'stopLabel': 'Stop assistance',
      'startHint': 'Double tap to start navigation assistance',
      'stopHint': 'Double tap to stop navigation assistance',
      'footerTitle': 'AI-Powered Intelligent Navigation Assistant',
      'footerAudience': 'For Visually Impaired People',
      'welcome':
          'AI Navigation Assistant is ready. Say start assistance to begin.',
      'connecting': 'Connecting to the navigation backend.',
      'started': 'Assistance started. Camera guidance is active.',
      'startFailed':
          'Unable to start assistance. Check camera permission and backend connection.',
      'stopped': 'Assistance stopped. Ready to start again.',
      'analysisUnavailable':
          'Navigation analysis is unavailable. Do not rely on guidance until it recovers.',
      'questionUnavailable':
          'I do not have a recent camera view. Start assistance and ask again.',
      'noObjectAtArea':
          'No object was detected on the {area}. This does not confirm the walking route is clear.',
      'obstacleAtArea':
          'Potential obstacle on the {area}. {objects}. This is camera-relative, not mapped route guidance.',
      'lowRiskAtArea':
          'Objects detected on the {area}, with low reported collision risk. {objects}. This does not confirm the route is clear.',
      'unknownRiskAtArea':
          'Objects detected on the {area}, but their risk could not be determined. {objects}. Do not assume the route is clear.',
      'cameraSummary':
          'Camera view: {objects}. Positions are relative to the image, not a mapped route.',
      'emptySummary':
          'No objects were detected in the current camera view. This does not confirm the walking route is clear.',
      'hazardSummary':
          'Nearby {risk}-risk scene: {objects}. Positions are image-relative; depth is relative, not distance in meters.',
      'detectedSummary':
          'Detected in the camera view: {objects}. Positions are image-relative; this does not confirm the route is clear.',
      'detection': '{object} at the {area}, {risk}, {proximity}',
      'riskHigh': 'high reported risk',
      'riskMedium': 'medium reported risk',
      'riskLow': 'low reported risk',
      'riskUnknown': 'risk unavailable',
      'depthUnknown': 'relative depth unavailable',
      'depthVeryClose': 'relative proximity very close',
      'depthClose': 'relative proximity close',
      'depthMedium': 'relative proximity medium',
      'depthFar': 'relative proximity far',
      'areaFront': 'center of the camera view',
      'areaLeft': 'left side of the camera view',
      'areaRight': 'right side of the camera view',
      'actionContinue': 'Continue',
      'actionStop': 'Stop',
      'actionMoveLeft': 'Move left',
      'actionMoveRight': 'Move right',
      'actionCaution': 'Caution. Slow down.',
      'warning': 'Warning.',
      'routeDisclaimer':
          'This is a camera-based suggestion, not a mapped route.',
      'readSignStart': 'Start assistance before reading a sign.',
      'captureRetry':
          'I could not capture the sign. Hold the phone steady and say read sign to retry.',
      'ocrRetry':
          'I could not read that sign clearly. Hold the phone steady and say read sign to retry.',
      'ocrUnavailable':
          'Sign reading is unavailable. Check the backend connection and try again.',
      'signSays': 'The sign says: {text}.',
      'help':
          'Available commands: start assistance, stop assistance, read sign, ask what is in front, left, or right, repeat instruction, and help.',
      'speechFallback':
          'Selected-language speech recognition is unavailable. English recognition will be used.',
      'ttsFallback':
          'The selected-language voice is unavailable. English speech will be used; install its Android speech data to enable this language.',
      'changeLanguage': 'Change language',
      'selectLanguage': 'Choose your language',
      'languageHelp':
          'Select a language, then continue. Voice availability depends on Android language data.',
      'continue': 'Continue',
      'cancel': 'Cancel',
      'englishName': 'English',
      'teluguName': 'Telugu',
      'hindiName': 'Hindi',
    },
    AssistantLanguage.telugu: {
      'appTitle': 'AI నావిగేషన్ సహాయకుడు',
      'assistantStatus': 'సహాయకుడి స్థితి',
      'navigationMessage': 'నావిగేషన్ సూచన',
      'statusReady': 'సహాయకుడు సిద్ధంగా ఉన్నారు',
      'statusStarting': 'సహాయకుడు ప్రారంభమవుతున్నారు',
      'statusRunning': 'సహాయం నడుస్తోంది',
      'statusStopped': 'సహాయం ఆగింది',
      'statusError': 'సహాయం ప్రారంభం కాలేదు',
      'waiting': 'ప్రారంభించడానికి వేచి ఉంది',
      'voiceStarting': 'వాయిస్ నియంత్రణ ప్రారంభమవుతోంది',
      'voiceListening': 'వాయిస్ ఆదేశాల కోసం వింటోంది',
      'voiceUnavailable': 'మైక్రోఫోన్ లేదా వాయిస్ గుర్తింపు అందుబాటులో లేదు',
      'screenLabel': 'సహాయ స్క్రీన్',
      'tapStart': 'సహాయం ప్రారంభించడానికి స్క్రీన్‌ను తాకండి',
      'tapStop': 'సహాయం ఆపడానికి స్క్రీన్‌ను తాకండి',
      'startLabel': 'సహాయం ప్రారంభించండి',
      'stopLabel': 'సహాయం ఆపండి',
      'startHint': 'నావిగేషన్ సహాయం ప్రారంభించడానికి రెండుసార్లు తాకండి',
      'stopHint': 'నావిగేషన్ సహాయం ఆపడానికి రెండుసార్లు తాకండి',
      'footerTitle': 'AI నావిగేషన్ సహాయకుడు',
      'footerAudience': 'దృష్టి లోపం ఉన్నవారి కోసం',
      'welcome':
          'AI నావిగేషన్ సహాయకుడు సిద్ధంగా ఉన్నారు. ప్రారంభించడానికి సహాయం ప్రారంభించండి అని చెప్పండి.',
      'connecting': 'నావిగేషన్ బ్యాక్‌ఎండ్‌కు అనుసంధానిస్తోంది.',
      'started': 'సహాయం ప్రారంభమైంది. కెమెరా సూచనలు ప్రారంభమయ్యాయి.',
      'startFailed':
          'సహాయం ప్రారంభం కాలేదు. కెమెరా అనుమతి మరియు బ్యాక్‌ఎండ్ అనుసంధానాన్ని తనిఖీ చేయండి.',
      'stopped': 'సహాయం ఆగింది. మళ్లీ ప్రారంభించడానికి సిద్ధంగా ఉంది.',
      'analysisUnavailable':
          'నావిగేషన్ విశ్లేషణ అందుబాటులో లేదు. తిరిగి అందుబాటులోకి వచ్చే వరకు సూచనలను నమ్మవద్దు.',
      'questionUnavailable':
          'తాజా కెమెరా దృశ్యం లేదు. సహాయం ప్రారంభించి మళ్లీ అడగండి.',
      'noObjectAtArea':
          '{area}లో వస్తువు గుర్తించబడలేదు. నడిచే దారి ఖాళీగా ఉందని దీని అర్థం కాదు.',
      'obstacleAtArea':
          '{area}లో అడ్డంకి ఉండవచ్చు. {objects}. ఇది కెమెరా దృశ్యానికి సంబంధించినది, మ్యాప్ దారికి కాదు.',
      'lowRiskAtArea':
          '{area}లో తక్కువ ప్రమాదంగా గుర్తించిన వస్తువులు ఉన్నాయి. {objects}. దారి ఖాళీ అని ఇది నిర్ధారించదు.',
      'unknownRiskAtArea':
          '{area}లో వస్తువులు కనిపించాయి, కానీ వాటి ప్రమాద స్థాయిని గుర్తించలేకపోయాం. {objects}. దారి ఖాళీగా ఉందని అనుకోకండి.',
      'cameraSummary':
          'కెమెరా దృశ్యం: {objects}. స్థానాలు చిత్రానికి సంబంధించినవి, మ్యాప్ దారికి కావు.',
      'emptySummary':
          'ప్రస్తుత కెమెరా దృశ్యంలో వస్తువులు గుర్తించబడలేదు. నడిచే దారి ఖాళీగా ఉందని దీని అర్థం కాదు.',
      'hazardSummary':
          'కెమెరా దృశ్యంలో సమీపంలో {risk} ప్రమాదం: {objects}. లోతు సాపేక్ష అంచనా మాత్రమే, మీటర్ల దూరం కాదు.',
      'detectedSummary':
          'కెమెరా దృశ్యంలో గుర్తించినవి: {objects}. స్థానాలు చిత్రానికి సంబంధించినవి; దారి ఖాళీగా ఉందని ఇది నిర్ధారించదు.',
      'detection': '{area}లో {object}, {risk}, {proximity}',
      'riskHigh': 'అధిక ప్రమాదం',
      'riskMedium': 'మధ్యస్థ ప్రమాదం',
      'riskLow': 'తక్కువ ప్రమాదం',
      'riskUnknown': 'ప్రమాద స్థాయి తెలియదు',
      'depthUnknown': 'సాపేక్ష లోతు అందుబాటులో లేదు',
      'depthVeryClose': 'సాపేక్షంగా చాలా దగ్గర',
      'depthClose': 'సాపేక్షంగా దగ్గర',
      'depthMedium': 'సాపేక్ష మధ్య దూరం',
      'depthFar': 'సాపేక్షంగా దూరం',
      'areaFront': 'కెమెరా దృశ్యం మధ్యలో',
      'areaLeft': 'కెమెరా దృశ్యం ఎడమ వైపు',
      'areaRight': 'కెమెరా దృశ్యం కుడి వైపు',
      'actionContinue': 'కొనసాగండి',
      'actionStop': 'ఆగండి',
      'actionMoveLeft': 'ఎడమవైపు కదలండి',
      'actionMoveRight': 'కుడివైపు కదలండి',
      'actionCaution': 'జాగ్రత్త. నెమ్మదిగా కదలండి.',
      'warning': 'హెచ్చరిక.',
      'routeDisclaimer': 'ఇది కెమెరా ఆధారిత సూచన మాత్రమే, మ్యాప్ దారి కాదు.',
      'readSignStart': 'బోర్డు చదవడానికి ముందు సహాయం ప్రారంభించండి.',
      'captureRetry':
          'బోర్డును చిత్రీకరించలేకపోయాను. ఫోన్‌ను స్థిరంగా ఉంచి బోర్డు చదువు అని మళ్లీ చెప్పండి.',
      'ocrRetry':
          'బోర్డును స్పష్టంగా చదవలేకపోయాను. ఫోన్‌ను స్థిరంగా ఉంచి బోర్డు చదువు అని మళ్లీ చెప్పండి.',
      'ocrUnavailable':
          'బోర్డు చదవడం అందుబాటులో లేదు. బ్యాక్‌ఎండ్ అనుసంధానాన్ని తనిఖీ చేసి మళ్లీ ప్రయత్నించండి.',
      'signSays': 'బోర్డుపై ఇలా ఉంది: {text}.',
      'help':
          'సహాయం ప్రారంభించండి, సహాయం ఆపండి, బోర్డు చదువు, ముందు లేదా ఎడమ లేదా కుడి వైపు ఏముంది అని అడగండి, సూచన మళ్లీ చెప్పు, లేదా సహాయం అని చెప్పండి.',
      'speechFallback':
          'ఈ భాషలో వాయిస్ గుర్తింపు అందుబాటులో లేదు. ఇంగ్లీష్ వాయిస్ గుర్తింపును ఉపయోగిస్తాము.',
      'ttsFallback':
          'ఈ భాషకు వాయిస్ అందుబాటులో లేదు. ఇంగ్లీష్‌లో మాట్లాడుతుంది. ఈ భాషను ప్రారంభించడానికి Android వాయిస్ డేటాను ఇన్‌స్టాల్ చేయండి.',
      'changeLanguage': 'భాష మార్చండి',
      'selectLanguage': 'మీ భాషను ఎంచుకోండి',
      'languageHelp':
          'భాషను ఎంచుకుని కొనసాగించండి. వాయిస్ అందుబాటు Android భాషా డేటాపై ఆధారపడి ఉంటుంది.',
      'continue': 'కొనసాగించండి',
      'cancel': 'రద్దు చేయండి',
      'englishName': 'ఇంగ్లీష్',
      'teluguName': 'తెలుగు',
      'hindiName': 'హిందీ',
    },
    AssistantLanguage.hindi: {
      'appTitle': 'AI नेविगेशन सहायक',
      'assistantStatus': 'सहायक की स्थिति',
      'navigationMessage': 'नेविगेशन निर्देश',
      'statusReady': 'सहायक तैयार है',
      'statusStarting': 'सहायक शुरू हो रहा है',
      'statusRunning': 'सहायता चालू है',
      'statusStopped': 'सहायता रुक गई है',
      'statusError': 'सहायता शुरू नहीं हुई',
      'waiting': 'शुरू करने की प्रतीक्षा में',
      'voiceStarting': 'वॉइस नियंत्रण शुरू हो रहा है',
      'voiceListening': 'वॉइस निर्देश सुन रहा है',
      'voiceUnavailable': 'माइक्रोफ़ोन या वॉइस पहचान उपलब्ध नहीं है',
      'screenLabel': 'सहायता स्क्रीन',
      'tapStart': 'सहायता शुरू करने के लिए स्क्रीन छुएँ',
      'tapStop': 'सहायता रोकने के लिए स्क्रीन छुएँ',
      'startLabel': 'सहायता शुरू करें',
      'stopLabel': 'सहायता रोकें',
      'startHint': 'नेविगेशन सहायता शुरू करने के लिए दो बार छुएँ',
      'stopHint': 'नेविगेशन सहायता रोकने के लिए दो बार छुएँ',
      'footerTitle': 'AI नेविगेशन सहायक',
      'footerAudience': 'दृष्टिबाधित लोगों के लिए',
      'welcome':
          'AI नेविगेशन सहायक तैयार है। शुरू करने के लिए सहायता शुरू करें कहें।',
      'connecting': 'नेविगेशन बैकएंड से जुड़ रहा है।',
      'started': 'सहायता शुरू हो गई है। कैमरा निर्देश चालू हैं।',
      'startFailed':
          'सहायता शुरू नहीं हो सकी। कैमरा अनुमति और बैकएंड कनेक्शन जाँचें।',
      'stopped': 'सहायता रुक गई है। फिर से शुरू करने के लिए तैयार है।',
      'analysisUnavailable':
          'नेविगेशन विश्लेषण उपलब्ध नहीं है। इसके लौटने तक निर्देशों पर भरोसा न करें।',
      'questionUnavailable':
          'हाल का कैमरा दृश्य उपलब्ध नहीं है। सहायता शुरू करके फिर पूछें।',
      'noObjectAtArea':
          '{area} में कोई वस्तु नहीं दिखी। इसका अर्थ यह नहीं कि चलने का रास्ता खाली है।',
      'obstacleAtArea':
          '{area} में संभावित बाधा। {objects}. यह कैमरा-दृश्य पर आधारित है, नक्शे के रास्ते पर नहीं।',
      'lowRiskAtArea':
          '{area} में कम जोखिम वाली वस्तुएँ दिखीं। {objects}. इससे रास्ता खाली साबित नहीं होता।',
      'unknownRiskAtArea':
          '{area} में वस्तुएँ दिखीं, लेकिन उनका जोखिम पता नहीं चल सका। {objects}. रास्ते को खाली न मानें।',
      'cameraSummary':
          'कैमरा दृश्य: {objects}. स्थितियाँ तस्वीर के अनुसार हैं, नक्शे के रास्ते के अनुसार नहीं।',
      'emptySummary':
          'मौजूदा कैमरा दृश्य में कोई वस्तु नहीं दिखी। इसका अर्थ यह नहीं कि चलने का रास्ता खाली है।',
      'hazardSummary':
          'कैमरा दृश्य में पास में {risk} जोखिम: {objects}. गहराई केवल सापेक्ष अनुमान है, मीटर में दूरी नहीं।',
      'detectedSummary':
          'कैमरा दृश्य में दिखा: {objects}. स्थितियाँ तस्वीर के अनुसार हैं; इससे रास्ता खाली साबित नहीं होता।',
      'detection': '{area} में {object}, {risk}, {proximity}',
      'riskHigh': 'उच्च जोखिम',
      'riskMedium': 'मध्यम जोखिम',
      'riskLow': 'कम जोखिम',
      'riskUnknown': 'जोखिम उपलब्ध नहीं',
      'depthUnknown': 'सापेक्ष गहराई उपलब्ध नहीं',
      'depthVeryClose': 'सापेक्ष रूप से बहुत पास',
      'depthClose': 'सापेक्ष रूप से पास',
      'depthMedium': 'सापेक्ष मध्यम दूरी',
      'depthFar': 'सापेक्ष रूप से दूर',
      'areaFront': 'कैमरा दृश्य के बीच में',
      'areaLeft': 'कैमरा दृश्य के बाईं ओर',
      'areaRight': 'कैमरा दृश्य के दाईं ओर',
      'actionContinue': 'आगे बढ़ें',
      'actionStop': 'रुकें',
      'actionMoveLeft': 'बाईं ओर जाएँ',
      'actionMoveRight': 'दाईं ओर जाएँ',
      'actionCaution': 'सावधान। धीरे चलें।',
      'warning': 'चेतावनी।',
      'routeDisclaimer': 'यह कैमरा-आधारित सुझाव है, नक्शे का रास्ता नहीं।',
      'readSignStart': 'साइन पढ़ने से पहले सहायता शुरू करें।',
      'captureRetry':
          'साइन की तस्वीर नहीं ले सका। फ़ोन स्थिर रखें और साइन पढ़ें कहकर फिर कोशिश करें।',
      'ocrRetry':
          'साइन स्पष्ट नहीं पढ़ सका। फ़ोन स्थिर रखें और साइन पढ़ें कहकर फिर कोशिश करें।',
      'ocrUnavailable':
          'साइन पढ़ना उपलब्ध नहीं है। बैकएंड कनेक्शन जाँचकर फिर कोशिश करें।',
      'signSays': 'साइन पर लिखा है: {text}.',
      'help':
          'सहायता शुरू करें, सहायता रोकें, साइन पढ़ें, सामने या बाईं या दाईं ओर क्या है पूछें, निर्देश दोहराएँ, या मदद कहें।',
      'speechFallback':
          'इस भाषा में वॉइस पहचान उपलब्ध नहीं है। अंग्रेज़ी वॉइस पहचान उपयोग होगी।',
      'ttsFallback':
          'इस भाषा की आवाज़ उपलब्ध नहीं है। अंग्रेज़ी में बोला जाएगा। इसे चालू करने के लिए Android वॉइस डेटा इंस्टॉल करें।',
      'changeLanguage': 'भाषा बदलें',
      'selectLanguage': 'अपनी भाषा चुनें',
      'languageHelp':
          'भाषा चुनकर जारी रखें। वॉइस उपलब्धता Android भाषा डेटा पर निर्भर है।',
      'continue': 'जारी रखें',
      'cancel': 'रद्द करें',
      'englishName': 'अंग्रेज़ी',
      'teluguName': 'तेलुगु',
      'hindiName': 'हिंदी',
    },
  };

  String text(String key, [Map<String, String> values = const {}]) {
    var result = _messages[language]![key] ??
        _messages[AssistantLanguage.english]![key] ??
        key;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  String area(SceneQuestionPosition position) => text(switch (position) {
        SceneQuestionPosition.front => 'areaFront',
        SceneQuestionPosition.left => 'areaLeft',
        SceneQuestionPosition.right => 'areaRight',
        SceneQuestionPosition.nearby => 'areaFront',
      });

  String action(String action) => text(switch (action) {
        'CONTINUE' => 'actionContinue',
        'STOP' => 'actionStop',
        'MOVE LEFT' => 'actionMoveLeft',
        'MOVE RIGHT' => 'actionMoveRight',
        'CAUTION / SLOW DOWN' => 'actionCaution',
        _ => 'actionStop',
      });

  String risk(String risk) => text(switch (risk.trim().toUpperCase()) {
        'HIGH' => 'riskHigh',
        'MEDIUM' => 'riskMedium',
        'LOW' => 'riskLow',
        _ => 'riskUnknown',
      });

  String proximity(String? proximity) =>
      text(switch (proximity?.trim().toUpperCase()) {
        'VERY CLOSE' => 'depthVeryClose',
        'CLOSE' => 'depthClose',
        'MEDIUM' => 'depthMedium',
        'FAR' => 'depthFar',
        _ => 'depthUnknown',
      });

  String objectName(String name) {
    return _objectNames[language]?[name.toLowerCase()] ?? name;
  }

  static const Map<AssistantLanguage, Map<String, String>> _objectNames = {
    AssistantLanguage.english: {},
    AssistantLanguage.telugu: {
      'person': 'వ్యక్తి',
      'bicycle': 'సైకిల్',
      'car': 'కారు',
      'chair': 'కుర్చీ',
      'dog': 'కుక్క',
      'cat': 'పిల్లి',
      'bus': 'బస్సు',
      'truck': 'ట్రక్',
      'motorcycle': 'మోటార్‌సైకిల్',
      'stairs': 'మెట్లు',
    },
    AssistantLanguage.hindi: {
      'person': 'व्यक्ति',
      'bicycle': 'साइकिल',
      'car': 'कार',
      'chair': 'कुर्सी',
      'dog': 'कुत्ता',
      'cat': 'बिल्ली',
      'bus': 'बस',
      'truck': 'ट्रक',
      'motorcycle': 'मोटरसाइकिल',
      'stairs': 'सीढ़ियाँ',
    },
  };

  String? _match(String text, List<String> phrases) {
    for (final phrase in phrases) {
      if (text.contains(phrase)) return phrase;
    }
    return null;
  }

  String normalizeCommand(String command) => command
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  bool isStop(String command) =>
      _match(
          normalizeCommand(command),
          switch (language) {
            AssistantLanguage.english => const [
                'stop assistance',
                'stop navigation',
                'stop'
              ],
            AssistantLanguage.telugu => const [
                'సహాయం ఆపండి',
                'నావిగేషన్ ఆపండి',
                'ఆపండి'
              ],
            AssistantLanguage.hindi => const [
                'सहायता रोकें',
                'नेविगेशन रोकें',
                'रुकें'
              ],
          }) !=
      null;

  bool isStart(String command) =>
      _match(
          normalizeCommand(command),
          switch (language) {
            AssistantLanguage.english => const ['start assistance', 'start'],
            AssistantLanguage.telugu => const [
                'సహాయం ప్రారంభించండి',
                'ప్రారంభించండి'
              ],
            AssistantLanguage.hindi => const ['सहायता शुरू करें', 'शुरू करें'],
          }) !=
      null;

  bool isReadSign(String command) =>
      _match(
          normalizeCommand(command),
          switch (language) {
            AssistantLanguage.english => const ['read sign', 'read text'],
            AssistantLanguage.telugu => const ['బోర్డు చదవండి', 'సైన్ చదవండి'],
            AssistantLanguage.hindi => const ['साइन पढ़ें', 'बोर्ड पढ़ें'],
          }) !=
      null;

  bool isRepeat(String command) =>
      _match(
          normalizeCommand(command),
          switch (language) {
            AssistantLanguage.english => const ['repeat instruction', 'repeat'],
            AssistantLanguage.telugu => const [
                'సూచన మళ్లీ చెప్పండి',
                'మళ్లీ చెప్పండి'
              ],
            AssistantLanguage.hindi => const ['निर्देश दोहराएँ', 'दोहराएँ'],
          }) !=
      null;

  bool isHelp(String command) =>
      _match(
          normalizeCommand(command),
          switch (language) {
            AssistantLanguage.english => const ['help'],
            AssistantLanguage.telugu => const ['సహాయం'],
            AssistantLanguage.hindi => const ['मदद'],
          }) !=
      null;

  SceneQuestionPosition? questionPosition(String command) {
    final normalized = normalizeCommand(command);
    final phrases = switch (language) {
      AssistantLanguage.english => {
          SceneQuestionPosition.left: const [
            'what is on my left',
            'what is to my left',
            'obstacle on my left'
          ],
          SceneQuestionPosition.right: const [
            'what is on my right',
            'what is to my right',
            'obstacle on my right'
          ],
          SceneQuestionPosition.front: const [
            'what is in front',
            'what is ahead',
            'obstacle ahead',
            'obstacle in front'
          ],
          SceneQuestionPosition.nearby: const [
            'what is around me',
            'nearby objects',
            'what do you see'
          ],
        },
      AssistantLanguage.telugu => {
          SceneQuestionPosition.left: const [
            'నా ఎడమ వైపు ఏముంది',
            'ఎడమ వైపు అడ్డంకి ఉందా'
          ],
          SceneQuestionPosition.right: const [
            'నా కుడి వైపు ఏముంది',
            'కుడి వైపు అడ్డంకి ఉందా'
          ],
          SceneQuestionPosition.front: const [
            'నా ముందు ఏముంది',
            'ముందు అడ్డంకి ఉందా'
          ],
          SceneQuestionPosition.nearby: const ['నా చుట్టూ ఏముంది'],
        },
      AssistantLanguage.hindi => {
          SceneQuestionPosition.left: const [
            'मेरी बाईं ओर क्या है',
            'बाईं ओर बाधा है'
          ],
          SceneQuestionPosition.right: const [
            'मेरी दाईं ओर क्या है',
            'दाईं ओर बाधा है'
          ],
          SceneQuestionPosition.front: const [
            'मेरे सामने क्या है',
            'सामने बाधा है'
          ],
          SceneQuestionPosition.nearby: const ['मेरे आसपास क्या है'],
        },
    };
    for (final entry in phrases.entries) {
      if (_match(normalized, entry.value) != null) return entry.key;
    }
    return null;
  }
}
