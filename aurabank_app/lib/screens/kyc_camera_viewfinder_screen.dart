import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/aura_theme.dart';

enum KycCameraMode {
  cardFront,
  cardBack,
  selfie,
}

/// Real-time In-App Camera Viewfinder with Live Alignment Guidelines and Corner Brackets.
class KycCameraViewfinderScreen extends StatefulWidget {
  final KycCameraMode mode;
  final String documentTitle;

  const KycCameraViewfinderScreen({
    super.key,
    required this.mode,
    required this.documentTitle,
  });

  @override
  State<KycCameraViewfinderScreen> createState() => _KycCameraViewfinderScreenState();
}

class _KycCameraViewfinderScreenState extends State<KycCameraViewfinderScreen>
    with SingleTickerProviderStateMixin {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isTorchOn = false;
  int _selectedCameraIndex = 0;
  String? _initError;

  // Review step after snapping
  Uint8List? _previewBytes;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _initCamera();
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _initError = 'No camera found on this device.';
        });
        return;
      }

      _cameras = cameras;

      // Select default camera: front for selfie, back for document cards
      int defaultIndex = 0;
      if (widget.mode == KycCameraMode.selfie) {
        final frontIdx = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        if (frontIdx != -1) defaultIndex = frontIdx;
      } else {
        final backIdx = _cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        if (backIdx != -1) defaultIndex = backIdx;
      }

      _selectedCameraIndex = defaultIndex;
      await _startController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _initError = 'Camera access error: $e';
      });
    }
  }

  Future<void> _startController(CameraDescription description) async {
    final oldController = _controller;
    if (oldController != null) {
      await oldController.dispose();
    }

    final newController = CameraController(
      description,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();
      if (!mounted) return;
      setState(() {
        _controller = newController;
        _isInitializing = false;
        _initError = null;
        _isTorchOn = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _initError = 'Failed to start camera: $e';
      });
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final nextState = !_isTorchOn;
      await _controller!.setFlashMode(nextState ? FlashMode.torch : FlashMode.off);
      setState(() => _isTorchOn = nextState);
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    setState(() => _isInitializing = true);
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gallery selection failed: $e')),
      );
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    try {
      setState(() => _isCapturing = true);
      HapticFeedback.mediumImpact();

      final XFile file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _previewBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture photo: $e')),
      );
    }
  }

  void _confirmAndReturn() {
    if (_previewBytes != null) {
      Navigator.of(context).pop(_previewBytes);
    }
  }

  void _retake() {
    setState(() {
      _previewBytes = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Camera stream or captured review
            if (_previewBytes != null)
              _buildReviewView()
            else if (_isInitializing)
              const Center(
                child: CircularProgressIndicator(color: AuraColors.accentLight),
              )
            else if (_initError != null)
              _buildErrorView()
            else
              _buildLiveCameraView(),

            // Layer 2: Top header bar
            _buildTopBar(),

            // Layer 3: Bottom controls (only when live preview)
            if (_previewBytes == null && _initError == null && !_isInitializing)
              _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final title = widget.mode == KycCameraMode.selfie
        ? 'Position Your Face'
        : widget.mode == KycCameraMode.cardBack
            ? 'Back of ${widget.documentTitle}'
            : 'Front of ${widget.documentTitle}';

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 12,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.mode == KycCameraMode.selfie
                        ? 'Ensure your face is centered inside the oval'
                        : 'Align all 4 card corners inside the guide box',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.mode != KycCameraMode.selfie && _controller != null)
              IconButton(
                icon: Icon(
                  _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white,
                  size: 24,
                ),
                onPressed: _toggleTorch,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCameraView() {
    final size = MediaQuery.of(context).size;
    final isCard = widget.mode != KycCameraMode.selfie;

    // Standard CR80 aspect ratio (85.60 mm × 53.98 mm ≈ 1.586)
    final double cardWidth = size.width - 48;
    final double cardHeight = cardWidth / 1.586;

    // Selfie oval dimensions
    final double ovalWidth = min(size.width * 0.72, 280);
    final double ovalHeight = ovalWidth * 1.35;

    final cutoutRect = isCard
        ? Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.44),
            width: cardWidth,
            height: cardHeight,
          )
        : Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.44),
            width: ovalWidth,
            height: ovalHeight,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera sensor stream
        Center(
          child: CameraPreview(_controller!),
        ),

        // Darkened mask overlay with clear cutout window
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return CustomPaint(
              size: size,
              painter: _ViewfinderOverlayPainter(
                cutoutRect: cutoutRect,
                isOval: !isCard,
                pulseProgress: _animController.value,
              ),
            );
          },
        ),

        // Real-time helper badge floating right above bottom controls
        Positioned(
          top: cutoutRect.bottom + 18,
          left: 20,
          right: 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.center_focus_strong_rounded,
                      color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isCard
                        ? 'Fit card edges within the green corners'
                        : 'Look directly at the camera with neutral face',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Gallery Picker Button
            IconButton(
              icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
              tooltip: 'Choose from Gallery',
              onPressed: _pickFromGallery,
            ),

            // Big Shutter Button
            GestureDetector(
              onTap: _isCapturing ? null : _takePicture,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  color: Colors.transparent,
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing ? AuraColors.primary : Colors.white,
                  ),
                  child: _isCapturing
                      ? const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),

            // Camera Flip Button (Front / Rear)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 28),
              tooltip: 'Flip Camera',
              onPressed: _cameras.length > 1 ? _switchCamera : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewView() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _previewBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Is the text clear and fully visible?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _retake,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retake',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _confirmAndReturn,
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('Use Photo',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 56),
            const SizedBox(height: 16),
            Text(
              _initError ?? 'Unable to initialize camera.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AuraColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Select from Gallery Instead'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for semi-transparent overlay and corner alignment brackets.
class _ViewfinderOverlayPainter extends CustomPainter {
  final Rect cutoutRect;
  final bool isOval;
  final double pulseProgress;

  _ViewfinderOverlayPainter({
    required this.cutoutRect,
    required this.isOval,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.68)
      ..style = PaintingStyle.fill;

    final screenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path();

    if (isOval) {
      cutoutPath.addOval(cutoutRect);
    } else {
      cutoutPath.addRRect(
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(18)),
      );
    }

    final overlayPath = Path.combine(PathOperation.difference, screenPath, cutoutPath);
    canvas.drawPath(overlayPath, backgroundPaint);

    // Glowing border outline
    final glowAlpha = 0.5 + (0.4 * pulseProgress);
    final borderPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (isOval) {
      canvas.drawOval(cutoutRect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cutoutRect, const Radius.circular(18)),
        borderPaint,
      );

      // Draw 4 Prominent Corner Brackets
      _drawCornerBrackets(canvas, cutoutRect);
    }
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect) {
    const double armLength = 34.0;
    const double radius = 16.0;

    final bracketPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Top-Left
    path.moveTo(rect.left, rect.top + armLength);
    path.lineTo(rect.left, rect.top + radius);
    path.arcToPoint(
      Offset(rect.left + radius, rect.top),
      radius: const Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(rect.left + armLength, rect.top);

    // Top-Right
    path.moveTo(rect.right - armLength, rect.top);
    path.lineTo(rect.right - radius, rect.top);
    path.arcToPoint(
      Offset(rect.right, rect.top + radius),
      radius: const Radius.circular(radius),
      clockwise: true,
    );
    path.lineTo(rect.right, rect.top + armLength);

    // Bottom-Left
    path.moveTo(rect.left, rect.bottom - armLength);
    path.lineTo(rect.left, rect.bottom - radius);
    path.arcToPoint(
      Offset(rect.left + radius, rect.bottom),
      radius: const Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(rect.left + armLength, rect.bottom);

    // Bottom-Right
    path.moveTo(rect.right - armLength, rect.bottom);
    path.lineTo(rect.right - radius, rect.bottom);
    path.arcToPoint(
      Offset(rect.right, rect.bottom - radius),
      radius: const Radius.circular(radius),
      clockwise: false,
    );
    path.lineTo(rect.right, rect.bottom - armLength);

    canvas.drawPath(path, bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.pulseProgress != pulseProgress ||
        oldDelegate.cutoutRect != cutoutRect ||
        oldDelegate.isOval != isOval;
  }
}
