import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/pose_landmark.dart';

/// Service that wraps the Google ML Kit Pose Detector.
///





/// Handles initialization, inference on camera frames, and cleanup.
/// Returns typed [PoseLandmarkData] from raw ML Kit results.
class PoseDetectionService {
  PoseDetector? _detector;
  bool _isBusy = false;

  /// Whether inference is currently running.
  bool get isBusy => _isBusy;

  /// Initialize the pose detector.
  void initialize() {
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  /// Process a single camera frame and return detected landmarks.
  ///
  /// Returns null if the detector is busy, not initialized, or if no
  /// person was detected. Drops stale frames by checking [_isBusy].
  Future<List<PoseLandmarkData>?> processFrame(
    CameraImage image,
    CameraDescription camera,
  ) async {
    if (_detector == null || _isBusy) return null;
    _isBusy = true;

    try {
      final InputImage? inputImage = _convertCameraImage(image, camera);
      if (inputImage == null) return null;

      final List<Pose> poses = await _detector!.processImage(inputImage);

      if (poses.isEmpty) return null;

      // Track the first (primary) detected person.
      final Pose pose = poses.first;
      return _convertLandmarks(pose);
    } catch (e) {
      // Swallow inference errors to prevent crash loops; log for debugging.
      // In production you'd use a proper logger.
      return null;
    } finally {
      _isBusy = false;
    }
  }

  /// Convert ML Kit [Pose] to our typed [PoseLandmarkData] list.
  List<PoseLandmarkData> _convertLandmarks(Pose pose) {
    final List<PoseLandmarkData> landmarks = [];
    for (final entry in pose.landmarks.entries) {
      final PoseLandmark lm = entry.value;
      landmarks.add(
        PoseLandmarkData(
          type: lm.type.index,
          imagePosition: Offset(lm.x, lm.y),
          z: lm.z,
          confidence: lm.likelihood,
        ),
      );
    }
    return landmarks;
  }

  /// Convert a [CameraImage] to an ML Kit [InputImage].
  ///
  /// Android CameraX provides YUV_420_888 with NV21 compatible planes.
  InputImage? _convertCameraImage(CameraImage image, CameraDescription camera) {
    final int sensorOrientation = camera.sensorOrientation;

    // Determine the input image rotation from sensor orientation.
    final InputImageRotation rotation = _rotationFromSensorOrientation(
      sensorOrientation,
    );

    // On Android, CameraX delivers NV21-compatible data.
    // Use nv21 format with the first plane's bytes.
    final InputImageFormat format = InputImageFormat.nv21;

    // Concatenate all planes into a single byte buffer (NV21).
    final allBytes = _concatenatePlanes(image.planes);

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: allBytes, metadata: metadata);
  }

  /// Concatenate camera image planes into a single Uint8List.
  /// For NV21 on Android, all plane bytes are concatenated.
  static Uint8List _concatenatePlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  /// Map sensor orientation degrees to [InputImageRotation].
  static InputImageRotation _rotationFromSensorOrientation(int orientation) {
    switch (orientation) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  /// Dispose of the pose detector and release native resources.
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
