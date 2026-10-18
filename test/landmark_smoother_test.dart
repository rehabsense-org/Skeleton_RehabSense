import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_rehabsense/models/pose_landmark.dart';
import 'package:skeleton_rehabsense/services/landmark_smoother.dart';

void main() {
  group('LandmarkSmoother (1€ Filter)', () {
    test('First frame passes raw values through without lag', () {
      final smoother = LandmarkSmoother();

      final raw = [
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(100, 200),
          z: 0.0,
          confidence: 0.9,
        ),
      ];

      final smoothed = smoother.smooth(raw);
      expect(smoothed.length, 1);
      expect(smoothed.first.x, 100);
      expect(smoothed.first.y, 200);
    });

    test('Stationary posture receives heavy jitter filtering', () {
      final smoother = LandmarkSmoother(minCutoff: 1.0, beta: 0.007);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);

      // Frame 1: baseline position (100, 100)
      smoother.smooth([
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(100, 100),
          z: 0.0,
          confidence: 0.9,
        ),
      ], timestamp: t0);

      // Frame 2 (33ms later): 2px noise tremor to (102, 100)
      final t1 = t0.add(const Duration(milliseconds: 33));
      final result = smoother.smooth([
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(102, 100),
          z: 0.0,
          confidence: 0.9,
        ),
      ], timestamp: t1);

      // 1€ Filter heavily dampens small tremor: result.x will be close to 100 (< 101)
      expect(result.first.x, lessThan(101.0));
      expect(result.first.x, greaterThanOrEqualTo(100.0));
    });

    test('Fast motion adapts cutoff to track without excessive lag', () {
      final smoother = LandmarkSmoother(minCutoff: 1.0, beta: 0.007);
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);

      // Frame 1: at x = 100
      smoother.smooth([
        const PoseLandmarkData(
          type: LandmarkType.leftWrist,
          imagePosition: Offset(100, 100),
          z: 0.0,
          confidence: 0.9,
        ),
      ], timestamp: t0);

      // Frame 2: fast arm swing jumping 150px in 33ms
      final t1 = t0.add(const Duration(milliseconds: 33));
      final result = smoother.smooth([
        const PoseLandmarkData(
          type: LandmarkType.leftWrist,
          imagePosition: Offset(250, 100),
          z: 0.0,
          confidence: 0.9,
        ),
      ], timestamp: t1);

      // Fast speed opens the filter cutoff so it tracks swiftly (> 170)
      expect(result.first.x, greaterThan(170.0));
    });

    test('Low confidence landmarks are discarded if below threshold', () {
      final smoother = LandmarkSmoother(confidenceThreshold: 0.35);

      final raw = [
        const PoseLandmarkData(
          type: LandmarkType.leftPinky,
          imagePosition: Offset(50, 50),
          z: 0.0,
          confidence: 0.2, // Below 0.35 threshold
        ),
      ];

      final smoothed = smoother.smooth(raw);
      expect(smoothed.isEmpty, isTrue);
    });

    test('Manual reset clears all filter history', () {
      final smoother = LandmarkSmoother();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0, 0);

      smoother.smooth([
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(100, 100),
          z: 0.0,
          confidence: 0.9,
        ),
      ], timestamp: t0);

      smoother.reset();

      // After reset, new frame is treated as first frame (exact passthrough)
      final t1 = t0.add(const Duration(milliseconds: 33));
      final result = smoother.smooth([
        const PoseLandmarkData(
          type: LandmarkType.nose,
          imagePosition: Offset(300, 300),
          z: 0.0,
          confidence: 0.9,
        ),
      ], timestamp: t1);

      expect(result.first.x, 300);
      expect(result.first.y, 300);
    });
  });
}
