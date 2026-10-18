import 'dart:ui';

/// Represents a single detected body landmark with position, depth, and confidence.
class PoseLandmarkData {
  /// The type index of the landmark (matches MediaPipe BlazePose indices 0-32).
  final int type;

  /// The 2D position of the landmark in coordinates.
  final Offset imagePosition;

  /// The 3D z-coordinate (relative depth from hip mid-plane).
  final double z;

  /// The confidence/likelihood score (0.0 to 1.0).
  final double confidence;

  const PoseLandmarkData({
    required this.type,
    required this.imagePosition,
    required this.z,
    required this.confidence,
  });

  /// Whether this landmark is considered reliable enough to draw.
  bool get isVisible => confidence >= 0.35;

  /// X coordinate.
  double get x => imagePosition.dx;

  /// Y coordinate.
  double get y => imagePosition.dy;

  PoseLandmarkData copyWith({
    int? type,
    Offset? imagePosition,
    double? z,
    double? confidence,
  }) {
    return PoseLandmarkData(
      type: type ?? this.type,
      imagePosition: imagePosition ?? this.imagePosition,
      z: z ?? this.z,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// BlazePose 33-landmark topology indices.
class LandmarkType {
  static const int nose = 0;
  static const int leftEyeInner = 1;
  static const int leftEye = 2;
  static const int leftEyeOuter = 3;
  static const int rightEyeInner = 4;
  static const int rightEye = 5;
  static const int rightEyeOuter = 6;
  static const int leftEar = 7;
  static const int rightEar = 8;
  static const int leftMouth = 9;
  static const int rightMouth = 10;
  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  static const int leftPinky = 17;
  static const int rightPinky = 18;
  static const int leftIndex = 19;
  static const int rightIndex = 20;
  static const int leftThumb = 21;
  static const int rightThumb = 22;
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
  static const int leftHeel = 29;
  static const int rightHeel = 30;
  static const int leftFootIndex = 31;
  static const int rightFootIndex = 32;

  LandmarkType._();
}

/// Defines complete anatomical connections between BlazePose landmarks.
class SkeletonConnections {
  /// Left arm (shoulder -> elbow -> wrist).
  static const List<List<int>> leftArm = [
    [LandmarkType.leftShoulder, LandmarkType.leftElbow],
    [LandmarkType.leftElbow, LandmarkType.leftWrist],
  ];

  /// Right arm (shoulder -> elbow -> wrist).
  static const List<List<int>> rightArm = [
    [LandmarkType.rightShoulder, LandmarkType.rightElbow],
    [LandmarkType.rightElbow, LandmarkType.rightWrist],
  ];

  /// Left hand & fingers (wrist, thumb, index, pinky, palm).
  static const List<List<int>> leftHand = [
    [LandmarkType.leftWrist, LandmarkType.leftThumb],
    [LandmarkType.leftWrist, LandmarkType.leftIndex],
    [LandmarkType.leftWrist, LandmarkType.leftPinky],
    [LandmarkType.leftThumb, LandmarkType.leftIndex],
    [LandmarkType.leftIndex, LandmarkType.leftPinky],
  ];

  /// Right hand & fingers.
  static const List<List<int>> rightHand = [
    [LandmarkType.rightWrist, LandmarkType.rightThumb],
    [LandmarkType.rightWrist, LandmarkType.rightIndex],
    [LandmarkType.rightWrist, LandmarkType.rightPinky],
    [LandmarkType.rightThumb, LandmarkType.rightIndex],
    [LandmarkType.rightIndex, LandmarkType.rightPinky],
  ];

  /// Left leg (hip -> knee -> ankle).
  static const List<List<int>> leftLeg = [
    [LandmarkType.leftHip, LandmarkType.leftKnee],
    [LandmarkType.leftKnee, LandmarkType.leftAnkle],
  ];

  /// Right leg (hip -> knee -> ankle).
  static const List<List<int>> rightLeg = [
    [LandmarkType.rightHip, LandmarkType.rightKnee],
    [LandmarkType.rightKnee, LandmarkType.rightAnkle],
  ];

  /// Left foot (ankle -> heel -> foot index/toes -> ankle).
  static const List<List<int>> leftFoot = [
    [LandmarkType.leftAnkle, LandmarkType.leftHeel],
    [LandmarkType.leftHeel, LandmarkType.leftFootIndex],
    [LandmarkType.leftAnkle, LandmarkType.leftFootIndex],
  ];

  /// Right foot (ankle -> heel -> foot index/toes -> ankle).
  static const List<List<int>> rightFoot = [
    [LandmarkType.rightAnkle, LandmarkType.rightHeel],
    [LandmarkType.rightHeel, LandmarkType.rightFootIndex],
    [LandmarkType.rightAnkle, LandmarkType.rightFootIndex],
  ];

  /// Torso / ribcage lateral contours.
  static const List<List<int>> torsoLateral = [
    [LandmarkType.leftShoulder, LandmarkType.leftHip],
    [LandmarkType.rightShoulder, LandmarkType.rightHip],
  ];

  /// Facial bones & features (eyes, nose bridge, mouth, jawline).
  static const List<List<int>> face = [
    // Eyes & Brow
    [LandmarkType.leftEar, LandmarkType.leftEyeOuter],
    [LandmarkType.leftEyeOuter, LandmarkType.leftEye],
    [LandmarkType.leftEye, LandmarkType.leftEyeInner],
    [LandmarkType.leftEyeInner, LandmarkType.rightEyeInner],
    [LandmarkType.rightEyeInner, LandmarkType.rightEye],
    [LandmarkType.rightEye, LandmarkType.rightEyeOuter],
    [LandmarkType.rightEyeOuter, LandmarkType.rightEar],
    // Nose bridge
    [LandmarkType.leftEyeInner, LandmarkType.nose],
    [LandmarkType.rightEyeInner, LandmarkType.nose],
    // Mouth & Dental arch
    [LandmarkType.leftMouth, LandmarkType.rightMouth],
    // Upper lip / Philtrum
    [LandmarkType.nose, LandmarkType.leftMouth],
    [LandmarkType.nose, LandmarkType.rightMouth],
    // Jaw / Mandible contour to ears
    [LandmarkType.leftMouth, LandmarkType.leftEar],
    [LandmarkType.rightMouth, LandmarkType.rightEar],
  ];

  /// All left side connections combined.
  static List<List<int>> get leftSide => [
    ...leftArm,
    ...leftHand,
    ...leftLeg,
    ...leftFoot,
  ];

  /// All right side connections combined.
  static List<List<int>> get rightSide => [
    ...rightArm,
    ...rightHand,
    ...rightLeg,
    ...rightFoot,
  ];

  /// All torso / center connections combined.
  static List<List<int>> get center => [
    ...torsoLateral,
    [LandmarkType.leftShoulder, LandmarkType.rightShoulder],
    [LandmarkType.leftHip, LandmarkType.rightHip],
    ...face,
  ];

  /// All connections combined.
  static List<List<int>> get all => [...leftSide, ...rightSide, ...center];

  SkeletonConnections._();
}
