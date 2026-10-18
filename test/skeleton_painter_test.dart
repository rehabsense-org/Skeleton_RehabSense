import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_rehabsense/models/pose_landmark.dart';
import 'package:skeleton_rehabsense/painters/skeleton_painter.dart';

void main() {
  group('SkeletonConnections & Topology', () {
    test('BlazePose topology has 33 distinct landmark constants', () {
      final types = [
        LandmarkType.nose,
        LandmarkType.leftEyeInner,
        LandmarkType.leftEye,
        LandmarkType.leftEyeOuter,
        LandmarkType.rightEyeInner,
        LandmarkType.rightEye,
        LandmarkType.rightEyeOuter,
        LandmarkType.leftEar,
        LandmarkType.rightEar,
        LandmarkType.leftMouth,
        LandmarkType.rightMouth,
        LandmarkType.leftShoulder,
        LandmarkType.rightShoulder,
        LandmarkType.leftElbow,
        LandmarkType.rightElbow,
        LandmarkType.leftWrist,
        LandmarkType.rightWrist,
        LandmarkType.leftPinky,
        LandmarkType.rightPinky,
        LandmarkType.leftIndex,
        LandmarkType.rightIndex,
        LandmarkType.leftThumb,
        LandmarkType.rightThumb,
        LandmarkType.leftHip,
        LandmarkType.rightHip,
        LandmarkType.leftKnee,
        LandmarkType.rightKnee,
        LandmarkType.leftAnkle,
        LandmarkType.rightAnkle,
        LandmarkType.leftHeel,
        LandmarkType.rightHeel,
        LandmarkType.leftFootIndex,
        LandmarkType.rightFootIndex,
      ];

      expect(types.length, 33);
      expect(types.toSet().length, 33);
      for (int i = 0; i < 33; i++) {
        expect(types.contains(i), isTrue);
      }
    });

    test('Connections only reference valid landmark indices (0-32)', () {
      for (final conn in SkeletonConnections.all) {
        expect(conn.length, 2);
        expect(conn[0], inInclusiveRange(0, 32));
        expect(conn[1], inInclusiveRange(0, 32));
      }
    });

    test('Left and right side connections are symmetric', () {
      expect(
        SkeletonConnections.leftSide.length,
        SkeletonConnections.rightSide.length,
      );
    });
  });

  group('SkeletonPainter', () {
    test('shouldRepaint returns true when landmarks instance changes', () {
      final lm1 = [
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(10, 10),
          z: 0.0,
          confidence: 0.9,
        ),
      ];
      final lm2 = [
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(20, 20),
          z: 0.0,
          confidence: 0.9,
        ),
      ];

      final painter1 = SkeletonPainter(landmarks: lm1);
      final painter2 = SkeletonPainter(landmarks: lm2);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test(
      'shouldRepaint returns false when landmarks instance is identical',
      () {
        final lm = [
          const PoseLandmarkData(
            type: LandmarkType.nose,
            imagePosition: Offset(10, 10),
            z: 0.0,
            confidence: 0.9,
          ),
        ];

        final painter1 = SkeletonPainter(landmarks: lm);
        final painter2 = SkeletonPainter(landmarks: lm);

        expect(painter1.shouldRepaint(painter2), isFalse);
      },
    );

    test('Paints without throwing error when empty', () {
      final painter = SkeletonPainter(landmarks: []);
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(100, 100)),
        returnsNormally,
      );
    });

    test('Paints landmarks above confidence threshold', () {
      final landmarks = [
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(50, 50),
          z: 0.0,
          confidence: 0.9,
        ),
        const PoseLandmarkData(
          type: LandmarkType.leftShoulder,
          imagePosition: Offset(40, 70),
          z: 0.0,
          confidence: 0.8,
        ),
        const PoseLandmarkData(
          type: LandmarkType.rightShoulder,
          imagePosition: Offset(60, 70),
          z: 0.0,
          confidence: 0.3, // Below threshold
        ),
      ];

      final painter = SkeletonPainter(
        landmarks: landmarks,
        confidenceThreshold: 0.5,
      );
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(100, 100)),
        returnsNormally,
      );
    });
  });
}
