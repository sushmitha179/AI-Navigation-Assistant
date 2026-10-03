# Independent Verification Report
## AI-Powered Intelligent Navigation and Scene Understanding Assistant

**Date:** 2026-10-02
**Objective:** Independent verification of implementation and automated test execution

---

## Priority 1: Depth Classification Verification

### Files Inspected
- `depth_classifier.py`
- `midas_depth.py`
- `perception_module.py`

### MiDaS Output Flow Analysis

**MiDaS Model Output (midas_depth.py):**
- Line 81: `prediction = self.midas(input_batch)` - Raw model output
- Line 84-89: Interpolation to resize to original dimensions
- Line 92: `depth_map = prediction.cpu().numpy()` - Converted to numpy array
- **No normalization or inversion applied** - Output is raw MiDaS inverse depth

**Depth Value Consumption (perception_module.py):**
- Line 71: `depth_value = self.midas.get_depth_at_bbox(bbox)` - Median depth in bbox region
- Line 77-79: `depth_classifier.classify(depth_value, depth_map)` - Pass raw value

**Classification Logic (depth_classifier.py):**
- Lines 67-69: Calculate percentiles of current depth map
- Lines 77-84: **Uses `>=` comparisons** (higher values = closer)

### Verification Results

✅ **CONFIRMED:** MiDaS outputs inverse depth (higher values = closer objects)
- Code correctly uses `>=` comparisons in adaptive classification
- Code correctly uses `>=` comparisons in fixed classification
- Fixed thresholds (600+, 400+, 200+) are appropriate for MiDaS Small output scale (0-1000+)

### Test Results

**test_midas_polarity.py** (NEW - Added during verification):
```
Nearby value 700: VERY CLOSE - Object is very close (top 25% closest)
Distant value 100: FAR - Object is far (bottom 25% deepest)
Medium value 300: MEDIUM - Object is at medium distance
[OK] Inverse depth polarity verified: higher values = closer objects

Value 800: VERY CLOSE - Object is very close
Value 500: CLOSE - Object is close
Value 300: MEDIUM - Object is at medium distance
Value 100: FAR - Object is far
[OK] Fixed thresholds verified

[OK] Depth value scale is within expected range (0-1000+)
Exit code: 0
```

**test_depth_classifier.py:**
```
Ran 7 tests in 0.303s
OK
Exit code: 0
```

### Conclusion
**No bugs found.** The depth classification implementation is correct. Higher MiDaS values correctly map to closer objects through the `>=` comparisons.

---

## Priority 2: Automated Tests

### Backend Python Tests

**Test Execution Commands:**
```bash
cd /c/Users/singa_x3eldes/AI-Navigation-Assistant/backend
./venv/Scripts/python.exe test_collision_risk.py
./venv/Scripts/python.exe test_depth_classifier.py
./venv/Scripts/python.exe test_navigation_engine.py
./venv/Scripts/python.exe test_api_server.py
./venv/Scripts/python.exe test_api_contract.py
./venv/Scripts/python.exe test_midas_polarity.py
```

**Results:**

1. **test_collision_risk.py**: 16/16 PASSED (0.001s)
   - Including updated test for unknown depth = MEDIUM risk

2. **test_depth_classifier.py**: 7/7 PASSED (0.303s)
   - Inverse depth polarity tests

3. **test_navigation_engine.py**: 13/13 PASSED (0.001s)
   - Navigation decision logic

4. **test_api_server.py**: 1/1 PASSED (0.026s)
   - API server basic functionality

5. **test_api_contract.py** (NEW): 6/6 PASSED (0.001s)
   - API contract verification
   - Response structure validation
   - Enum conversion
   - JSON serialization
   - Unknown depth handling
   - Failure never returns false CONTINUE

6. **test_midas_polarity.py** (NEW): 3/3 PASSED
   - Synthetic depth map with nearby/distant regions
   - Fixed threshold verification
   - Depth value scale validation

**Total Backend Tests: 46/46 PASSED** ✅

**Python Compilation Check:**
```bash
./venv/Scripts/python.exe -m py_compile api_server.py perception_module.py midas_depth.py depth_classifier.py collision_risk.py navigation_engine.py
```
**Result:** Exit code 0 ✅ (No syntax errors)

### Flutter Tests

**Status:** Flutter CLI not found in environment
- Searched locations: `$PROGRAMFILES/Flutter`, `C:/Flutter`, `$HOME/flutter`
- Result: Flutter not found

**Cannot execute:**
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

**Test Files Created (awaiting execution):**
- `test/test_backend_service.dart`: 12 tests for NavigationModel JSON parsing
- `test/test_voice_commands.dart`: 14 tests for voice commands and state transitions

**User must run manually:**
```bash
cd C:\Users\singa_x3eldes\AI-Navigation-Assistant\frontend\navigation_app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

---

## Priority 3: API Contract Verification

### Files Inspected
- `api_server.py`
- `backend_service.dart`
- `navigation_model.dart`

### Backend Response Structure (api_server.py)

**Line 55:** `decision = NavigationDecisionEngine().decide(results.get("detections", []))`
**Line 56:** `return _json_value({**decision, "detections": detections})`

**Response Fields:**
- `action`: String (e.g., "CONTINUE", "STOP", "MOVE LEFT", "MOVE RIGHT", "CAUTION / SLOW DOWN")
- `reason`: String (human-readable explanation)
- `priority`: String ("LOW", "MEDIUM", "HIGH")
- `relevant_object`: String or null (object name for highest-risk detection)
- `detections`: Array of detection objects

**Detection Fields (after filtering line 52):**
- `class_name`: String
- `bbox`: Array [x1, y1, x2, y2]
- `confidence`: Float
- `proximity_category`: String ("VERY CLOSE", "CLOSE", "MEDIUM", "FAR", or "UNKNOWN")
- `collision_risk`: String ("LOW", "MEDIUM", "HIGH")
- `horizontal_position`: String ("LEFT", "CENTER", "RIGHT")
- `depth_value`: **FILTERED OUT** (not sent to Flutter)

### Flutter Parsing Logic (navigation_model.dart)

**Lines 18-29:** `fromJson` method
- Line 21: `action` defaults to "CONTINUE" if missing
- Line 22: `reason` defaults to "No navigation instruction" if missing
- Line 23: `priority` defaults to "LOW" if missing
- Line 24: `relevant_object` nullable
- Lines 25-28: `detections` filtered to Map types, parsed with DetectionModel.fromJson

### Contract Verification Results

✅ **Field Matching:**
- Backend sends all required fields
- Flutter expects all required fields
- Defaults handle missing fields gracefully

✅ **Enum Conversion:**
- Backend converts enums to strings via `_json_value` (line 30-31)
- Flutter receives strings
- No enum mismatch

✅ **Unknown Depth Handling:**
- Backend: `proximity_category` = None or "UNKNOWN"
- Collision risk: MEDIUM (conservative)
- Flutter: Accepts string values

✅ **Failure Safety:**
- Empty detections → CONTINUE (appropriate)
- Unknown depth + CENTER → Not CONTINUE (appropriate)
- HIGH risk + CENTER → STOP (appropriate)

### Backend Service Validation (backend_service.dart)

**Lines 17-34:** `connect()` method
- 10-second timeout
- Specific error messages
- Throws on non-200 status

**Lines 41-84:** `processFrame()` method
- 30-second timeout
- Response structure validation (lines 62-70)
- Validates: `action`, `reason`, `detections` required
- Specific error messages for network, JSON, and general errors

**✅ CONFIRMED:** Failures never silently become CONTINUE
- Line 62-64: Throws if `action` missing
- Line 65-67: Throws if `reason` missing
- Line 68-70: Throws if `detections` missing
- Line 55-57: Throws if status code != 200

### Test Results

**test_api_contract.py**: 6/6 PASSED
- Response structure complete ✅
- Empty detections ✅
- Unknown depth ✅
- Enum conversion ✅
- Failure never continues unsafe ✅
- JSON serialization ✅

---

## Priority 4: Android Behavior Verification

### Files Inspected
- `AndroidManifest.xml`
- `network_security_config.xml`
- `camera_service.dart`
- `speech_recognition_service.dart`
- `MainActivity.kt`
- `home_screen.dart`

### Network Security Configuration

**AndroidManifest.xml (Lines 11-12):**
```xml
android:usesCleartextTraffic="true"
android:networkSecurityConfig="@xml/network_security_config"
```
✅ Correctly configured for local HTTP development

**network_security_config.xml:**
- Allows cleartext for: localhost, 10.0.2.2 (emulator), 192.168.x.x, 172.16.x.x, 10.x.x.x
- ✅ Appropriate for LAN development
- ✅ Does not expose to public internet

### Backend URL Configuration

**home_screen.dart (Lines 37-41):**
```dart
final backendUrl = const String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'http://192.168.1.100:8000',
);
_backendService = BackendService(baseUrl: backendUrl);
```
✅ BackendService requires baseUrl (no hardcoded default in service)
✅ Configurable via --dart-define
✅ Default value preserved for compatibility

### Camera Service

**camera_service.dart (Lines 22-26):**
```dart
final rearCamera = cameras.firstWhere(
  (camera) => camera.lensDirection == CameraLensDirection.back,
  orElse: () => cameras.first,
);
```
✅ Explicit rear camera selection with fallback

**Lines 45-62:** Capture method
- Checks: `_isRunning`, `_captureInProgress`, `controller`, `isTakingPicture`, `isInitialized`
- ✅ Prevents overlapping captures
- ✅ Null safety checks

**Lines 65-77:** Stop method
- Cancels timer
- Resets flags
- Disposes controller with error handling
- ✅ Proper resource cleanup

### Speech Recognition Service

**speech_recognition_service.dart (Lines 53-69):**
```dart
Future<void> setTtsSpeaking(bool speaking) async {
  if (!_isInitialized) return;
  try {
    await _channel.invokeMethod('setTtsSpeaking', speaking);
  } on PlatformException {
    // Ignore errors
  }
}

Future<void> requestCameraPermission() async {
  if (!_isInitialized) return;
  try {
    await _channel.invokeMethod('requestCameraPermission');
  } on PlatformException {
    // Ignore errors
  }
}
```
✅ TTS coordination method added
✅ Camera permission request method added

### MainActivity.kt

**Lines 22, 36-42:** TTS coordination
```kotlin
private var isTtsSpeaking = false

"setTtsSpeaking" -> {
    isTtsSpeaking = call.arguments == true
    if (isTtsSpeaking) {
        speechRecognizer?.stopListening()
        channel?.invokeMethod("onListening", false)
    }
    result.success(true)
}
```
✅ TTS state tracking
✅ Stops recognition during TTS

**Lines 65-70:** Speech result filtering
```kotlin
override fun onResults(results: Bundle?) {
    if (!isTtsSpeaking) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        matches?.firstOrNull()?.let { channel?.invokeMethod("onResult", it) }
    }
    channel?.invokeMethod("onListening", false)
}
```
✅ Ignores results while TTS speaking
✅ Prevents self-recognition

**Lines 44-47, 99-107:** Camera permission
```kotlin
"requestCameraPermission" -> {
    requestCameraPermission()
    result.success(true)
}

private fun requestCameraPermission() {
    if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            cameraPermissionRequestCode
        )
    }
}
```
✅ Camera permission request added
✅ Separate request code from audio

### Home Screen Coordination

**Lines 78-83:** TTS coordination
```dart
Future<void> _speakWithPause(String text) async {
  await _speechRecognitionService.setTtsSpeaking(true);
  await _voiceService.speak(text);
  await Future.delayed(const Duration(milliseconds: 500));
  await _speechRecognitionService.setTtsSpeaking(false);
}
```
✅ Calls setTtsSpeaking before and after speech
✅ 500ms delay for TTS to complete

**Lines 335-387:** Start assistant
- Requests camera permission (line 345)
- Connects to backend with timeout and error handling
- Speaks error messages on failure
- Resets state on failure
- ✅ Proper error handling
- ✅ Spoken feedback

**Lines 389-404:** Analyze frame
- Checks running state
- Validates response structure
- Speaks navigation with coordination
- Catches errors without speaking every error
- ✅ TTS coordination
- ✅ Error spam prevention

**Lines 406-415:** Stop assistant
- Stops camera
- Disconnects backend
- Speaks confirmation with coordination
- ✅ Proper cleanup
- ✅ TTS coordination

### Android Verification Summary

✅ **Network Security:** Correctly configured for local development
✅ **Backend URL:** Configurable, no hardcoded default in service
✅ **Camera Selection:** Rear camera with fallback
✅ **Capture Overlap:** Prevented by flag checks
✅ **Resource Cleanup:** Proper disposal with error handling
✅ **TTS/Speech Coordination:** Implemented and verified
✅ **Permission Handling:** Camera and audio permissions handled

---

## Confirmed Bugs and Fixes

### No Bugs Found

All previous fixes from the Integration Fixes Report have been verified to be correctly implemented:

1. ✅ **Unknown Depth Risk:** Changed to MEDIUM (collision_risk.py line 153)
2. ✅ **Inverse Depth Polarity:** Fixed with >= comparisons (depth_classifier.py)
3. ✅ **TTS Self-Recognition:** Prevented via isTtsSpeaking flag (MainActivity.kt)
4. ✅ **Hardcoded Backend URL:** Made required parameter (backend_service.dart)
5. ✅ **HTTP Timeouts:** Added 10s health, 30s analysis (backend_service.dart)
6. ✅ **Rear Camera Selection:** Explicit selection (camera_service.dart)
7. ✅ **Network Security:** Configured for local networks (AndroidManifest.xml)

### Additional Tests Added

1. **test_midas_polarity.py** - Verifies inverse depth with synthetic data
2. **test_api_contract.py** - Verifies API contract and failure safety

---

## Exact Commands Executed and Results

### Backend Tests

```bash
cd /c/Users/singa_x3eldes/AI-Navigation-Assistant/backend
./venv/Scripts/python.exe test_midas_polarity.py
```
**Result:** Exit code 0, 3/3 tests passed

```bash
./venv/Scripts/python.exe test_collision_risk.py
```
**Result:** Exit code 0, 16/16 tests passed

```bash
./venv/Scripts/python.exe test_depth_classifier.py
```
**Result:** Exit code 0, 7/7 tests passed

```bash
./venv/Scripts/python.exe test_navigation_engine.py
```
**Result:** Exit code 0, 13/13 tests passed

```bash
./venv/Scripts/python.exe test_api_server.py
```
**Result:** Exit code 0, 1/1 test passed

```bash
./venv/Scripts/python.exe test_api_contract.py
```
**Result:** Exit code 0, 6/6 tests passed

```bash
./venv/Scripts/python.exe -m py_compile api_server.py perception_module.py midas_depth.py depth_classifier.py collision_risk.py navigation_engine.py
```
**Result:** Exit code 0 (no syntax errors)

### Flutter Tests

**Status:** Flutter CLI not found in environment

**Commands not executed:**
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

**Reason:** Flutter not installed in common locations on this machine

---

## Flutter Analysis, Test, and APK Build Status

### Status: NOT EXECUTED

**Reason:** Flutter CLI not available in current environment

**User must run manually:**
```bash
cd C:\Users\singa_x3eldes\AI-Navigation-Assistant\frontend\navigation_app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

**Expected results based on code inspection:**
- ✅ `flutter pub get` should succeed (pubspec.yaml is valid)
- ⚠️ `flutter analyze` may have issues with new test files (need to verify)
- ⚠️ `flutter test` may have issues with new test files (need to verify)
- ⚠️ `flutter build apk` may have dependency issues (speech_to_text mentioned in previous conversation)

---

## Unresolved Issues

### 1. Flutter CLI Unavailable
- **Issue:** Flutter not found in environment
- **Impact:** Cannot verify Flutter build, analyze, or test
- **Action Required:** User must run Flutter commands manually
- **Priority:** HIGH

### 2. speech_to_text Dependency
- **Issue:** Previous conversation mentioned Android NDK mismatch and Registrar API errors with speech_to_text 6.6.2
- **Current State:** pubspec.yaml has speech_to_text removed (not listed in dependencies)
- **Verification:** MainActivity.kt uses native Android SpeechRecognizer (not speech_to_text package)
- **Impact:** Native speech recognition is used, not the speech_to_text package
- **Status:** ✅ RESOLVED - Using native implementation instead

### 3. Physical Device Testing
- **Issue:** Cannot test on physical phone from this environment
- **Impact:** Cannot verify real-device behavior
- **Action Required:** User must perform manual tests on phone
- **Priority:** HIGH

---

## Manual Test Checklist for Android Phone

### Prerequisites
1. ✅ PC and phone on same Wi-Fi network
2. ✅ Backend running on PC
3. ✅ App installed on phone (APK built by user)
4. ✅ Phone has camera and microphone permissions

### Test 1: Backend Health Check
1. **On PC:** Run `cd backend && venv\Scripts\python.exe api_server.py`
2. **On PC:** Get LAN IP with `ipconfig` (e.g., 192.168.1.50)
3. **On Phone:** Open browser and navigate to `http://192.168.1.50:8000/health`
4. **Expected:** Returns `{"status": "ok"}`
5. **If fails:** Check firewall, Wi-Fi network, backend running

### Test 2: App Launch and Welcome Message
1. **Launch app** on phone
2. **Expected:** TTS speaks "AI Navigation Assistant is ready. Say start assistance to begin."
3. **Expected:** Status shows "Assistant Ready"
4. **Expected:** Navigation message shows "Waiting to start..."
5. **If no TTS:** Check volume, TTS initialization

### Test 3: Voice Command - Start Assistance
1. **Speak:** "start assistance"
2. **Expected:** TTS speaks "Assistance started."
3. **Expected:** Status changes to "Assistant Running"
4. **Expected:** Navigation message shows "Connecting to navigation backend..."
5. **Expected:** After connection: Camera indicator active, navigation messages update
6. **If fails:** Check microphone permission, speech recognition availability

### Test 4: Touch Button - Start Assistance
1. **Tap:** "START ASSISTANCE" button
2. **Expected:** Same as Test 3 (alternative to voice)
3. **If fails:** Check button state, touch targets

### Test 5: Camera Detection and Navigation
1. **Point rear camera** at objects (person, chair, wall)
2. **Wait 2 seconds** for first capture
3. **Expected:** Navigation message updates with action and reason
4. **Expected:** TTS speaks navigation (e.g., "Continue. No detected obstacles.")
5. **Expected:** Actions include: CONTINUE, STOP, MOVE LEFT, MOVE RIGHT, CAUTION / SLOW DOWN
6. **If no updates:** Check backend connection, camera permission, camera selection

### Test 6: Voice Command - Stop Assistance
1. **Speak:** "stop assistance"
2. **Expected:** TTS speaks "Assistance stopped."
3. **Expected:** Status changes to "Assistant Stopped"
4. **Expected:** Camera stops
5. **Expected:** Navigation message: "Assistance stopped. Waiting to start..."
6. **If fails:** Check speech recognition, state management

### Test 7: Touch Button - Stop Assistance
1. **Tap:** "STOP ASSISTANCE" button
2. **Expected:** Same as Test 6 (alternative to voice)
3. **If fails:** Check button state

### Test 8: Voice Command - Help
1. **Speak:** "help"
2. **Expected:** TTS speaks "Available commands: start assistance, stop assistance, help."
3. **If fails:** Check command recognition

### Test 9: TTS Self-Recognition Prevention
1. **Start assistance** (ensure working)
2. **Listen to TTS output** (e.g., "Continue. No detected obstacles.")
3. **Expected:** Speech recognizer does NOT interpret TTS as command
4. **Expected:** Assistant does not stop or start due to TTS
5. **If fails:** Check isTtsSpeaking coordination in MainActivity.kt

### Test 10: Backend Disconnection
1. **Start assistance** (ensure working)
2. **Stop backend** on PC (Ctrl+C in terminal)
3. **Wait 10 seconds** for next camera capture
4. **Expected:** Navigation message shows error (e.g., "Navigation backend error")
5. **Expected:** App does not crash
6. **Expected:** Can still stop assistance
7. **If crashes:** Check error handling in backend_service.dart

### Test 11: Backend Reconnection
1. **Restart backend** on PC: `python api_server.py`
2. **Stop and restart assistance** on phone
3. **Expected:** Connection succeeds
4. **Expected:** Camera capture resumes
5. **Expected:** Navigation messages update
6. **If fails:** Check backend restart, network connectivity

### Test 12: Microphone Permission Denial
1. **Uninstall app** or clear app data
2. **Reinstall app**
3. **Launch app**
4. **Deny microphone permission** when prompted
5. **Expected:** Navigation message: "Speech recognition unavailable. Use touch controls."
6. **Expected:** Touch buttons still work
7. **Expected:** Can start/stop assistance with buttons
8. **If fails:** Check permission handling, fallback UI

### Test 13: Camera Permission Denial
1. **Uninstall app** or clear app data
2. **Reinstall app**
3. **Launch app**
4. **Tap START ASSISTANCE**
5. **Deny camera permission** when prompted
6. **Expected:** Navigation message: "Camera unavailable. Check permissions."
7. **Expected:** TTS speaks "Camera unavailable. Check permissions."
8. **Expected:** Assistant stops automatically
9. **Expected:** Can retry after granting permission
10. **If fails:** Check permission request logic, error handling

### Test 14: Network Configuration Verification
1. **Check Wi-Fi** on phone and PC are same network
2. **Verify backend IP** matches phone's reachable network
3. **Test health endpoint** in phone browser: `http://<PC_IP>:8000/health`
4. **Expected:** Returns `{"status": "ok"}`
5. **If fails:** Check network_security_config.xml, usesCleartextTraffic

### Test 15: Rear Camera Selection
1. **Start assistance**
2. **Point phone** at yourself (front facing)
3. **Observe:** Should not detect your face as obstacle (using rear camera)
4. **Turn phone around** (rear facing)
5. **Observe:** Should detect objects in front of phone
6. **If wrong camera:** Check camera_service.dart rear camera selection

---

## Test Classification

### Automated Tests (Executed ✅)

**Backend Python Tests:**
- test_collision_risk.py: 16/16 PASSED
- test_depth_classifier.py: 7/7 PASSED
- test_navigation_engine.py: 13/13 PASSED
- test_api_server.py: 1/1 PASSED
- test_api_contract.py: 6/6 PASSED (NEW)
- test_midas_polarity.py: 3/3 PASSED (NEW)
- Python compilation: PASSED

**Total Automated Backend Tests: 46/46 PASSED**

**Flutter Tests:**
- test_backend_service.dart: 12 tests (created, awaiting execution)
- test_voice_commands.dart: 14 tests (created, awaiting execution)
- flutter pub get: NOT EXECUTED (Flutter CLI unavailable)
- flutter analyze: NOT EXECUTED (Flutter CLI unavailable)
- flutter test: NOT EXECUTED (Flutter CLI unavailable)
- flutter build apk: NOT EXECUTED (Flutter CLI unavailable)

### API Tests (Executed ✅)

**test_api_contract.py:**
- Response structure validation: PASSED
- Empty detections handling: PASSED
- Unknown depth handling: PASSED
- Enum conversion: PASSED
- Failure safety (never false CONTINUE): PASSED
- JSON serialization: PASSED

**Test with Real Image:**
- NOT EXECUTED (requires physical device and camera)
- User must perform manually

### Physical Device Tests (Require Phone)

**15 manual tests listed above:**
- All require physical Android phone
- All require backend running on PC
- All require same Wi-Fi network
- User must perform manually

---

## Conclusion

### What Was Verified ✅

1. **Depth Classification:** Correctly implements inverse depth (higher values = closer)
2. **API Contract:** Backend response matches Flutter parsing logic
3. **Failure Safety:** Failures never silently become CONTINUE
4. **Android Configuration:** Network security, permissions, camera selection correct
5. **TTS Coordination:** Self-recognition prevention implemented
6. **Backend Tests:** 46/46 automated tests passing
7. **Python Compilation:** No syntax errors

### What Requires User Action ⚠️

1. **Flutter Build:** User must run flutter commands (CLI unavailable)
2. **Physical Device Testing:** User must perform 15 manual tests on phone
3. **Real Image API Test:** User must test with actual camera image

### No Regressions Found

All changes from the Integration Fixes Report have been verified to be correctly implemented. No additional bugs were discovered during this independent verification.

### Next Steps for User

1. Run Flutter commands manually to verify build
2. Build and install APK on phone
3. Perform 15 manual device tests
4. Report any failures for further investigation
