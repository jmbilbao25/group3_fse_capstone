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

  static const Color brandViolet = AuraColors.primary;
  static const Color neonViolet = Color(0xFFA855F7);
  static const Color neonLight = Color(0xFFC084FC);
  static const Color greenSuccess = Color(0xFF10B981);
  static const Color darkBg = Color(0xFF0C071E);

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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Navigation Header
                  _buildHeader(),

                  const SizedBox(height: 18),

                  // Pill Badge: "Authorize with Face ID"
                  _buildBiometricBadge(),

                  const SizedBox(height: 22),

                  // Centerpiece Neon Face ID Squircle Box
                  _buildNeonScannerCard(),

                  const SizedBox(height: 24),

                  // Title: "Face ID Verification"
                  Text(
                    _isSuccess ? 'Face ID Verified!' : 'Face ID Verification',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle: "Position your face within the frame" or "Scanning Face..."
                  Text(
                    _isSuccess
                        ? 'Transfer authorized. Generating receipt...'
                        : (_isVerifying
                            ? 'Scanning Face...'
                            : 'Position your face within the frame'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _isVerifying ? FontWeight.w700 : FontWeight.w500,
                      color: _isVerifying ? neonLight : const Color(0xFF94A3B8),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sleek Animated Progress Bar
                  _buildProgressBar(),

                  const SizedBox(height: 26),

                  // Transaction Summary Capsule
                  _buildTransferDetailsCapsule(),

                  const SizedBox(height: 26),

                  // Action Buttons
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

  Widget _buildBiometricBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1538),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B2276), width: 1.0),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.face_retouching_natural_rounded, color: neonLight, size: 16),
          SizedBox(width: 6),
          Text(
            'Authorize with Face ID',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: neonLight,
              letterSpacing: 0.2,
            ),
          ),
        ],
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
            color: const Color(0xFF1E1538),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF3B2276), width: 1.0),
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
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 42),
      ],
    );
  }

  Widget _buildNeonScannerCard() {
    return GestureDetector(
      onTap: _triggerManualAuth,
      child: Container(
        width: 250,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: const LinearGradient(
            colors: [Color(0xFF150D32), Color(0xFF0F0826)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: _isSuccess ? greenSuccess : neonViolet,
            width: 3.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (_isSuccess ? greenSuccess : neonViolet).withValues(alpha: 0.55),
              blurRadius: 36,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: (_isSuccess ? greenSuccess : brandViolet).withValues(alpha: 0.35),
              blurRadius: 60,
              spreadRadius: 6,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(33),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Corner Brackets
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: CustomPaint(
                    painter: _NeonCornerBracketsPainter(
                      color: _isSuccess ? greenSuccess : neonLight,
                    ),
                  ),
                ),
              ),

              // 3D Biometric Facial Mesh Painter (No static image)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _BiometricFaceMeshPainter(
                        scanProgress: _laserController.value,
                        isVerifying: _isVerifying,
                        isSuccess: _isSuccess,
                        primaryColor: brandViolet,
                        accentColor: neonViolet,
                      ),
                    );
                  },
                ),
              ),

              // Top HUD Telemetry Pill
              Positioned(
                top: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0826).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isSuccess
                          ? greenSuccess.withValues(alpha: 0.6)
                          : (_isVerifying
                              ? neonLight.withValues(alpha: 0.7)
                              : const Color(0xFF3B2276)),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? greenSuccess
                              : (_isVerifying ? const Color(0xFF00E676) : neonLight),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSuccess
                            ? 'MATCH CONFIRMED'
                            : (_isVerifying ? 'BIOMETRIC SCANNING' : 'FACIAL GEOMETRY LOCK'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _isSuccess
                              ? greenSuccess
                              : (_isVerifying ? Colors.white : const Color(0xFF94A3B8)),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom HUD Coordinates
              Positioned(
                bottom: 14,
                child: Text(
                  _isSuccess
                      ? 'ID: AUR-BIO-PASS'
                      : (_isVerifying ? 'NODES: 38/38 LOCKED' : 'TARGET: CENTER FACE'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _isSuccess
                        ? greenSuccess.withValues(alpha: 0.9)
                        : const Color(0xFF94A3B8).withValues(alpha: 0.8),
                    letterSpacing: 0.6,
                  ),
                ),
              ),

              // Success Overlay Checkmark
              if (_isSuccess)
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: greenSuccess.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: greenSuccess, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: greenSuccess.withValues(alpha: 0.5),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: greenSuccess,
                      size: 48,
                    ),
                  ),
                ),

              // Animated Laser Beam
              if (!_isSuccess)
                AnimatedBuilder(
                  animation: _laserController,
                  builder: (context, child) {
                    final factor = _laserController.value;
                    return Positioned(
                      top: 36 + (170 * factor),
                      left: 18,
                      right: 18,
                      child: Container(
                        height: 2.8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFFE9D5FF),
                              Color(0xFFFFFFFF),
                              Color(0xFFE9D5FF),
                              Colors.transparent,
                            ],
                            stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: neonViolet.withValues(alpha: 0.9),
                              blurRadius: 12,
                              spreadRadius: 2.0,
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

  Widget _buildProgressBar() {
    return Container(
      width: 220,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF26194F),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: _progressValue.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                colors: _isSuccess
                    ? [greenSuccess, const Color(0xFF34D399)]
                    : [const Color(0xFF9333EA), neonViolet],
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isSuccess ? greenSuccess : neonViolet).withValues(alpha: 0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferDetailsCapsule() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF180F33).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF361E68), width: 1.2),
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
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.recipientName.isNotEmpty ? widget.recipientName : 'Jessie Mae Dela Paz',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFF2B1854), height: 1, thickness: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  'PHP ${_formatAmount(widget.amount)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: neonLight,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Tap to Authorize Button
        Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
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
        // Cancel Button
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF180F33),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF361E68), width: 1.0),
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
                color: Color(0xFF94A3B8),
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

class _NeonCornerBracketsPainter extends CustomPainter {
  final Color color;

  _NeonCornerBracketsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    const l = 28.0;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BiometricFaceMeshPainter extends CustomPainter {
  final double scanProgress;
  final bool isVerifying;
  final bool isSuccess;
  final Color primaryColor;
  final Color accentColor;

  _BiometricFaceMeshPainter({
    required this.scanProgress,
    required this.isVerifying,
    required this.isSuccess,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final baseColor = isSuccess
        ? const Color(0xFF10B981)
        : (isVerifying ? const Color(0xFFC084FC) : const Color(0xFFA855F7));

    // 1. Concentric Depth Radar Waves (pulsing from center)
    final radarPaint = Paint()
      ..color = baseColor.withValues(alpha: isVerifying ? 0.22 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset(cx, cy), 38 + (scanProgress * 32), radarPaint);
    canvas.drawCircle(Offset(cx, cy), 74, radarPaint..color = baseColor.withValues(alpha: 0.06));

    // 2. Subtle Background Depth Grid Lines
    final gridPaint = Paint()
      ..color = baseColor.withValues(alpha: 0.07)
      ..strokeWidth = 0.8;
    for (double x = cx - 70; x <= cx + 70; x += 18) {
      canvas.drawLine(Offset(x, cy - 80), Offset(x, cy + 80), gridPaint);
    }
    for (double y = cy - 70; y <= cy + 70; y += 18) {
      canvas.drawLine(Offset(cx - 70, y), Offset(cx + 70, y), gridPaint);
    }

    // 3. Facial Landmark Nodes (Mathematical Biometric Coordinates relative to center)
    final nodes = <Offset>[
      // Forehead arc
      Offset(cx - 44, cy - 58),
      Offset(cx - 22, cy - 68),
      Offset(cx, cy - 72),
      Offset(cx + 22, cy - 68),
      Offset(cx + 44, cy - 58),
      // Temples & Cheeks
      Offset(cx - 52, cy - 30),
      Offset(cx - 48, cy + 4),
      Offset(cx - 36, cy + 38),
      Offset(cx + 52, cy - 30),
      Offset(cx + 48, cy + 4),
      Offset(cx + 38, cy + 38),
      // Chin
      Offset(cx - 18, cy + 62),
      Offset(cx, cy + 68),
      Offset(cx + 18, cy + 62),
      // Eyebrows
      Offset(cx - 32, cy - 32),
      Offset(cx - 18, cy - 35),
      Offset(cx - 6, cy - 32),
      Offset(cx + 6, cy - 32),
      Offset(cx + 18, cy - 35),
      Offset(cx + 32, cy - 32),
      // Left Eye Box
      Offset(cx - 24, cy - 18),
      Offset(cx - 12, cy - 18),
      Offset(cx - 18, cy - 22),
      Offset(cx - 18, cy - 14),
      // Right Eye Box
      Offset(cx + 12, cy - 18),
      Offset(cx + 24, cy - 18),
      Offset(cx + 18, cy - 22),
      Offset(cx + 18, cy - 14),
      // Nose Bridge & Tip
      Offset(cx, cy - 22),
      Offset(cx, cy - 6),
      Offset(cx, cy + 8),
      Offset(cx - 10, cy + 12),
      Offset(cx + 10, cy + 12),
      // Lips / Mouth
      Offset(cx - 20, cy + 30),
      Offset(cx, cy + 26),
      Offset(cx + 20, cy + 30),
      Offset(cx, cy + 36),
      Offset(cx - 12, cy + 36),
      Offset(cx + 12, cy + 36),
    ];

    // 4. Connect Landmark Nodes into 3D Polygonal Wireframe Mesh
    final meshLines = <List<int>>[
      // Forehead contour
      [0, 1], [1, 2], [2, 3], [3, 4],
      // Jawline contour
      [0, 5], [5, 6], [6, 7], [7, 11], [11, 12], [12, 13], [13, 10], [10, 9], [9, 8], [8, 4],
      // Forehead to Eyebrows
      [1, 15], [2, 28], [3, 18], [0, 14], [4, 19],
      // Eyebrows to Eyes
      [14, 20], [15, 22], [16, 21], [17, 24], [18, 26], [19, 25],
      // Eye boxes
      [20, 22], [22, 21], [21, 23], [23, 20],
      [24, 26], [26, 25], [25, 27], [27, 24],
      // Nose bridge and cheeks
      [28, 29], [29, 30], [30, 31], [30, 32], [21, 29], [24, 29],
      [20, 5], [25, 8], [31, 6], [32, 9],
      // Nose to mouth
      [31, 33], [30, 34], [32, 35],
      // Mouth contour
      [33, 34], [34, 35], [35, 38], [38, 36], [36, 37], [37, 33],
      // Mouth to chin
      [37, 11], [36, 12], [38, 13],
    ];

    final wirePaint = Paint()
      ..color = baseColor.withValues(alpha: isVerifying ? 0.42 : 0.22)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (final pair in meshLines) {
      if (pair[0] < nodes.length && pair[1] < nodes.length) {
        canvas.drawLine(nodes[pair[0]], nodes[pair[1]], wirePaint);
      }
    }

    // 5. Draw Glowing Landmark Nodes
    final nodePaint = Paint()
      ..color = baseColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final activeNodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Laser current Y position to illuminate nearby nodes
    final laserY = (cy - 85) + (170 * scanProgress);

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final distToLaser = (node.dy - laserY).abs();
      final isNearLaser = distToLaser < 22;

      if (isNearLaser && isVerifying) {
        // Highlighting active nodes scanned by laser
        canvas.drawCircle(node, 3.6, activeNodePaint);
        canvas.drawCircle(
          node,
          7.0,
          Paint()
            ..color = baseColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else {
        canvas.drawCircle(node, 2.0, nodePaint);
      }
    }

    // 6. Eye Crosshair Reticles [ + ]
    final reticlePaint = Paint()
      ..color = (isVerifying ? Colors.white : baseColor).withValues(alpha: 0.85)
      ..strokeWidth = 1.3;

    void drawCrosshair(double x, double y) {
      canvas.drawLine(Offset(x - 5, y), Offset(x + 5, y), reticlePaint);
      canvas.drawLine(Offset(x, y - 5), Offset(x, y + 5), reticlePaint);
      canvas.drawCircle(
        Offset(x, y),
        8,
        Paint()
          ..color = baseColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    drawCrosshair(cx - 18, cy - 18); // Left pupil reticle
    drawCrosshair(cx + 18, cy - 18); // Right pupil reticle

    // 7. Center Nose Targeting Cross
    canvas.drawLine(Offset(cx - 4, cy), Offset(cx + 4, cy), reticlePaint);
    canvas.drawLine(Offset(cx, cy - 4), Offset(cx, cy + 4), reticlePaint);
  }

  @override
  bool shouldRepaint(covariant _BiometricFaceMeshPainter oldDelegate) {
    return oldDelegate.scanProgress != scanProgress ||
        oldDelegate.isVerifying != isVerifying ||
        oldDelegate.isSuccess != isSuccess;
  }
}
