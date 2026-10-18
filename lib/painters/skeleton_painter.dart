import 'package:flutter/material.dart';

import '../models/pose_landmark.dart';

/// CustomPainter that renders a realistic, anatomically complete human skeleton.
///
/// Features:
/// - Axial skeleton: Cervical spine, thoracic/lumbar vertebral column with vertebrae nodes
/// - Clavicular & pelvic girdles: Collarbones and pelvic basin connecting shoulders and hips
/// - Transverse ribcage arcs: Thoracic ribs extending from spine to lateral torso
/// - Complete hand & finger rays: Palm, thumb, index, pinky, and knuckles for all finger actions
/// - Complete foot structure: Ankle, heel, sole arch, and toe index
/// - Detailed facial skeleton: Cranium dome, brow ridge, nose bridge, dental arch, and jawline
/// - Dual-pass rendering: Depth glow under-layer + crisp bone core for high contrast
/// - Color-coded body sides: Electric Cyan (Left), Mint Teal (Right), Luminescent Pearl (Spine/Face)
class SkeletonPainter extends CustomPainter {
  /// The detected and smoothed landmarks in screen coordinates.
  final List<PoseLandmarkData> landmarks;

  /// Minimum confidence to render a landmark.
  final double confidenceThreshold;

  // --- Pre-allocated Paints (Dual-pass: Glow + Core) ---

  // Glow under-layer paints
  static final Paint _leftGlowPaint = Paint()
    ..color = const Color(0x6600E5FF)
    ..strokeWidth = 7.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _rightGlowPaint = Paint()
    ..color = const Color(0x6600FFC8)
    ..strokeWidth = 7.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _axialGlowPaint = Paint()
    ..color = const Color(0x6680CBC4)
    ..strokeWidth = 6.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  // Core bone paints
  static final Paint _leftBonePaint = Paint()
    ..color =
        const Color(0xFF00E5FF) // Electric Cyan
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _rightBonePaint = Paint()
    ..color =
        const Color(0xFF00FFC8) // Mint Teal
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _axialBonePaint = Paint()
    ..color =
        const Color(0xFFE0F7FA) // Luminescent Pearl
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _ribPaint = Paint()
    ..color =
        const Color(0x4D80CBC4) // Semi-transparent ribcage
    ..strokeWidth = 2.0
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _fingerPaintLeft = Paint()
    ..color = const Color(0xFF80D8FF)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  static final Paint _fingerPaintRight = Paint()
    ..color = const Color(0xFFA7FFEB)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  // Joint paints
  static final Paint _jointHaloPaint = Paint()
    ..color = const Color(0x99004D40)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _jointCorePaint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _jointBorderPaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  SkeletonPainter({required this.landmarks, this.confidenceThreshold = 0.35});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final Map<int, PoseLandmarkData> map = {
      for (final lm in landmarks) lm.type: lm,
    };

    // 1. Draw anatomical Axial Skeleton (Spine, Neck, Ribcage, Clavicles, Pelvis)
    _drawAxialSkeleton(canvas, map);

    // 2. Draw Limbs (Under-glow first, then bone core)
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.leftArm,
      _leftGlowPaint,
    );
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.leftArm,
      _leftBonePaint,
    );

    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.rightArm,
      _rightGlowPaint,
    );
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.rightArm,
      _rightBonePaint,
    );

    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.leftLeg,
      _leftGlowPaint,
    );
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.leftLeg,
      _leftBonePaint,
    );

    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.rightLeg,
      _rightGlowPaint,
    );
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.rightLeg,
      _rightBonePaint,
    );

    // 3. Draw Hands & Fingers (Thumb, Index, Pinky, Metacarpals)
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.leftHand,
      _fingerPaintLeft,
    );
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.rightHand,
      _fingerPaintRight,
    );

    // 4. Draw Feet & Toes (Heel, Sole Arch, Dorsum)
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.leftFoot,
      _leftBonePaint,
    );
    _drawConnectionList(
      canvas,
      map,
      SkeletonConnections.rightFoot,
      _rightBonePaint,
    );

    // 5. Draw Facial Skeleton & Cranium
    _drawFacialSkeleton(canvas, map);

    // 6. Draw Joint Nodes on top of all connections
    _drawJointNodes(canvas, map);
  }

  /// Draws the central anatomical spine, neck, ribs, clavicles, and pelvic girdle.
  void _drawAxialSkeleton(Canvas canvas, Map<int, PoseLandmarkData> map) {
    final lSh = map[LandmarkType.leftShoulder];
    final rSh = map[LandmarkType.rightShoulder];
    final lHip = map[LandmarkType.leftHip];
    final rHip = map[LandmarkType.rightHip];

    if (lSh == null || rSh == null) {
      return;
    }
    if (lSh.confidence < confidenceThreshold ||
        rSh.confidence < confidenceThreshold) {
      return;
    }

    final midShoulder = Offset((lSh.x + rSh.x) / 2.0, (lSh.y + rSh.y) / 2.0);

    // Clavicles (Collar bones: Mid-Shoulder -> Left Shoulder & Right Shoulder)
    canvas.drawLine(midShoulder, lSh.imagePosition, _axialGlowPaint);
    canvas.drawLine(midShoulder, lSh.imagePosition, _axialBonePaint);
    canvas.drawLine(midShoulder, rSh.imagePosition, _axialGlowPaint);
    canvas.drawLine(midShoulder, rSh.imagePosition, _axialBonePaint);

    // Neck: connects mid-shoulder to head/mouth base
    final nose = map[LandmarkType.nose];
    final lMouth = map[LandmarkType.leftMouth];
    final rMouth = map[LandmarkType.rightMouth];
    Offset? headBase = nose?.imagePosition;
    if (lMouth != null &&
        rMouth != null &&
        lMouth.confidence >= confidenceThreshold &&
        rMouth.confidence >= confidenceThreshold) {
      headBase = Offset(
        (lMouth.x + rMouth.x) / 2.0,
        (lMouth.y + rMouth.y) / 2.0,
      );
    }
    if (headBase != null) {
      canvas.drawLine(headBase, midShoulder, _axialGlowPaint);
      canvas.drawLine(headBase, midShoulder, _axialBonePaint);
    }

    // Spine and Ribcage (if hips are available)
    if (lHip != null &&
        rHip != null &&
        lHip.confidence >= confidenceThreshold &&
        rHip.confidence >= confidenceThreshold) {
      final midHip = Offset((lHip.x + rHip.x) / 2.0, (lHip.y + rHip.y) / 2.0);

      // Pelvic Girdle (Mid-Hip -> Left Hip & Right Hip)
      canvas.drawLine(midHip, lHip.imagePosition, _axialGlowPaint);
      canvas.drawLine(midHip, lHip.imagePosition, _axialBonePaint);
      canvas.drawLine(midHip, rHip.imagePosition, _axialGlowPaint);
      canvas.drawLine(midHip, rHip.imagePosition, _axialBonePaint);

      // Vertebral Column (Main Spine: Mid-Shoulder -> Mid-Hip)
      canvas.drawLine(midShoulder, midHip, _axialGlowPaint);
      canvas.drawLine(midShoulder, midHip, _axialBonePaint);

      // Lateral Thorax Borders (Torso contours)
      canvas.drawLine(lSh.imagePosition, lHip.imagePosition, _leftBonePaint);
      canvas.drawLine(rSh.imagePosition, rHip.imagePosition, _rightBonePaint);

      // Anatomical Rib Arcs (3 pairs of ribs connecting spine to lateral torso)
      for (final ratio in [0.25, 0.50, 0.75]) {
        final spinePoint = Offset.lerp(midShoulder, midHip, ratio)!;
        final leftTorsoPoint = Offset.lerp(
          lSh.imagePosition,
          lHip.imagePosition,
          ratio,
        )!;
        final rightTorsoPoint = Offset.lerp(
          rSh.imagePosition,
          rHip.imagePosition,
          ratio,
        )!;

        canvas.drawLine(spinePoint, leftTorsoPoint, _ribPaint);
        canvas.drawLine(spinePoint, rightTorsoPoint, _ribPaint);

        // Vertebra node along the spine
        canvas.drawCircle(spinePoint, 2.5, _jointCorePaint);
      }
    }
  }

  /// Draws facial bones, cranium vault, eyes, nose, and jaw.
  void _drawFacialSkeleton(Canvas canvas, Map<int, PoseLandmarkData> map) {
    _drawConnectionList(canvas, map, SkeletonConnections.face, _axialBonePaint);

    final nose = map[LandmarkType.nose];
    final lEar = map[LandmarkType.leftEar];
    final rEar = map[LandmarkType.rightEar];

    // Cranium dome above forehead
    if (nose != null &&
        nose.confidence >= confidenceThreshold &&
        lEar != null &&
        rEar != null &&
        lEar.confidence >= confidenceThreshold &&
        rEar.confidence >= confidenceThreshold) {
      final headWidth = (rEar.imagePosition - lEar.imagePosition).distance;
      if (headWidth > 10) {
        final midEars = Offset(
          (lEar.x + rEar.x) / 2.0,
          (lEar.y + rEar.y) / 2.0,
        );
        final double craniumRadius = headWidth * 0.45;
        final craniumCenter = midEars - Offset(0, craniumRadius * 0.35);

        // Cranium dome arc
        canvas.drawCircle(
          craniumCenter,
          craniumRadius,
          Paint()
            ..color = const Color(0x3380CBC4)
            ..strokeWidth = 1.8
            ..style = PaintingStyle.stroke
            ..isAntiAlias = true,
        );
      }
    }
  }

  /// Draws joint nodes with varying radii based on anatomical significance.
  void _drawJointNodes(Canvas canvas, Map<int, PoseLandmarkData> map) {
    for (final entry in map.entries) {
      final lm = entry.value;
      if (lm.confidence < confidenceThreshold) continue;

      final double radius = _jointRadius(lm.type);
      final pos = lm.imagePosition;

      // Outer halo
      canvas.drawCircle(pos, radius + 2.5, _jointHaloPaint);
      // Border ring
      canvas.drawCircle(pos, radius + 1.0, _jointBorderPaint);
      // Solid bright core
      canvas.drawCircle(pos, radius, _jointCorePaint);
    }
  }

  double _jointRadius(int type) {
    switch (type) {
      // Major body joints (large condyles)
      case LandmarkType.leftShoulder:
      case LandmarkType.rightShoulder:
      case LandmarkType.leftHip:
      case LandmarkType.rightHip:
      case LandmarkType.leftKnee:
      case LandmarkType.rightKnee:
        return 5.0;

      // Medium joints
      case LandmarkType.leftElbow:
      case LandmarkType.rightElbow:
      case LandmarkType.leftAnkle:
      case LandmarkType.rightAnkle:
      case LandmarkType.leftWrist:
      case LandmarkType.rightWrist:
        return 4.0;

      // Feet & Hands
      case LandmarkType.leftHeel:
      case LandmarkType.rightHeel:
      case LandmarkType.leftFootIndex:
      case LandmarkType.rightFootIndex:
      case LandmarkType.leftThumb:
      case LandmarkType.rightThumb:
      case LandmarkType.leftIndex:
      case LandmarkType.rightIndex:
      case LandmarkType.leftPinky:
      case LandmarkType.rightPinky:
        return 3.0;

      // Facial feature nodes
      default:
        return 2.2;
    }
  }

  void _drawConnectionList(
    Canvas canvas,
    Map<int, PoseLandmarkData> map,
    List<List<int>> connections,
    Paint paint,
  ) {
    for (final conn in connections) {
      final a = map[conn[0]];
      final b = map[conn[1]];

      if (a == null || b == null) continue;
      if (a.confidence < confidenceThreshold ||
          b.confidence < confidenceThreshold) {
        continue;
      }

      canvas.drawLine(a.imagePosition, b.imagePosition, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return !identical(oldDelegate.landmarks, landmarks);
  }
}
