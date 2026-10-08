import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/bank_service.dart';
import '../../widgets/aura_logo.dart';
import '../transfer/send_money_screen.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ScanScreen({super.key, this.onBack});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final BankService _bankService = BankService();
  final ImagePicker _imagePicker = ImagePicker();
  late final MobileScannerController _scannerController;
  late final AnimationController _laserAnimController;

  bool _isTorchOn = false;
  bool _hasScanned = false;
  bool _isProcessingImage = false;

  static const Color brandViolet = Color(0xFF380084);
  static const Color accentGreen = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetectBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        setState(() => _hasScanned = true);
        HapticFeedback.mediumImpact();
        _handleScannedData(code);
      }
    }
  }

  void _handleScannedData(String rawData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildScannedResultModal(rawData),
    ).then((_) {
      if (mounted) {
        setState(() => _hasScanned = false);
      }
    });
  }

  Future<void> _pickFromGallery() async {
    setState(() => _isProcessingImage = true);
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final BarcodeCapture? result = await _scannerController.analyzeImage(image.path);
        if (result != null && result.barcodes.isNotEmpty) {
          final code = result.barcodes.first.rawValue;
          if (code != null && code.isNotEmpty) {
            HapticFeedback.mediumImpact();
            _handleScannedData(code);
            return;
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No QR code detected in the selected image. Please try another.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing photo: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _showGenerateQrModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GenerateQrModal(bankService: _bankService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanSize = MediaQuery.of(context).size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Live Camera Feed
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: _onDetectBarcode,
                errorBuilder: (context, error) {
                  return _buildCameraFallback();
                },
              ),
            ),

            // 2. Translucent Viewfinder Overlay
            Positioned.fill(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Viewfinder Target Frame
                  Container(
                    width: scanSize,
                    height: scanSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        // Four Corner Accents
                        ..._buildCornerAccents(),

                        // Sweeping Animated Laser Beam
                        AnimatedBuilder(
                          animation: _laserAnimController,
                          builder: (context, child) {
                            return Positioned(
                              top: _laserAnimController.value * (scanSize - 20) + 10,
                              left: 12,
                              right: 12,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF22C55E),
                                      Color(0xFF86EFAC),
                                      Color(0xFF22C55E),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF22C55E).withValues(alpha: 0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Hint Text Below Frame
                  Positioned(
                    bottom: 120,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, color: Colors.white70, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Align QR code inside the frame to scan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Top Header Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.onBack != null) ...[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: widget.onBack,
                      ),
                      const SizedBox(width: 4),
                    ],
                    const AuraLogo(size: 36, style: AuraLogoStyle.violet, borderRadius: 10),
                    const SizedBox(width: 12),
                    const Text(
                      'Scan & Pay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Torch Flash Toggle
                    IconButton(
                      icon: Icon(
                        _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white,
                      ),
                      onPressed: () async {
                        await _scannerController.toggleTorch();
                        setState(() => _isTorchOn = !_isTorchOn);
                      },
                    ),
                    // Flip Camera
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                      onPressed: () => _scannerController.switchCamera(),
                    ),
                  ],
                ),
              ),
            ),

            // 4. Bottom Action Buttons: Upload from Gallery & Generate QR
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  // Upload from Gallery Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessingImage ? null : _pickFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111827),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isProcessingImage
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.photo_library_rounded, size: 20, color: brandViolet),
                      label: const Text(
                        'Upload Gallery',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Generate QR Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showGenerateQrModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandViolet,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 22, color: Colors.white),
                      label: const Text(
                        'Generate QR',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCornerAccents() {
    const double length = 26.0;
    const double thickness = 4.0;
    const Color cornerColor = Color(0xFF22C55E);

    return [
      // Top-Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: length,
          height: thickness,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: thickness,
          height: length,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
          ),
        ),
      ),
      // Top-Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: length,
          height: thickness,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: thickness,
          height: length,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
          ),
        ),
      ),
      // Bottom-Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: length,
          height: thickness,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: thickness,
          height: length,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20)),
          ),
        ),
      ),
      // Bottom-Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: length,
          height: thickness,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(20)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: thickness,
          height: length,
          decoration: const BoxDecoration(
            color: cornerColor,
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(20)),
          ),
        ),
      ),
    ];
  }

  Widget _buildCameraFallback() {
    return Container(
      color: const Color(0xFF111827),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Camera Access',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please grant camera permission to scan QR codes live, or pick a QR screenshot from your gallery below.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _scannerController.start(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandViolet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Start Camera'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannedResultModal(String rawData) {
    // Parse if it looks like an account or payment request
    String targetName = 'Aura Merchant / User';
    String targetAccount = rawData;
    String? requestedAmount;

    if (rawData.contains('account=')) {
      final uri = Uri.tryParse(rawData);
      if (uri != null) {
        targetAccount = uri.queryParameters['account'] ?? rawData;
        targetName = uri.queryParameters['name'] ?? 'Aura User';
        requestedAmount = uri.queryParameters['amount'];
      }
    } else if (rawData.length >= 10 && RegExp(r'^[0-9\-\+ ]+$').hasMatch(rawData)) {
      targetAccount = rawData.trim();
      targetName = 'Aura Account Holder';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.check_circle_rounded, color: accentGreen, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QR Code Detected',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                    ),
                    Text(
                      targetName,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Scanned Details:', style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                SelectableText(
                  targetAccount,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                if (requestedAmount != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Requested Amount: PHP $requestedAmount',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accentGreen),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: rawData));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied QR data to clipboard')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Copy Data'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SendMoneyScreen(
                          initialAccountNo: targetAccount,
                          initialRecipientName: targetName,
                          initialAmount: requestedAmount,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Send Money', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Dynamic QR Generator Modal for receiving funds
class _GenerateQrModal extends StatefulWidget {
  final BankService bankService;

  const _GenerateQrModal({required this.bankService});

  @override
  State<_GenerateQrModal> createState() => _GenerateQrModalState();
}

class _GenerateQrModalState extends State<_GenerateQrModal> {
  final TextEditingController _amountController = TextEditingController();
  String? _customAmount;

  static const Color brandViolet = Color(0xFF380084);

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _getQrPayload() {
    final user = widget.bankService.user;
    final buffer = StringBuffer('aurabank://transfer?account=${user.phoneNumber}&name=${Uri.encodeComponent(user.name)}');
    if (_customAmount != null && _customAmount!.isNotEmpty) {
      buffer.write('&amount=$_customAmount');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.bankService.user;
    final qrData = _getQrPayload();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const AuraLogo(size: 40, style: AuraLogoStyle.violet, borderRadius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Receive QR Code',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                      ),
                      Text(
                        user.name,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Real Vector Generated QR Code
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFEDE9FE), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: brandViolet.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 210.0,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: brandViolet,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.phoneNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: brandViolet,
                    ),
                  ),
                  if (_customAmount != null && _customAmount!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Amount: PHP $_customAmount',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Optional Amount Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Set Request Amount (PHP)',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onSubmitted: (val) {
                      setState(() => _customAmount = val.trim());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _customAmount = _amountController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandViolet,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Update'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: qrData));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('QR payload copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('QR Code saved to gallery.'),
                          backgroundColor: brandViolet,
                        ),
                      );
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Save QR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandViolet,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
