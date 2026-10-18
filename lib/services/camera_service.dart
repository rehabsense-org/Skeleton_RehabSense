import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service that manages camera initialization, image streaming, and cleanup.
///
/// Provides a clean interface for the UI layer to access camera preview
/// and register a frame callback for pose detection.
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isStreaming = false;

  /// The active camera controller.
  CameraController? get controller => _controller;

  /// Whether the camera is initialized and ready.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Current camera description.
  CameraDescription? get currentCamera =>
      _cameras.isNotEmpty ? _cameras[_currentCameraIndex] : null;

  /// Whether a front camera is currently selected.
  bool get isFrontCamera =>
      currentCamera?.lensDirection == CameraLensDirection.front;

  /// Whether multiple cameras are available for switching.
  bool get canSwitchCamera => _cameras.length > 1;

  /// Callback invoked on each camera frame (for pose detection).
  void Function(CameraImage image)? onFrameAvailable;

  /// Initialize the camera system.
  ///
  /// Discovers available cameras and initializes the first back-facing
  /// camera (or the first available camera).
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw CameraException('noCameras', 'No cameras available on device');
    }

    // Prefer back camera initially.
    _currentCameraIndex = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (_currentCameraIndex < 0) _currentCameraIndex = 0;

    await _initController();
  }

  /// Initialize or re-initialize the camera controller.
  Future<void> _initController() async {
    // Stop any previous stream and dispose.
    await _stopStream();
    await _controller?.dispose();

    final camera = _cameras[_currentCameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // Balance between quality and inference speed.
      enableAudio: false,
      imageFormatGroup:
          ImageFormatGroup.nv21, // Required for ML Kit on Android.
    );

    await _controller!.initialize();
  }

  /// Start streaming camera frames to [onFrameAvailable].
  Future<void> startStream() async {
    if (_controller == null || !isInitialized || _isStreaming) return;
    _isStreaming = true;

    await _controller!.startImageStream((CameraImage image) {
      onFrameAvailable?.call(image);
    });
  }

  /// Stop the camera image stream.
  Future<void> _stopStream() async {
    if (!_isStreaming || _controller == null) return;
    try {
      await _controller!.stopImageStream();
    } catch (e) {
      debugPrint('Error stopping image stream: $e');
    }
    _isStreaming = false;
  }

  /// Switch between front and back camera.
  ///
  /// Returns true if the switch was successful.
  Future<bool> switchCamera() async {
    if (_cameras.length < 2) return false;

    await _stopStream();

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await _initController();
    await startStream();

    return true;
  }

  /// Dispose of all camera resources.
  Future<void> dispose() async {
    await _stopStream();
    await _controller?.dispose();
    _controller = null;
  }
}
