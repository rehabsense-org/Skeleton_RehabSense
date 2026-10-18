import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_rehabsense/services/pose_coordinate_transformer.dart';

void main() {
  group('PoseCoordinateTransformer', () {
    test(
      'Portrait Back Camera: center maps to center without horizontal rotation',
      () {
        // Raw camera frame: 1280 wide x 720 high (landscape)
        // Screen: 1080 wide x 2400 high (portrait)
        // Sensor rotation: 90 deg, rear camera (no mirror)
        final transformer = PoseCoordinateTransformer(
          imageSize: const Size(1280, 720),
          previewSize: const Size(1080, 2400),
          sensorOrientation: 90,
          isFrontCamera: false,
        );

        // Rotated upright frame dimensions: 720 x 1280
        expect(transformer.rotatedImageSize.width, 720);
        expect(transformer.rotatedImageSize.height, 1280);

        // Center point in ML Kit upright frame: (360, 640)
        final center = transformer.transformPoint(360, 640);

        // Center point must map exactly to center of preview screen (540, 1200)
        expect(center.dx, closeTo(540.0, 0.001));
        expect(center.dy, closeTo(1200.0, 0.001));
      },
    );

    test(
      'Body Posture: standing person remains vertical (head above feet)',
      () {
        final transformer = PoseCoordinateTransformer(
          imageSize: const Size(1280, 720),
          previewSize: const Size(1080, 2400),
          sensorOrientation: 90,
          isFrontCamera: false,
        );

        // Standing person in ML Kit upright frame:
        // Head at x=360, y=200
        // Feet at x=360, y=1100
        final head = transformer.transformPoint(360, 200);
        final feet = transformer.transformPoint(360, 1100);

        // Both are horizontally centered at x = 540
        expect(head.dx, closeTo(540.0, 0.001));
        expect(feet.dx, closeTo(540.0, 0.001));

        // Head must be vertically above feet (head.dy < feet.dy)
        expect(head.dy, lessThan(feet.dy));
        expect(head.dy, closeTo(375.0, 0.001));
        expect(feet.dy, closeTo(2062.5, 0.001));
      },
    );

    test(
      'Body Posture: lying down person remains horizontal (head left, feet right)',
      () {
        final transformer = PoseCoordinateTransformer(
          imageSize: const Size(1280, 720),
          previewSize: const Size(1080, 2400),
          sensorOrientation: 90,
          isFrontCamera: false,
        );

        // Lying down person across the frame at mid-height y=640
        // Head on left at x=150, feet on right at x=570
        final head = transformer.transformPoint(150, 640);
        final feet = transformer.transformPoint(570, 640);

        // Both are at screen mid-height y = 1200
        expect(head.dy, closeTo(1200.0, 0.001));
        expect(feet.dy, closeTo(1200.0, 0.001));

        // Head is to the left of feet on screen (head.dx < feet.dx)
        expect(head.dx, lessThan(feet.dx));
      },
    );

    test('Portrait Front Camera: center maps to center with mirror', () {
      final transformer = PoseCoordinateTransformer(
        imageSize: const Size(1280, 720),
        previewSize: const Size(1080, 2400),
        sensorOrientation: 270,
        isFrontCamera: true,
      );

      expect(transformer.rotatedImageSize.width, 720);
      expect(transformer.rotatedImageSize.height, 1280);

      final center = transformer.transformPoint(360, 640);
      expect(center.dx, closeTo(540.0, 0.001));
      expect(center.dy, closeTo(1200.0, 0.001));
    });

    test('Front-camera horizontal mirroring flips X axis', () {
      final rear = PoseCoordinateTransformer(
        imageSize: const Size(1280, 720),
        previewSize: const Size(720, 1280),
        sensorOrientation: 90,
        isFrontCamera: false,
      );

      final front = PoseCoordinateTransformer(
        imageSize: const Size(1280, 720),
        previewSize: const Size(720, 1280),
        sensorOrientation: 90,
        isFrontCamera: true,
      );

      // Point at raw (x=100, y=100)
      final pRear = rear.transformPoint(100, 100);
      final pFront = front.transformPoint(100, 100);

      // Mirroring across width 720 means pFront.dx + pRear.dx == 720
      expect(pRear.dx + pFront.dx, closeTo(720.0, 0.001));
      // Y-axis is unchanged by horizontal mirroring
      expect(pRear.dy, closeTo(pFront.dy, 0.001));
    });

    test('BoxFit.cover scales uniformly and centers cropped edges', () {
      final exactMatch = PoseCoordinateTransformer(
        imageSize: const Size(1280, 720),
        previewSize: const Size(1080, 1920),
        sensorOrientation: 90,
        isFrontCamera: false,
      );
      expect(exactMatch.scale, closeTo(1.5, 0.001));
      expect(exactMatch.offsetX, closeTo(0.0, 0.001));
      expect(exactMatch.offsetY, closeTo(0.0, 0.001));

      final tallerScreen = PoseCoordinateTransformer(
        imageSize: const Size(1280, 720),
        previewSize: const Size(1080, 2400),
        sensorOrientation: 90,
        isFrontCamera: false,
      );
      expect(tallerScreen.scale, closeTo(1.875, 0.001));
      expect(tallerScreen.offsetX, closeTo(-135.0, 0.001));
      expect(tallerScreen.offsetY, closeTo(0.0, 0.001));
    });
  });
}
