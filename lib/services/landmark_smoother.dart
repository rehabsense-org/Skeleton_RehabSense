import 'dart:math' as math;
import 'dart:ui';

import '../models/pose_landmark.dart';

/// Temporal smoothing filter for body landmarks using the 1€ Filter (One Euro Filter).
///
/// The 1€ Filter (Casiez et al., CHI 2012) is the industry standard for human
/// motion tracking. It uses an adaptive low-pass filter:
/// - At low speeds / stationary postures: Cutoff frequency is low (~1.0 Hz),
///   completely eliminating micro-tremor, jitter, and fluctuating animations.
/// - At high speeds (fast arm raises, jumping, squats): Cutoff frequency rises
///   linearly with speed, completely eliminating lag and keeping the skeleton
///   pinned to the user's joints in real time.
class LandmarkSmoother {
  /// Minimum cutoff frequency in Hertz for low speeds (lower = less jitter).
  final double minCutoff;

  /// Speed coefficient (higher = less lag during fast movements).
  final double beta;

  /// Cutoff frequency for derivative filtering in Hertz.
  final double dCutoff;

  /// Minimum confidence threshold below which landmarks are discarded.
  final double confidenceThreshold;

  /// Per-landmark 1€ Filter instances.
  final Map<int, _OneEuroPointFilter> _filters = {};

  /// Per-landmark confidence filters to avoid binary on/off flickering.
  final Map<int, double> _smoothedConfidence = {};

  /// Consecutive missing frame counts per landmark.
  final Map<int, int> _missingCounts = {};

  /// Max missing frames before resetting a landmark's filter history.
  static const int _maxMissingFrames = 8;

  LandmarkSmoother({
    this.minCutoff = 1.0,
    this.beta = 0.007,
    this.dCutoff = 1.0,
    this.confidenceThreshold = 0.35,
  });

  /// Smooth raw landmarks from a new frame.
  List<PoseLandmarkData> smooth(
    List<PoseLandmarkData> rawLandmarks, {
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final Map<int, PoseLandmarkData> current = {
      for (final lm in rawLandmarks) lm.type: lm,
    };

    final List<PoseLandmarkData> result = [];

    for (int i = 0; i < 33; i++) {
      final PoseLandmarkData? raw = current[i];

      if (raw == null || raw.confidence < confidenceThreshold) {
        // Landmark missing or uncertain
        _missingCounts[i] = (_missingCounts[i] ?? 0) + 1;
        if (_missingCounts[i]! >= _maxMissingFrames) {
          _filters.remove(i);
          _smoothedConfidence.remove(i);
        } else if (_filters.containsKey(i)) {
          // Decay confidence smoothly rather than abruptly dropping
          final prevConf = (_smoothedConfidence[i] ?? 0.5) * 0.75;
          _smoothedConfidence[i] = prevConf;
          if (prevConf >= 0.25) {
            final prevPos = _filters[i]!.lastPosition;
            if (prevPos != null) {
              result.add(
                PoseLandmarkData(
                  type: i,
                  imagePosition: prevPos,
                  z: 0.0,
                  confidence: prevConf,
                ),
              );
            }
          }
        }
        continue;
      }

      _missingCounts[i] = 0;

      // Smooth confidence to eliminate on/off flickering
      final double prevConf = _smoothedConfidence[i] ?? raw.confidence;
      final double smoothConf = 0.7 * raw.confidence + 0.3 * prevConf;
      _smoothedConfidence[i] = smoothConf;

      // Filter position through 1€ Filter
      final filter = _filters.putIfAbsent(
        i,
        () => _OneEuroPointFilter(
          minCutoff: minCutoff,
          beta: beta,
          dCutoff: dCutoff,
        ),
      );

      final Offset smoothedPos = filter.filter(raw.imagePosition, now);

      result.add(
        PoseLandmarkData(
          type: i,
          imagePosition: smoothedPos,
          z: raw.z,
          confidence: smoothConf,
        ),
      );
    }

    return result;
  }

  /// Reset all smoothing history (call when tracking is lost or camera switches).
  void reset() {
    _filters.clear();
    _smoothedConfidence.clear();
    _missingCounts.clear();
  }
}

/// A 2D One Euro Filter for smoothing an (x, y) Offset with adaptive cutoff.
class _OneEuroPointFilter {
  final double minCutoff;
  final double beta;
  final double dCutoff;

  double? _xHatPrev;
  double? _yHatPrev;
  double? _dxHatPrev;
  double? _dyHatPrev;
  DateTime? _tPrev;

  _OneEuroPointFilter({
    required this.minCutoff,
    required this.beta,
    required this.dCutoff,
  });

  Offset? get lastPosition => _xHatPrev != null && _yHatPrev != null
      ? Offset(_xHatPrev!, _yHatPrev!)
      : null;

  Offset filter(Offset current, DateTime timestamp) {
    if (_xHatPrev == null || _yHatPrev == null || _tPrev == null) {
      _xHatPrev = current.dx;
      _yHatPrev = current.dy;
      _dxHatPrev = 0.0;
      _dyHatPrev = 0.0;
      _tPrev = timestamp;
      return current;
    }

    // Time elapsed in seconds (clamped to realistic frame intervals)
    final double dt = (timestamp.difference(_tPrev!).inMicroseconds / 1000000.0)
        .clamp(0.001, 0.1);
    _tPrev = timestamp;

    // 1. Raw derivative (velocity)
    final double dx = (current.dx - _xHatPrev!) / dt;
    final double dy = (current.dy - _yHatPrev!) / dt;

    // 2. Filter derivative with fixed cutoff dCutoff
    final double alphaD = _computeAlpha(dt, dCutoff);
    final double dxHat = alphaD * dx + (1.0 - alphaD) * _dxHatPrev!;
    final double dyHat = alphaD * dy + (1.0 - alphaD) * _dyHatPrev!;
    _dxHatPrev = dxHat;
    _dyHatPrev = dyHat;

    // 3. Adaptive cutoff frequency based on velocity magnitude
    final double speed = math.sqrt(dxHat * dxHat + dyHat * dyHat);
    final double cutoff = minCutoff + beta * speed;

    // 4. Filter position with adaptive cutoff
    final double alpha = _computeAlpha(dt, cutoff);
    final double xHat = alpha * current.dx + (1.0 - alpha) * _xHatPrev!;
    final double yHat = alpha * current.dy + (1.0 - alpha) * _yHatPrev!;
    _xHatPrev = xHat;
    _yHatPrev = yHat;

    return Offset(xHat, yHat);
  }

  static double _computeAlpha(double dt, double cutoff) {
    final double tau = 1.0 / (2.0 * math.pi * cutoff);
    return 1.0 / (1.0 + tau / dt);
  }
}
