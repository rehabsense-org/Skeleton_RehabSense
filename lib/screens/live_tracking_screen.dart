import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/pose_landmark.dart';
import '../painters/skeleton_painter.dart';
import '../services/camera_service.dart';
import '../services/landmark_smoother.dart';
import '../services/pose_coordinate_transformer.dart';
import '../services/pose_detection_service.dart';

/// The main live tracking screen.
///
/// Composes the camera preview with the skeleton overlay and manages
/// the full pipeline: camera → inference → smoothing → transform → paint.
class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final PoseDetectionService _poseDetectionService = PoseDetectionService();
  final LandmarkSmoother _smoother = LandmarkSmoother();

  /// Landmarks in screen coordinates, ready to draw.
  List<PoseLandmarkData> _screenLandmarks = [];

  /// Current size of the preview canvas.
  Size _previewWidgetSize = Size.zero;

  /// Whether the system is initializing.
  bool _isInitializing = true;

  /// Error message if initialization fails.
  String? _errorMessage;

  /// Whether a person is currently detected.
  bool _isPersonDetected = false;

  /// Whether the skeleton overlay is visible (toggle).
  bool _showSkeleton = true;

  /// FPS measurement.
  int _fps = 0;
  int _frameCount = 0;
  DateTime _lastFpsTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePipeline();
  }

  Future<void> _initializePipeline() async {
    try {
      // Initialize pose detector.
      _poseDetectionService.initialize();

      // Initialize camera.
      await _cameraService.initialize();

      // Set up frame callback.
      _cameraService.onFrameAvailable = _onCameraFrame;

      // Start streaming.
      await _cameraService.startStream();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = 'Camera initialization failed: $e';
        });
      }
    }
  }

  /// Called for each camera frame. Runs inference and updates landmarks.
  void _onCameraFrame(CameraImage image) async {
    final camera = _cameraService.currentCamera;
    if (camera == null) return;

    final landmarks = await _poseDetectionService.processFrame(image, camera);

    if (!mounted) return;

    if (landmarks == null || landmarks.isEmpty) {
      // No person detected this frame.
      if (_isPersonDetected) {
        setState(() {
          _isPersonDetected = false;
          _screenLandmarks = [];
        });
      }
      return;
    }

    // Smooth the raw landmarks.
    final smoothed = _smoother.smooth(landmarks);

    // Transform to screen coordinates.
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_previewWidgetSize.width <= 0 || _previewWidgetSize.height <= 0) return;

    final transformer = PoseCoordinateTransformer(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      previewSize: _previewWidgetSize,
      sensorOrientation: camera.sensorOrientation,
      isFrontCamera: camera.lensDirection == CameraLensDirection.front,
    );

    final List<PoseLandmarkData> screenLandmarks = smoothed.map((lm) {
      final screenPos = transformer.transformPoint(lm.x, lm.y);
      return PoseLandmarkData(
        type: lm.type,
        imagePosition: screenPos,
        z: lm.z,
        confidence: lm.confidence,
      );
    }).toList();

    // Update FPS counter.
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsTime);
    if (elapsed.inMilliseconds >= 1000) {
      _fps = (_frameCount * 1000 / elapsed.inMilliseconds).round();
      _frameCount = 0;
      _lastFpsTime = now;
    }

    if (mounted) {
      setState(() {
        _screenLandmarks = screenLandmarks;
        _isPersonDetected = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause/resume camera when app goes to background/foreground.
    if (state == AppLifecycleState.paused) {
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializePipeline();
    }
  }

  Future<void> _switchCamera() async {
    _smoother.reset();
    setState(() {
      _screenLandmarks = [];
      _isPersonDetected = false;
    });
    final success = await _cameraService.switchCamera();
    if (success) {
      await _cameraService.startStream();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraService.dispose();
    _poseDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: _buildBody());
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00E5CC)),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please enable camera access in Android Settings → Apps → RehabSense → Permissions.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializePipeline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5CC),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _cameraService.controller;
    final camera = _cameraService.currentCamera;
    if (controller == null ||
        !controller.value.isInitialized ||
        camera == null) {
      return const Center(
        child: Text(
          'Camera not available.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final bool isRotated =
        camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
    final double rawW = controller.value.previewSize?.width ?? 1280;
    final double rawH = controller.value.previewSize?.height ?? 720;
    final double rotatedW = isRotated ? rawH : rawW;
    final double rotatedH = isRotated ? rawW : rawH;

    return LayoutBuilder(
      builder: (context, constraints) {
        _previewWidgetSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview (BoxFit.cover fills the screen).
            ClipRect(
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: rotatedW,
                    height: rotatedH,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            ),

            // Skeleton overlay.
            if (_showSkeleton && _screenLandmarks.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: SkeletonPainter(landmarks: _screenLandmarks),
                ),
              ),

            // Top status bar.
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: _buildStatusBar(),
            ),

            // Bottom controls.
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            // "No person detected" message.
            if (!_isPersonDetected)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'No person detected',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBar() {
    return Row(
      children: [
        // Tracking indicator.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPersonDetected
                      ? const Color(0xFF00E5CC)
                      : Colors.white38,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isPersonDetected ? 'Tracking' : 'Searching',
                style: TextStyle(
                  color: _isPersonDetected
                      ? const Color(0xFF00E5CC)
                      : Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // FPS counter.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$_fps FPS',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skeleton visibility toggle.
        _CircleButton(
          icon: _showSkeleton ? Icons.visibility : Icons.visibility_off,
          onPressed: () {
            setState(() {
              _showSkeleton = !_showSkeleton;
            });
          },
          tooltip: 'Toggle skeleton',
        ),
        const SizedBox(width: 32),
        // Camera switch button.
        if (_cameraService.canSwitchCamera)
          _CircleButton(
            icon: Icons.cameraswitch_rounded,
            onPressed: _switchCamera,
            tooltip: 'Switch camera',
          ),
      ],
    );
  }
}

/// A minimal circular icon button used for controls.
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _CircleButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: Colors.white70, size: 24),
          ),
        ),
      ),
    );
  }
}
