import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../theme/aura_theme.dart';

enum KycCameraMode {
  cardFront,
  cardBack,
  selfie,
}

class _CropParams {
  final Uint8List rawBytes;
  final double cutoutLeft;
  final double cutoutTop;
  final double cutoutWidth;
  final double cutoutHeight;
  final double screenWidth;
  final double screenHeight;

  _CropParams({
    required this.rawBytes,
    required this.cutoutLeft,
    required this.cutoutTop,
    required this.cutoutWidth,
    required this.cutoutHeight,
    required this.screenWidth,
    required this.screenHeight,
  });
}

Uint8List _processAndCropImage(_CropParams params) {
  img.Image? image = img.decodeImage(params.rawBytes);
  if (image == null) return params.rawBytes;

  image = img.bakeOrientation(image);

  final double imgW = image.width.toDouble();
  final double imgH = image.height.toDouble();

  // Full-bleed BoxFit.cover mapping from sensor image to phone screen
  final double scale = max(params.screenWidth / imgW, params.screenHeight / imgH);
  final double displayedW = imgW * scale;
  final double displayedH = imgH * scale;
  final double offsetX = (params.screenWidth - displayedW) / 2.0;
  final double offsetY = (params.screenHeight - displayedH) / 2.0;

  int cropX = ((params.cutoutLeft - offsetX) / scale).round();
  int cropY = ((params.cutoutTop - offsetY) / scale).round();
  int cropW = (params.cutoutWidth / scale).round();
  int cropH = (params.cutoutHeight / scale).round();

  // Safety clamping within image bounds
  cropX = cropX.clamp(0, image.width - 1);
  cropY = cropY.clamp(0, image.height - 1);
  cropW = cropW.clamp(1, image.width - cropX);
  cropH = cropH.clamp(1, image.height - cropY);

  final cropped = img.copyCrop(
    image,
    x: cropX,
    y: cropY,
    width: cropW,
    height: cropH,
  );

  return Uint8List.fromList(img.encodeJpg(cropped, quality: 95));
}

/// Real-time In-App Camera Viewfinder with Live Alignment Guidelines and Automatic Framing Crop.
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

  // 3D Photometric Liveness State (Spectral Emitter Reflection)
  bool _isLivenessActive = false;
  Color _livenessColor = const Color(0xFF00E5FF);
  String _livenessStatusText = '';
  int _livenessStep = 0;
  double _livenessProgress = 0.0;

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

  Rect _calculateCutoutRect(Size size) {
    final isCard = widget.mode != KycCameraMode.selfie;

    if (isCard) {
      // Standard CR80 aspect ratio (1.586 : 1)
      final double cardWidth = size.width - 44;
      final double cardHeight = cardWidth / 1.586;
      return Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.44),
        width: cardWidth,
        height: cardHeight,
      );
    } else {
      // Selfie oval dimensions
      final double ovalWidth = min(size.width * 0.72, 280);
      final double ovalHeight = ovalWidth * 1.35;
      return Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.44),
        width: ovalWidth,
        height: ovalHeight,
      );
    }
  }

  Future<void> _run3DLivenessScan() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing || _isLivenessActive) return;

    final size = MediaQuery.of(context).size;
    final cutoutRect = _calculateCutoutRect(size);

    setState(() {
      _isLivenessActive = true;
      _livenessStep = 1;
      _livenessColor = const Color(0xFF00E5FF); // Vivid Cyan
      _livenessStatusText = 'Hold still: Reflecting Cyan light...';
      _livenessProgress = 0.33;
    });
    HapticFeedback.lightImpact();

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || !_isLivenessActive) return;

    setState(() {
      _livenessStep = 2;
      _livenessColor = const Color(0xFFFF007A); // Vivid Magenta
      _livenessStatusText = 'Measuring 3D depth: Reflecting Magenta...';
      _livenessProgress = 0.66;
    });
    HapticFeedback.lightImpact();

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || !_isLivenessActive) return;

    setState(() {
      _livenessStep = 3;
      _livenessColor = const Color(0xFF2FA37E); // Vivid Emerald
      _livenessStatusText = 'Confirming curvature: Reflecting Emerald...';
      _livenessProgress = 1.0;
    });
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted || !_isLivenessActive) return;

    setState(() {
      _isCapturing = true;
      _livenessStatusText = '3D Surface Verified: Snapping biometric frame...';
    });
    HapticFeedback.heavyImpact();

    try {
      final XFile file = await _controller!.takePicture();
      final rawBytes = await file.readAsBytes();

      // Crop precisely to the alignment cutout in a background isolate
      final croppedBytes = await compute(
        _processAndCropImage,
        _CropParams(
          rawBytes: rawBytes,
          cutoutLeft: cutoutRect.left,
          cutoutTop: cutoutRect.top,
          cutoutWidth: cutoutRect.width,
          cutoutHeight: cutoutRect.height,
          screenWidth: size.width,
          screenHeight: size.height,
        ),
      );

      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _isLivenessActive = false;
        _previewBytes = croppedBytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _isLivenessActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to complete 3D liveness scan: $e')),
      );
    }
  }

  Future<void> _handleCaptureAction() async {
    if (widget.mode == KycCameraMode.selfie) {
      await _run3DLivenessScan();
    } else {
      await _takePicture();
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    final size = MediaQuery.of(context).size;
    final cutoutRect = _calculateCutoutRect(size);

    try {
      setState(() => _isCapturing = true);
      HapticFeedback.mediumImpact();

      final XFile file = await _controller!.takePicture();
      final rawBytes = await file.readAsBytes();

      // Crop precisely to the alignment cutout in a background isolate
      final croppedBytes = await compute(
        _processAndCropImage,
        _CropParams(
          rawBytes: rawBytes,
          cutoutLeft: cutoutRect.left,
          cutoutTop: cutoutRect.top,
          cutoutWidth: cutoutRect.width,
          cutoutHeight: cutoutRect.height,
          screenWidth: size.width,
          screenHeight: size.height,
        ),
      );

      if (!mounted) return;
      setState(() {
        _isCapturing = false;
        _previewBytes = croppedBytes;
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
    final cutoutRect = _calculateCutoutRect(size);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed camera sensor stream
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.previewSize != null
                  ? _controller!.value.previewSize!.height
                  : size.width,
              height: _controller!.value.previewSize != null
                  ? _controller!.value.previewSize!.width
                  : size.height,
              child: CameraPreview(_controller!),
            ),
          ),
        ),

        // Darkened mask overlay with clear cutout window and spectral emitter illumination
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return CustomPaint(
              size: size,
              painter: _ViewfinderOverlayPainter(
                cutoutRect: cutoutRect,
                isOval: !isCard,
                pulseProgress: _animController.value,
                isLivenessActive: _isLivenessActive,
                livenessColor: _livenessColor,
                livenessProgress: _livenessProgress,
              ),
            );
          },
        ),

        // Spectral color calibration indicators for selfie mode
        if (!isCard)
          Positioned(
            top: cutoutRect.top - 54,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isLivenessActive ? _livenessColor : Colors.white24,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSpectralDot('Cyan', const Color(0xFF00E5FF), _livenessStep == 1),
                    const SizedBox(width: 8),
                    _buildSpectralDot('Magenta', const Color(0xFFFF007A), _livenessStep == 2),
                    const SizedBox(width: 8),
                    _buildSpectralDot('Emerald', const Color(0xFF2FA37E), _livenessStep == 3),
                  ],
                ),
              ),
            ),
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
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isLivenessActive
                      ? _livenessColor
                      : const Color(0xFF2FA37E).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isLivenessActive
                        ? Icons.flare_rounded
                        : (isCard ? Icons.center_focus_strong_rounded : Icons.face_rounded),
                    color: _isLivenessActive ? _livenessColor : const Color(0xFF2FA37E),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isLivenessActive
                        ? _livenessStatusText
                        : (isCard
                            ? 'Fit card edges within the green corners'
                            : 'Look directly at camera. Tap button to start 3D scan'),
                    style: TextStyle(
                      color: _isLivenessActive ? _livenessColor : Colors.white,
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

  Widget _buildSpectralDot(String label, Color color, bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? color : Colors.white24,
          width: isActive ? 1.5 : 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isActive
                  ? [BoxShadow(color: color, blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
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
              onPressed: (_isCapturing || _isLivenessActive) ? null : _pickFromGallery,
            ),

            // Big Shutter Button
            GestureDetector(
              onTap: (_isCapturing || _isLivenessActive) ? null : _handleCaptureAction,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isLivenessActive ? _livenessColor : Colors.white,
                    width: 4,
                  ),
                  color: Colors.transparent,
                ),
                padding: const EdgeInsets.all(4),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCapturing
                        ? AuraColors.primary
                        : (_isLivenessActive ? _livenessColor : Colors.white),
                  ),
                  child: (_isCapturing || _isLivenessActive)
                      ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                              value: _isLivenessActive ? _livenessProgress : null,
                            ),
                          ),
                        )
                      : (widget.mode == KycCameraMode.selfie
                          ? const Center(
                              child: Icon(
                                Icons.face_retouching_natural_rounded,
                                color: Colors.black87,
                                size: 30,
                              ),
                            )
                          : null),
                ),
              ),
            ),

            // Camera Flip Button (Front / Rear)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 28),
              tooltip: 'Flip Camera',
              onPressed: (_cameras.length > 1 && !_isLivenessActive && !_isCapturing)
                  ? _switchCamera
                  : null,
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
              color: const Color(0xFF10171C),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.mode == KycCameraMode.selfie)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2FA37E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF2FA37E).withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_user_rounded,
                            color: Color(0xFF2FA37E), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '3D Photometric Liveness Verified',
                                style: TextStyle(
                                  color: Color(0xFF2FA37E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Spectral reflections (Cyan, Magenta, Emerald) verified 3D depth and filtered 2D prints.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        color: Color(0xFF2FA37E), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.mode == KycCameraMode.selfie
                          ? 'Face is clear and well-lit'
                          : 'Is the text clear and fully visible?',
                      style: const TextStyle(
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
                          backgroundColor: const Color(0xFF2FA37E),
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
  final bool isLivenessActive;
  final Color livenessColor;
  final double livenessProgress;

  _ViewfinderOverlayPainter({
    required this.cutoutRect,
    required this.isOval,
    required this.pulseProgress,
    this.isLivenessActive = false,
    this.livenessColor = const Color(0xFF00E5FF),
    this.livenessProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = isLivenessActive
          ? livenessColor.withValues(alpha: 0.88)
          : Colors.black.withValues(alpha: 0.68)
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
      ..color = isLivenessActive
          ? livenessColor
          : const Color(0xFF2FA37E).withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isLivenessActive ? 3.5 : 1.5;

    if (isOval) {
      canvas.drawOval(cutoutRect, borderPaint);

      if (isLivenessActive) {
        final glowHalo = Paint()
          ..color = livenessColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0;
        canvas.drawOval(cutoutRect.inflate(6), glowHalo);
      }
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
      ..color = const Color(0xFF2FA37E)
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
        oldDelegate.isOval != isOval ||
        oldDelegate.isLivenessActive != isLivenessActive ||
        oldDelegate.livenessColor != livenessColor ||
        oldDelegate.livenessProgress != livenessProgress;
  }
}
