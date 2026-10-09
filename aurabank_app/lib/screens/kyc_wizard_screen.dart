import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/bank_service.dart';
import '../services/kyc_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'kyc_camera_viewfinder_screen.dart';

enum KycStep {
  selectIdType,
  captureFront,
  captureBack,
  captureSelfie,
  processing,
  verdict,
}

class KycWizardScreen extends StatefulWidget {
  final VoidCallback? onCompleted;

  const KycWizardScreen({super.key, this.onCompleted});

  @override
  State<KycWizardScreen> createState() => _KycWizardScreenState();
}

class _KycWizardScreenState extends State<KycWizardScreen>
    with SingleTickerProviderStateMixin {
  final KycService _kycService = KycService();
  final ImagePicker _picker = ImagePicker();

  KycStep _currentStep = KycStep.selectIdType;
  KycDocumentType _selectedType = KycDocumentType.supportedTypes[0];

  // Captured image buffers
  Uint8List? _frontBytes;
  Uint8List? _backBytes;
  Uint8List? _selfieBytes;

  // Quality check metadata
  Size? _frontDimensions;
  Size? _backDimensions;
  Size? _selfieDimensions;

  // Processing state
  String _processingStatus = 'Preparing secure upload...';
  double _processingProgress = 0.15;
  KycVerificationResult? _verificationResult;
  String? _errorMessage;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _pickImageForSlot({
    required String slot,
    required ImageSource source,
  }) async {
    try {
      Uint8List? bytes;

      if (source == ImageSource.camera) {
        final KycCameraMode mode = slot == 'selfie'
            ? KycCameraMode.selfie
            : slot == 'back'
                ? KycCameraMode.cardBack
                : KycCameraMode.cardFront;

        bytes = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (context) => KycCameraViewfinderScreen(
              mode: mode,
              documentTitle: _selectedType.name,
            ),
          ),
        );
      } else {
        final XFile? file = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 92,
        );
        if (file != null) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes == null) return;
      final size = await _inspectDimensions(bytes);

      setState(() {
        if (slot == 'front') {
          _frontBytes = bytes;
          _frontDimensions = size;
        } else if (slot == 'back') {
          _backBytes = bytes;
          _backDimensions = size;
        } else if (slot == 'selfie') {
          _selfieBytes = bytes;
          _selfieDimensions = size;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not access image: $e'),
          backgroundColor: AuraColors.primary,
        ),
      );
    }
  }

  Future<Size> _inspectDimensions(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (_) {
      return const Size(1280, 720);
    }
  }

  void _proceedFromIdSelection() {
    setState(() {
      _currentStep = KycStep.captureFront;
    });
  }

  void _proceedFromFrontCapture() {
    if (_frontBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture the front of your document to continue.'),
          backgroundColor: AuraColors.primary,
        ),
      );
      return;
    }

    if (_selectedType.requiresBack) {
      setState(() {
        _currentStep = KycStep.captureBack;
      });
    } else {
      setState(() {
        _currentStep = KycStep.captureSelfie;
      });
    }
  }

  void _proceedFromBackCapture() {
    if (_backBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture the back of your document to continue.'),
          backgroundColor: AuraColors.primary,
        ),
      );
      return;
    }

    setState(() {
      _currentStep = KycStep.captureSelfie;
    });
  }

  Future<void> _submitVerificationFlow() async {
    if (_selfieBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture your selfie to proceed.'),
          backgroundColor: AuraColors.primary,
        ),
      );
      return;
    }

    setState(() {
      _currentStep = KycStep.processing;
      _processingStatus = 'Requesting secure upload authorization...';
      _processingProgress = 0.25;
      _errorMessage = null;
    });

    try {
      // 1. Request SAS Upload Intent
      final intent = await _kycService.requestUploadIntent(
        idType: _selectedType.code,
        requireBack: _selectedType.requiresBack,
      );

      if (intent == null) {
        throw Exception('Failed to obtain secure upload token. Please check your network connection.');
      }

      // 2. Direct binary upload of front ID
      setState(() {
        _processingStatus = 'Uploading identity document...';
        _processingProgress = 0.45;
      });

      final frontSuccess = await _kycService.uploadBlob(
        uploadUrl: intent.frontSlot.uploadUrl,
        bytes: _frontBytes!,
      );

      if (!frontSuccess) {
        throw Exception('Failed to upload document front. Please retry.');
      }

      // 3. Upload back ID if required
      if (_selectedType.requiresBack && intent.backSlot != null && _backBytes != null) {
        setState(() {
          _processingStatus = 'Uploading document back...';
          _processingProgress = 0.65;
        });

        final backSuccess = await _kycService.uploadBlob(
          uploadUrl: intent.backSlot!.uploadUrl,
          bytes: _backBytes!,
        );

        if (!backSuccess) {
          throw Exception('Failed to upload document back. Please retry.');
        }
      }

      // 4. Upload Selfie
      setState(() {
        _processingStatus = 'Uploading verification photo...';
        _processingProgress = 0.80;
      });

      final selfieSuccess = await _kycService.uploadBlob(
        uploadUrl: intent.selfieSlot.uploadUrl,
        bytes: _selfieBytes!,
      );

      if (!selfieSuccess) {
        throw Exception('Failed to upload verification photo. Please retry.');
      }

      // 5. Trigger automated verification
      setState(() {
        _processingStatus = 'Verifying identity records...';
        _processingProgress = 0.95;
      });

      final user = BankService().user;
      final result = await _kycService.verifySubmission(
        submissionId: intent.submissionId,
        idType: _selectedType.code,
        declaredName: user.name,
        declaredDob: user.dob,
      );

      setState(() {
        _verificationResult = result;
        _processingProgress = 1.0;
        _currentStep = KycStep.verdict;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _currentStep = KycStep.verdict;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AuraColors.textPrimary),
          onPressed: () {
            if (_currentStep == KycStep.captureBack) {
              setState(() => _currentStep = KycStep.captureFront);
            } else if (_currentStep == KycStep.captureFront) {
              setState(() => _currentStep = KycStep.selectIdType);
            } else if (_currentStep == KycStep.captureSelfie) {
              setState(() => _currentStep = _selectedType.requiresBack ? KycStep.captureBack : KycStep.captureFront);
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Row(
          children: [
            AuraLogo(size: 28, style: AuraLogoStyle.violet, borderRadius: 8),
            SizedBox(width: 10),
            Text(
              'Identity Verification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AuraColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AuraColors.cardBorder, height: 1),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStepView(),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case KycStep.selectIdType:
        return _buildSelectIdTypeStep();
      case KycStep.captureFront:
        return _buildCaptureFrontStep();
      case KycStep.captureBack:
        return _buildCaptureBackStep();
      case KycStep.captureSelfie:
        return _buildCaptureSelfieStep();
      case KycStep.processing:
        return _buildProcessingStep();
      case KycStep.verdict:
        return _buildVerdictStep();
    }
  }

  // STEP 1: Select ID Type
  Widget _buildSelectIdTypeStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_select_id'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AuraColors.tintPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Step 1 of 3',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AuraColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose your document',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Select an official Philippine government ID to verify your banking profile.',
            style: TextStyle(
              fontSize: 13.5,
              color: AuraColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...KycDocumentType.supportedTypes.map((type) {
            final isSelected = _selectedType.code == type.code;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected ? AuraColors.bgLavender : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AuraColors.accent : AuraColors.cardBorder,
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: AuraColors.cardShadow,
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedType = type;
                    _frontBytes = null;
                    _backBytes = null;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected ? AuraColors.tintPurple : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          type.code == 'PASSPORT'
                              ? Icons.menu_book_rounded
                              : Icons.badge_outlined,
                          color: isSelected ? AuraColors.primary : AuraColors.textSecondary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? AuraColors.primary : AuraColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              type.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AuraColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: type.requiresBack
                                    ? const Color(0xFFEEF2F6)
                                    : const Color(0xFFE6F8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                type.requiresBack ? 'Front and back required' : 'Front page only',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: type.requiresBack
                                      ? AuraColors.textSecondary
                                      : AuraColors.creditGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                        color: isSelected ? AuraColors.primary : const Color(0xFFD1D5DB),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AuraColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _proceedFromIdSelection,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue to Document Capture',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // STEP 2: Capture Front ID
  Widget _buildCaptureFrontStep() {
    return _buildDocumentCaptureLayout(
      stepTitle: 'Step 2 of 3',
      heading: 'Front of ${_selectedType.name}',
      description: 'Position the front of your document inside the card frame. Keep it flat and avoid glare.',
      bytes: _frontBytes,
      dimensions: _frontDimensions,
      onPickCamera: () => _pickImageForSlot(slot: 'front', source: ImageSource.camera),
      onPickGallery: () => _pickImageForSlot(slot: 'front', source: ImageSource.gallery),
      onRetake: () => setState(() => _frontBytes = null),
      onContinue: _proceedFromFrontCapture,
      continueLabel: _selectedType.requiresBack ? 'Continue to Document Back' : 'Continue to Selfie',
    );
  }

  // STEP 3: Capture Back ID (if required)
  Widget _buildCaptureBackStep() {
    return _buildDocumentCaptureLayout(
      stepTitle: 'Step 2 of 3 (Back)',
      heading: 'Back of ${_selectedType.name}',
      description: 'Turn your card over and align the back inside the frame. Ensure the barcode or serial is visible.',
      bytes: _backBytes,
      dimensions: _backDimensions,
      onPickCamera: () => _pickImageForSlot(slot: 'back', source: ImageSource.camera),
      onPickGallery: () => _pickImageForSlot(slot: 'back', source: ImageSource.gallery),
      onRetake: () => setState(() => _backBytes = null),
      onContinue: _proceedFromBackCapture,
      continueLabel: 'Continue to Selfie',
    );
  }

  // Helper: Card CR80 Viewfinder and Capture Options
  Widget _buildDocumentCaptureLayout({
    required String stepTitle,
    required String heading,
    required String description,
    required Uint8List? bytes,
    required Size? dimensions,
    required VoidCallback onPickCamera,
    required VoidCallback onPickGallery,
    required VoidCallback onRetake,
    required VoidCallback onContinue,
    required String continueLabel,
  }) {
    final bool hasImage = bytes != null;
    final bool isLowRes = dimensions != null && (min(dimensions.width, dimensions.height) < 720);

    return SingleChildScrollView(
      key: ValueKey(heading),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AuraColors.tintPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              stepTitle,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AuraColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            heading,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              color: AuraColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // CR80 Aspect Ratio (1.586 : 1) Card Viewfinder
          AspectRatio(
            aspectRatio: 1.586,
            child: Container(
              decoration: BoxDecoration(
                color: hasImage ? Colors.black : const Color(0xFF1E1B4B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasImage ? AuraColors.creditGreen : AuraColors.accentLight,
                  width: 2.0,
                ),
                boxShadow: AuraColors.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.memory(bytes, fit: BoxFit.cover)
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.crop_free_rounded,
                            size: 52,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Align card edges here',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Format: ${_selectedType.sampleFormat}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),

                    // Card Framing Markers (Corner Brackets)
                    CustomPaint(
                      painter: _CardViewfinderPainter(
                        color: hasImage ? AuraColors.creditGreen : Colors.white,
                      ),
                    ),

                    if (hasImage)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, color: AuraColors.creditGreen, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Captured',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (isLowRes) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AuraColors.amberWarning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Image resolution is lower than recommended. Ensure good lighting and hold the card closer for crisp detail.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          if (!hasImage) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onPickCamera,
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraColors.textPrimary,
                        side: const BorderSide(color: AuraColors.cardBorder, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onPickGallery,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Upload File', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraColors.textPrimary,
                        side: const BorderSide(color: AuraColors.cardBorder, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onRetake,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retake', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: onContinue,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              continueLabel,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // STEP 4: Live Selfie Capture with Oval Frame
  Widget _buildCaptureSelfieStep() {
    final bool hasImage = _selfieBytes != null;
    final bool isLowRes = _selfieDimensions != null && (min(_selfieDimensions!.width, _selfieDimensions!.height) < 720);

    return SingleChildScrollView(
      key: const ValueKey('step_capture_selfie'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AuraColors.tintPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Step 3 of 3',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AuraColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Take a quick selfie',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Center your face inside the oval frame. Remove hats or tinted glasses and maintain a neutral expression.',
            style: TextStyle(
              fontSize: 13.5,
              color: AuraColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Selfie Oval Alignment Frame
          Center(
            child: Container(
              width: 240,
              height: 310,
              decoration: BoxDecoration(
                color: hasImage ? Colors.black : const Color(0xFF1E1B4B),
                borderRadius: BorderRadius.all(Radius.elliptical(120, 155)),
                border: Border.all(
                  color: hasImage ? AuraColors.creditGreen : AuraColors.accentLight,
                  width: 3.0,
                ),
                boxShadow: AuraColors.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.elliptical(120, 155)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      Image.memory(_selfieBytes!, fit: BoxFit.cover)
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Center Face in Oval',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Good lighting required',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (isLowRes) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AuraColors.amberWarning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Photo resolution is low. Please take the selfie in bright lighting without glare.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          if (!hasImage) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _pickImageForSlot(slot: 'selfie', source: ImageSource.camera),
                      icon: const Icon(Icons.camera_front_rounded, size: 20),
                      label: const Text('Open Front Camera', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AuraColors.textPrimary,
                      side: const BorderSide(color: AuraColors.cardBorder, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _pickImageForSlot(slot: 'selfie', source: ImageSource.gallery),
                    child: const Icon(Icons.photo_library_outlined, size: 20),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraColors.textPrimary,
                        side: const BorderSide(color: AuraColors.cardBorder, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => setState(() => _selfieBytes = null),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retake', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 6,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AuraColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _submitVerificationFlow,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Confirm & Submit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                          SizedBox(width: 8),
                          Icon(Icons.check_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // STEP 5: Processing View
  Widget _buildProcessingStep() {
    return Center(
      key: const ValueKey('step_processing'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AuraColors.tintPurple,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: AuraColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Verifying Your Identity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AuraColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _processingStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AuraColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _processingProgress,
                backgroundColor: const Color(0xFFE5E7EB),
                color: AuraColors.primary,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This usually takes about 5 to 10 seconds.',
              style: TextStyle(fontSize: 11.5, color: AuraColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 6: Instant Verdict View
  Widget _buildVerdictStep() {
    if (_errorMessage != null) {
      return _buildVerdictCard(
        isSuccess: false,
        isPending: false,
        title: 'Verification Incomplete',
        subtitle: _errorMessage!,
        reasons: const ['Network connection or server error occurred during processing.'],
        primaryButtonText: 'Try Again',
        onPrimaryPressed: () {
          setState(() {
            _currentStep = KycStep.selectIdType;
            _errorMessage = null;
          });
        },
      );
    }

    final result = _verificationResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    if (result.isApproved) {
      return _buildVerdictCard(
        isSuccess: true,
        isPending: false,
        title: 'Identity Verified',
        subtitle: 'Your identity has been verified successfully. Your account is now active with full banking privileges.',
        reasons: const [
          'High transfer limits unlocked',
          'Physical debit card ordering active',
          'Full digital banking access',
        ],
        primaryButtonText: 'Return to Profile',
        onPrimaryPressed: () {
          widget.onCompleted?.call();
          Navigator.of(context).pop();
        },
      );
    } else if (result.isPendingReview) {
      return _buildVerdictCard(
        isSuccess: false,
        isPending: true,
        title: 'Under Review',
        subtitle: 'We have securely received your documents. Our team is conducting a final verification check.',
        reasons: result.reasons.isNotEmpty
            ? result.reasons
            : const ['Your submission is currently in the compliance review queue. You will receive a notification once verified.'],
        primaryButtonText: 'Done',
        onPrimaryPressed: () {
          widget.onCompleted?.call();
          Navigator.of(context).pop();
        },
      );
    } else {
      return _buildVerdictCard(
        isSuccess: false,
        isPending: false,
        title: 'Verification Needs Attention',
        subtitle: result.message.isNotEmpty
            ? result.message
            : 'We were unable to automatically verify your documents. Please ensure clear lighting and valid documents.',
        reasons: result.reasons,
        primaryButtonText: 'Retry Verification',
        onPrimaryPressed: () {
          setState(() {
            _currentStep = KycStep.selectIdType;
            _frontBytes = null;
            _backBytes = null;
            _selfieBytes = null;
            _verificationResult = null;
          });
        },
      );
    }
  }

  Widget _buildVerdictCard({
    required bool isSuccess,
    required bool isPending,
    required String title,
    required String subtitle,
    required List<String> reasons,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
  }) {
    final Color badgeColor = isSuccess
        ? AuraColors.creditGreenBg
        : (isPending ? const Color(0xFFFEF3C7) : AuraColors.debitRedBg);
    final Color iconColor = isSuccess
        ? AuraColors.creditGreen
        : (isPending ? AuraColors.amberWarning : AuraColors.debitRed);
    final IconData icon = isSuccess
        ? Icons.check_circle_rounded
        : (isPending ? Icons.hourglass_top_rounded : Icons.error_outline_rounded);

    return SingleChildScrollView(
      key: ValueKey(title),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: AuraColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AuraColors.cardBorder),
                boxShadow: AuraColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: reasons.map((r) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isSuccess
                              ? Icons.check_rounded
                              : (isPending ? Icons.info_outline_rounded : Icons.close_rounded),
                          size: 16,
                          color: iconColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AuraColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AuraColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onPrimaryPressed,
              child: Text(
                primaryButtonText,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Custom painter for CR80 card viewfinder frame corners
class _CardViewfinderPainter extends CustomPainter {
  final Color color;

  _CardViewfinderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;
    const padding = 12.0;

    // Top-left
    canvas.drawLine(const Offset(padding, padding + cornerLength), const Offset(padding, padding), paint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLength, padding), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - padding - cornerLength, padding), Offset(size.width - padding, padding), paint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding, padding + cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(padding, size.height - padding - cornerLength), Offset(padding, size.height - padding), paint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLength, size.height - padding), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - padding - cornerLength, size.height - padding), Offset(size.width - padding, size.height - padding), paint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding, size.height - padding - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _CardViewfinderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
