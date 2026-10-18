import 'dart:ui';

import 'package:camera/camera.dart';

/// Transforms landmark coordinates from ML Kit inference space to screen
/// preview widget space.
///
/// Google ML Kit on Android (when passed rotation90deg or rotation270deg)
/// performs internal rotation and outputs coordinates directly in the upright
/// rotated frame (x in [0, rotatedWidth], y in [0, rotatedHeight]).
///
/// This transformer accurately maps these coordinates onto the screen
/// taking into account:
/// - Front-camera horizontal mirroring
/// - Camera sensor orientation
/// - Uniform BoxFit.cover scaling
/// - Centering offsets for cropped margins
class PoseCoordinateTransformer {
  /// The raw image buffer size (e.g. 1280x720) reported by CameraImage.
  final Size imageSize;

  /// The size of the preview canvas / screen widget.
  final Size previewSize;

  /// The rotation of the camera sensor in degrees (0, 90, 180, 270).
  final int sensorOrientation;

  /// Whether this is the front-facing camera (requires horizontal mirroring).
  final bool isFrontCamera;

  /// Effective image dimensions after sensor rotation (e.g. 720x1280 for portrait).
  late final Size rotatedImageSize;

  /// Uniform scale factor applied under BoxFit.cover.
  late final double scale;

  /// Horizontal translation offset (for centering / cropping).
  late final double offsetX;

  /// Vertical translation offset (for centering / cropping).
  late final double offsetY;

  PoseCoordinateTransformer({
    required this.imageSize,
    required this.previewSize,
    required this.sensorOrientation,
    required this.isFrontCamera,
  }) {
    _computeTransform();
  }

  void _computeTransform() {
    // When sensor orientation is 90 or 270 (standard Android portrait),
    // the upright rotated frame swaps the camera buffer's landscape width and height.
    final bool isRotated90or270 =
        sensorOrientation == 90 || sensorOrientation == 270;
    rotatedImageSize = isRotated90or270
        ? Size(imageSize.height, imageSize.width)
        : imageSize;

    if (rotatedImageSize.width <= 0 || rotatedImageSize.height <= 0) {
      scale = 1.0;
      offsetX = 0.0;
      offsetY = 0.0;
      return;
    }

    // BoxFit.cover: scale uniformly so the image covers the entire screen.
    final double scaleX = previewSize.width / rotatedImageSize.width;
    final double scaleY = previewSize.height / rotatedImageSize.height;
    scale = scaleX > scaleY ? scaleX : scaleY;

    // Center the scaled image within the preview (crops equally on overflowing edges).
    offsetX = (previewSize.width - rotatedImageSize.width * scale) / 2.0;
    offsetY = (previewSize.height - rotatedImageSize.height * scale) / 2.0;
  }

  /// Transforms a single landmark point from ML Kit coordinate space to screen space.
  Offset transformPoint(double imageX, double imageY) {
    double x = imageX;
    double y = imageY;

    // ML Kit outputs coordinates in the upright rotated frame.
    // Front camera preview is mirrored horizontally so the user sees a mirror image.
    if (isFrontCamera) {
      x = rotatedImageSize.width - x;
    }

    // Scale and translate according to BoxFit.cover.
    x = x * scale + offsetX;
    y = y * scale + offsetY;

    return Offset(x, y);
  }

  /// Convenience factory from CameraController, CameraImage, and preview widget size.
  static PoseCoordinateTransformer create({
    required CameraController controller,
    required Size imageSize,
    required Size previewWidgetSize,
  }) {
    final CameraDescription camera = controller.description;
    return PoseCoordinateTransformer(
      imageSize: imageSize,
      previewSize: previewWidgetSize,
      sensorOrientation: camera.sensorOrientation,
      isFrontCamera: camera.lensDirection == CameraLensDirection.front,
    );
  }
}
