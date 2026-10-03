package com.example.navigation_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "VoiceRecognition"
        private const val END_OF_SPEECH_TIMEOUT_MS = 3000L
    }

    private val channelName = "voice_recognition"
    private val audioPermissionRequestCode = 1001
    private val cameraPermissionRequestCode = 1002
    private var speechRecognizer: SpeechRecognizer? = null
    private var channel: MethodChannel? = null
    private var isTtsSpeaking = false
    private var recognitionActive = false
    private var shouldListen = false
    private var requestedRecognitionLanguage = "en-US"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var endOfSpeechWatchdog: Runnable? = null
    private var activeHapticPriority: String? = null
    private var activeHighHapticUntil = 0L
    private var hapticGeneration = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSelectedLanguage" -> {
                    val saved = getSharedPreferences("navigation_settings", MODE_PRIVATE)
                        .getString("assistant_language", null)
                    result.success(saved)
                }
                "setSelectedLanguage" -> {
                    val code = call.argument<String>("code")
                    if (code !in setOf("en", "te", "hi")) {
                        result.success(false)
                    } else {
                        getSharedPreferences("navigation_settings", MODE_PRIVATE)
                            .edit()
                            .putString("assistant_language", code)
                            .apply()
                        result.success(true)
                    }
                }
                "initialize" -> result.success(initializeSpeech())
                "startListening" -> {
                    val args = call.arguments as? Map<*, *>
                    requestedRecognitionLanguage =
                        args?.get("languageTag") as? String ?: "en-US"
                    result.success(startListening())
                }
                "stopListening" -> {
                    shouldListen = false
                    destroyRecognizer()
                    reportState("ready")
                    result.success(true)
                }
                "setTtsSpeaking" -> {
                    isTtsSpeaking = call.arguments == true
                    if (isTtsSpeaking) {
                        destroyRecognizer()
                        reportState("speaking")
                    }
                    result.success(true)
                }
                "triggerHaptic" -> result.success(triggerHaptic(call.arguments))
                "stopHaptics" -> {
                    val force = (call.arguments as? Map<*, *>)?.get("force") == true
                    result.success(stopHaptics(force))
                }
                "requestCameraPermission" -> {
                    requestCameraPermission()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initializeSpeech(): Boolean {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            reportError("unavailable", "Speech recognition is not available on this device")
            return false
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.RECORD_AUDIO),
                audioPermissionRequestCode
            )
            reportState("permission_required")
            return false
        }
        if (speechRecognizer != null) return true
        val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer = recognizer
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                if (!isCurrent(recognizer)) return
                val match = if (!isTtsSpeaking) {
                    results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                } else {
                    null
                }
                finishSession(recognizer)
                Log.d(TAG, "onResults recognized text=${match ?: "<empty>"}")
                if (match.isNullOrBlank()) {
                    reportError("no_match", "No speech was recognized")
                } else {
                    channel?.invokeMethod("onRecognitionResult", match)
                }
            }
            override fun onError(error: Int) {
                if (!isCurrent(recognizer)) return
                finishSession(recognizer)
                Log.w(TAG, "onError received; code=$error")
                if (error == SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS) {
                    shouldListen = false
                    reportError("permission_denied", "Microphone permission denied")
                } else if (requestedRecognitionLanguage != "en-US" &&
                    (error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
                        error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE)) {
                    requestedRecognitionLanguage = "en-US"
                    reportError(
                        "language_fallback",
                        "Selected speech-recognition language unavailable; English will be used",
                    )
                } else {
                    reportError("$error", recognitionErrorMessage(error))
                }
            }
            override fun onReadyForSpeech(params: Bundle?) {
                if (isCurrent(recognizer)) reportState("listening")
            }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {
                if (!isCurrent(recognizer)) return
                Log.d(TAG, "onEndOfSpeech received; awaiting final results")
                reportState("processing")
                endOfSpeechWatchdog?.let(mainHandler::removeCallbacks)
                val watchdog = Runnable {
                    if (isCurrent(recognizer)) {
                        Log.w(TAG, "No final results after end-of-speech; recovering session")
                        finishSession(recognizer)
                        reportError("end_of_speech_timeout", "Speech results timed out; restarting")
                    }
                }
                endOfSpeechWatchdog = watchdog
                mainHandler.postDelayed(watchdog, END_OF_SPEECH_TIMEOUT_MS)
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val partial = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                if (!partial.isNullOrBlank()) {
                    Log.d(TAG, "onPartialResults recognized text=$partial")
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        return true
    }

    private fun startListening(): Boolean {
        shouldListen = true
        if (isTtsSpeaking || recognitionActive) return recognitionActive
        if (speechRecognizer == null && !initializeSpeech()) return false
        if (speechRecognizer == null) return false
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, requestedRecognitionLanguage)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1000L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1000L)
        }
        return try {
            speechRecognizer?.startListening(intent)
            recognitionActive = true
            Log.d(TAG, "Recognition session started")
            true
        } catch (error: RuntimeException) {
            Log.e(TAG, "Could not start recognition session", error)
            destroyRecognizer()
            reportError("start_failed", error.message ?: "Could not start speech recognition")
            false
        }
    }

    private fun isCurrent(recognizer: SpeechRecognizer): Boolean {
        return speechRecognizer === recognizer && recognitionActive
    }

    private fun finishSession(recognizer: SpeechRecognizer) {
        if (speechRecognizer !== recognizer) return
        endOfSpeechWatchdog?.let(mainHandler::removeCallbacks)
        endOfSpeechWatchdog = null
        recognitionActive = false
        speechRecognizer = null
        recognizer.destroy()
    }

    private fun destroyRecognizer() {
        endOfSpeechWatchdog?.let(mainHandler::removeCallbacks)
        endOfSpeechWatchdog = null
        val recognizer = speechRecognizer
        speechRecognizer = null
        recognitionActive = false
        recognizer?.cancel()
        recognizer?.destroy()
    }

    private fun reportState(state: String) {
        channel?.invokeMethod("onRecognitionState", state)
    }

    private fun reportError(code: String, message: String) {
        Log.w(TAG, "Reporting recognition error to Flutter; code=$code message=$message")
        channel?.invokeMethod("onRecognitionError", mapOf("code" to code, "message" to message))
    }

    private fun deviceVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            (getSystemService(VIBRATOR_SERVICE) as? Vibrator)
        }
    }

    private fun triggerHaptic(arguments: Any?): Boolean {
        val values = arguments as? Map<*, *> ?: return false
        val priority = values["priority"] as? String ?: return false
        val signature = values["signature"] as? String ?: return false
        if (priority != "high" && priority != "medium") return false

        val vibrator = deviceVibrator()
        if (vibrator?.hasVibrator() != true) {
            Log.i(TAG, "Haptic alert ignored: no vibrator available")
            return false
        }

        val now = SystemClock.elapsedRealtime()
        if (priority == "medium" && activeHapticPriority == "high" &&
            now < activeHighHapticUntil) {
            Log.d(TAG, "Medium haptic ignored while HIGH pattern is active")
            return false
        }

        val timings = if (priority == "high") {
            longArrayOf(0, 220, 110, 220, 110, 220, 300, 220, 110, 220, 110, 220)
        } else {
            longArrayOf(0, 100, 120, 100)
        }
        val amplitudes = if (priority == "high") {
            intArrayOf(0, 255, 0, 255, 0, 255, 0, 255, 0, 255, 0, 255)
        } else {
            intArrayOf(0, 128, 0, 128)
        }
        val duration = timings.sum()
        val generation = ++hapticGeneration
        try {
            vibrator.cancel()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = if (vibrator.hasAmplitudeControl()) {
                    VibrationEffect.createWaveform(timings, amplitudes, -1)
                } else {
                    VibrationEffect.createWaveform(timings, -1)
                }
                vibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(timings, -1)
            }
            activeHapticPriority = priority
            activeHighHapticUntil = if (priority == "high") now + duration else 0L
            Log.d(TAG, "Started $priority haptic alert: $signature")
            mainHandler.postDelayed({
                if (hapticGeneration == generation) {
                    activeHapticPriority = null
                    activeHighHapticUntil = 0L
                }
            }, duration)
            return true
        } catch (error: RuntimeException) {
            activeHapticPriority = null
            activeHighHapticUntil = 0L
            Log.w(TAG, "Could not start haptic alert", error)
            return false
        }
    }

    private fun stopHaptics(force: Boolean): Boolean {
        if (!force && activeHapticPriority == "high" &&
            SystemClock.elapsedRealtime() < activeHighHapticUntil) {
            return false
        }
        hapticGeneration++
        activeHapticPriority = null
        activeHighHapticUntil = 0L
        return try {
            deviceVibrator()?.cancel()
            true
        } catch (error: RuntimeException) {
            Log.w(TAG, "Could not stop haptic alert", error)
            false
        }
    }

    private fun recognitionErrorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Audio recording error; restarting speech recognition"
            SpeechRecognizer.ERROR_CLIENT -> "Speech recognition client error; restarting"
            SpeechRecognizer.ERROR_NETWORK -> "Network error; restarting speech recognition"
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognition timed out; restarting"
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech was recognized"
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognizer was busy; restarting"
            SpeechRecognizer.ERROR_SERVER -> "Speech recognition service error; restarting"
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "No speech detected; restarting"
            else -> "Speech recognition error ($error); restarting"
        }
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            audioPermissionRequestCode -> {
                val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                if (granted) {
                    initializeSpeech()
                }
                channel?.invokeMethod("onPermissionResult", granted)
                if (!granted) reportError("permission_denied", "Microphone permission denied")
            }
            cameraPermissionRequestCode -> {
                // Camera permission result handled by Flutter permission_handler
            }
        }
    }

    override fun onDestroy() {
        shouldListen = false
        destroyRecognizer()
        stopHaptics(force = true)
        super.onDestroy()
    }
}
