import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import 'receipt_screen.dart';

class FaceIdVerificationScreen extends StatefulWidget {
  final String senderName;
  final String senderAccount;
  final String recipientName;
  final String recipientAccount;
  final String recipientBank;
  final double amount;
  final double fee;
  final String? remarks;
  final bool autoAuthenticate;

  const FaceIdVerificationScreen({
    super.key,
    required this.senderName,
    required this.senderAccount,
    required this.recipientName,
    required this.recipientAccount,
    required this.recipientBank,
    required this.amount,
    this.fee = 0.0,
    this.remarks,
    this.autoAuthenticate = false,
  });

  @override
  State<FaceIdVerificationScreen> createState() => _FaceIdVerificationScreenState();
}

class _FaceIdVerificationScreenState extends State<FaceIdVerificationScreen>
    with SingleTickerProviderStateMixin {
  final BankService _bankService = BankService();

  // Aura Bank Brand Colors
  static const Color brandPrimary = AuraColors.primary; // 0xFF380084
  static const Color brandAccent = Color(0xFF7C3AED); // Electric Purple
  static const Color darkBg = Color(0xFF0D0820); // Deep Midnight Violet
  static const Color surfaceCard = Color(0xFF160F2E); // Elevated Card Surface
  static const Color surfaceBorder = Color(0xFF2C1C54); // Subtle Card Border
  static const Color textMuted = Color(0xFF94A3B8); // Slate Muted
  static const Color greenSuccess = Color(0xFF10B981); // Emerald Verified

  bool _isVerifying = false;
  bool _isSuccess = false;
  double _progressValue = 0.2;
  Timer? _progressTimer;
  late AnimationController _laserController;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    if (widget.autoAuthenticate) {
      _startVerificationFlow();
    }
  }

  void _startVerificationFlow() {
    if (_isSuccess || _isVerifying) return;
    setState(() {
      _isVerifying = true;
      _progressValue = 0.2;
    });
    _laserController.repeat(reverse: true);
    _startVerificationProgress();
  }

  void _startVerificationProgress() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue += 0.08;
        if (_progressValue >= 1.0) {
          _progressValue = 1.0;
          timer.cancel();
          _onVerificationComplete();
        }
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _onVerificationComplete() async {
    if (_isSuccess) return;
    _progressTimer?.cancel();
    _laserController.stop();

    setState(() {
      _isVerifying = false;
      _isSuccess = true;
      _progressValue = 1.0;
    });

    // Brief verification feedback
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final result = await _bankService.executeTransfer(
      targetAccount: widget.recipientAccount,
      recipientName: widget.recipientName,
      amount: widget.amount,
      destinationBank: widget.recipientBank,
      remarks: widget.remarks,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => TransactionReceiptScreen(
          isSuccess: result['success'] == true,
          senderName: widget.senderName,
          senderAccount: widget.senderAccount,
          recipientName: widget.recipientName,
          recipientAccount: widget.recipientAccount,
          recipientBank: widget.recipientBank,
          amount: widget.amount,
          fee: widget.fee,
          referenceNumber: result['reference'] ?? 'AUR-990123',
          failureReason: result['success'] == true
              ? null
              : (result['message'] as String? ?? 'Destination Bank Timeout'),
          onTryAgain: () => Navigator.of(context).pop(),
          onBackToHome: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ),
    );
  }

  void _triggerManualAuth() {
    _startVerificationFlow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Navigation Header
                  _buildHeader(),

                  const SizedBox(height: 14),

                  // Pill Badge: "Authorize with Face ID"
                  _buildBiometricBadge(),

                  const SizedBox(height: 18),

                  // 1. Realistic Apple Face ID Camera Viewfinder (Reduced Neon, Realistic Face Silhouette)
                  _buildRealisticFaceIdViewfinder(),

                  const SizedBox(height: 18),

                  // 2. Simplified Banking Status & Messaging
                  Text(
                    _isSuccess ? 'Face ID Verified!' : 'Face ID Verification',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    _isSuccess
                        ? 'Transaction authorized. Generating receipt...'
                        : (_isVerifying
                            ? 'Scanning Face...'
                            : 'Position your face within the frame'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: _isVerifying ? FontWeight.w700 : FontWeight.w500,
                      color: _isVerifying ? const Color(0xFFC084FC) : textMuted,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 3. Prioritized Transaction Details Card (Apple Pay Pattern)
                  _buildTransactionDetailsCard(),

                  const SizedBox(height: 24),

                  // 4. Action Buttons (Aura Bank Primary Violet CTA)
                  _buildActionButtons(),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: surfaceCard,
            shape: BoxShape.circle,
            border: Border.all(color: surfaceBorder, width: 1.0),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Aura Bank',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 42),
      ],
    );
  }

  Widget _buildBiometricBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceBorder, width: 1.0),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.face_retouching_natural_rounded, color: Color(0xFFC084FC), size: 16),
          SizedBox(width: 6),
          Text(
            'Authorize with Face ID',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE9D5FF),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Prioritized banking transaction card (Apple Pay / Revolut pattern)
  Widget _buildTransactionDetailsCard() {
    final recipient = widget.recipientName.isNotEmpty ? widget.recipientName : 'Jessie Mae Dela Paz';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaceBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Paying To',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recipient,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: surfaceBorder, height: 1, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Amount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'PHP ${_formatAmount(widget.amount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFC084FC),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Realistic Apple Face ID Viewfinder with fine optical brackets and real face silhouette
  Widget _buildRealisticFaceIdViewfinder() {
    return GestureDetector(
      onTap: _triggerManualAuth,
      child: Container(
        width: 210,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(
            colors: [Color(0xFF191033), Color(0xFF0F0822)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: _isSuccess
                ? greenSuccess
                : (_isVerifying ? brandAccent : const Color(0xFF3B2276)),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isSuccess ? greenSuccess : brandPrimary).withValues(alpha: _isSuccess ? 0.35 : 0.2),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Subtle Optical Camera Viewport Vignette & Grid
              Positioned.fill(
                child: CustomPaint(
                  painter: _OpticalCameraVignettePainter(
                    isSuccess: _isSuccess,
                    isVerifying: _isVerifying,
                  ),
                ),
              ),

              // 2. Apple Face ID Corner Alignment Brackets
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CustomPaint(
                    painter: _AppleFaceIdCornersPainter(
                      color: _isSuccess
                          ? greenSuccess
                          : (_isVerifying ? const Color(0xFFE9D5FF) : const Color(0xFFA78BFA)),
                    ),
                  ),
                ),
              ),

              // 3. Realistic Biometric Face Silhouette Guide (Fine, Natural Anatomy Lines)
              if (!_isSuccess)
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(140, 150),
                      painter: _RealisticFaceSilhouettePainter(
                        scanProgress: _laserController.value,
                        isVerifying: _isVerifying,
                      ),
                    );
                  },
                ),

              // 4. Success Overlay Checkmark (Apple Pay Style)
              if (_isSuccess)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: greenSuccess.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: greenSuccess, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: greenSuccess.withValues(alpha: 0.4),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: greenSuccess,
                      size: 44,
                    ),
                  ),
                ),

              // 5. Sleek Optical Scanning Bar (Subtle & Clean, Not Blinding Neon)
              if (!_isSuccess && _isVerifying)
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, child) {
                    final factor = _laserController.value;
                    return Positioned(
                      top: 28 + (155 * factor),
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 2.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFFE9D5FF),
                              Colors.white,
                              Color(0xFFE9D5FF),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF7C3AED),
                              blurRadius: 8,
                              spreadRadius: 1.0,
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
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Primary CTA: Solid Aura Royal Violet matching main app theme
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: brandPrimary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: brandPrimary.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: (_isSuccess || _isVerifying) ? null : _triggerManualAuth,
            icon: Icon(
              _isSuccess
                  ? Icons.check_circle_rounded
                  : (_isVerifying
                      ? Icons.sync_rounded
                      : Icons.face_retouching_natural_rounded),
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              _isSuccess
                  ? 'Verified'
                  : (_isVerifying ? 'Authorizing...' : 'Authorize Face ID'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary CTA: Cancel
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: surfaceCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: surfaceBorder, width: 1.0),
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '$intPart.${parts[1]}';
  }
}

/// Subtle optical camera vignette & target crosshairs (Apple Pay style)
class _OpticalCameraVignettePainter extends CustomPainter {
  final bool isSuccess;
  final bool isVerifying;

  _OpticalCameraVignettePainter({
    required this.isSuccess,
    required this.isVerifying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Subtle optical lens guide ring
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: isVerifying ? 0.08 : 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(cx, cy), 65, ringPaint);

    // Fine center alignment tick marks
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), tickPaint);
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 6), tickPaint);
  }

  @override
  bool shouldRepaint(covariant _OpticalCameraVignettePainter oldDelegate) =>
      oldDelegate.isSuccess != isSuccess || oldDelegate.isVerifying != isVerifying;
}

/// Clean Apple Face ID 4 corner brackets
class _AppleFaceIdCornersPainter extends CustomPainter {
  final Color color;

  _AppleFaceIdCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const l = 24.0;
    const r = 12.0;

    // Top-Left
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: const Radius.circular(r))
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r))
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _AppleFaceIdCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Realistic, elegant face silhouette outline with eye alignment markers (Apple Face ID pattern)
class _RealisticFaceSilhouettePainter extends CustomPainter {
  final double scanProgress;
  final bool isVerifying;

  _RealisticFaceSilhouettePainter({
    required this.scanProgress,
    required this.isVerifying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final lineColor = isVerifying
        ? const Color(0xFFC084FC).withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.28);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // 1. Natural Head / Face Oval Contour
    final headRect = Rect.fromCenter(
      center: Offset(cx, cy - 4),
      width: 86,
      height: 114,
    );
    canvas.drawOval(headRect, linePaint);

    // 2. Eyebrow Guides
    final browPaint = Paint()
      ..color = lineColor.withValues(alpha: isVerifying ? 0.7 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final leftBrow = Path()
      ..moveTo(cx - 28, cy - 18)
      ..quadraticBezierTo(cx - 19, cy - 22, cx - 10, cy - 19);
    canvas.drawPath(leftBrow, browPaint);

    final rightBrow = Path()
      ..moveTo(cx + 10, cy - 19)
      ..quadraticBezierTo(cx + 19, cy - 22, cx + 28, cy - 18);
    canvas.drawPath(rightBrow, browPaint);

    // 3. Eye Target Reticles (Refined Apple Face ID crosses)
    final eyePaint = Paint()
      ..color = isVerifying ? Colors.white.withValues(alpha: 0.85) : lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    void drawEye(double x, double y) {
      canvas.drawCircle(Offset(x, y), 4.5, eyePaint);
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        Paint()
          ..color = isVerifying ? Colors.white : lineColor
          ..style = PaintingStyle.fill,
      );
    }

    drawEye(cx - 17, cy - 9);
    drawEye(cx + 17, cy - 9);

    // 4. Nose Bridge & Tip Guide
    final nosePath = Path()
      ..moveTo(cx, cy - 10)
      ..lineTo(cx, cy + 6)
      ..quadraticBezierTo(cx, cy + 11, cx - 4, cy + 11)
      ..quadraticBezierTo(cx, cy + 13, cx + 4, cy + 11);
    canvas.drawPath(nosePath, browPaint);

    // 5. Lip / Mouth Guide
    final mouthPath = Path()
      ..moveTo(cx - 13, cy + 25)
      ..quadraticBezierTo(cx, cy + 28, cx + 13, cy + 25);
    canvas.drawPath(mouthPath, browPaint);
  }

  @override
  bool shouldRepaint(covariant _RealisticFaceSilhouettePainter oldDelegate) =>
      oldDelegate.scanProgress != scanProgress ||
      oldDelegate.isVerifying != isVerifying;
}
