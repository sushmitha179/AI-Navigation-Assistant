import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  Timer? _captureTimer;
  bool _isRunning = false;
  bool _isStarting = false;
  bool _captureInProgress = false;
  int _generation = 0;
  Completer<void>? _captureCompleted;

  Future<bool> start({
    required Future<void> Function(Uint8List frame) onFrame,
    Duration interval = const Duration(seconds: 2),
  }) async {
    if (_isRunning) return true;
    if (_isStarting) return false;
    _isStarting = true;
    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      if (generation != _generation) return false;
      if (cameras.isEmpty) {
        throw Exception('No cameras available on device');
      }

      // Prefer rear-facing camera for navigation
      final rearCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        rearCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (generation != _generation || _controller != controller) {
        await controller.dispose();
        return false;
      }
      _isRunning = true;
      await _capture(onFrame, generation);
      if (generation != _generation || !_isRunning) return false;
      _captureTimer = Timer.periodic(
        interval,
        (_) => _capture(onFrame, generation),
      );
      return true;
    } catch (e) {
      print('Camera initialization error: $e');
      if (generation == _generation) {
        await stop();
      }
      return false;
    } finally {
      if (generation == _generation) _isStarting = false;
    }
  }

  Future<void> _capture(
    Future<void> Function(Uint8List frame) onFrame,
    int generation,
  ) async {
    final controller = _controller;
    if (generation != _generation ||
        !_isRunning ||
        _captureInProgress ||
        controller == null ||
        controller.value.isTakingPicture ||
        !controller.value.isInitialized) {
      return;
    }
    final capture = _beginCapture();
    try {
      final file = await controller.takePicture();
      final frame = await file.readAsBytes();
      if (generation == _generation && _isRunning) await onFrame(frame);
    } catch (e) {
      print('Camera capture error: $e');
    } finally {
      _finishCapture(capture);
    }
  }

  Future<Uint8List?> captureSnapshot({
    Duration waitTimeout = const Duration(seconds: 8),
  }) async {
    if (!_isRunning) return null;
    final generation = _generation;
    final deadline = DateTime.now().add(waitTimeout);
    while (_captureInProgress && generation == _generation) {
      final activeCapture = _captureCompleted;
      if (activeCapture == null) return null;
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return null;
      try {
        await activeCapture.future.timeout(remaining);
      } on TimeoutException {
        return null;
      }
    }

    final controller = _controller;
    if (generation != _generation ||
        !_isRunning ||
        controller == null ||
        !controller.value.isInitialized) {
      return null;
    }

    final capture = _beginCapture();
    try {
      final file = await controller.takePicture();
      final frame = await file.readAsBytes();
      return generation == _generation && _isRunning ? frame : null;
    } catch (error) {
      print('Camera snapshot error: $error');
      return null;
    } finally {
      _finishCapture(capture);
    }
  }

  Completer<void> _beginCapture() {
    final capture = Completer<void>();
    _captureInProgress = true;
    _captureCompleted = capture;
    return capture;
  }

  void _finishCapture(Completer<void> capture) {
    if (identical(_captureCompleted, capture)) {
      _captureCompleted = null;
      _captureInProgress = false;
    }
    if (!capture.isCompleted) capture.complete();
  }

  Future<bool> stop() async {
    _generation++;
    _captureTimer?.cancel();
    _captureTimer = null;
    _isRunning = false;
    _isStarting = false;
    _captureInProgress = false;
    final activeCapture = _captureCompleted;
    _captureCompleted = null;
    if (activeCapture != null && !activeCapture.isCompleted) {
      activeCapture.complete();
    }
    try {
      await _controller?.dispose();
    } catch (e) {
      print('Camera disposal error: $e');
    }
    _controller = null;
    return true;
  }

  bool isRunning() => _isRunning;

  String getStatus() => _isRunning ? 'Camera running' : 'Camera stopped';
}
