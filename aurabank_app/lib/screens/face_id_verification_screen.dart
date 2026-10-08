import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import 'login_page_face_id.dart' show FaceIdIcon;
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
  });

  @override
  State<FaceIdVerificationScreen> createState() => _FaceIdVerificationScreenState();
}

class _FaceIdVerificationScreenState extends State<FaceIdVerificationScreen> {
  final BankService _bankService = BankService();

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color greenSuccess = Color(0xFF10B981);

  bool _isVerifying = false;
  bool _isSuccess = false;

  Future<void> _handleAuthorize() async {
    if (_isVerifying || _isSuccess) return;

    setState(() {
      _isVerifying = true;
    });

    // Realistic biometric scanning handshake
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _isSuccess = true;
    });

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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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

                  const SizedBox(height: 28),

                  // Centerpiece Scanner Display
                  _buildScannerCard(),

                  const SizedBox(height: 24),

                  // Transfer Recap Capsule
                  _buildTransferDetailsCard(),

                  const SizedBox(height: 32),

                  // Action Buttons
                  _buildActionButtons(),

                  const SizedBox(height: 24),
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
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: cardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: textDark),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Face ID Verification',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        const SizedBox(width: 42),
      ],
    );
  }

  Widget _buildScannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Glowing Sensor
          GestureDetector(
            onTap: _handleAuthorize,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSuccess
                    ? greenSuccess.withValues(alpha: 0.12)
                    : brandViolet.withValues(alpha: 0.08),
                border: Border.all(
                  color: _isSuccess ? greenSuccess : brandViolet.withValues(alpha: 0.35),
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isSuccess ? greenSuccess : brandViolet).withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: _isSuccess
                    ? const Icon(Icons.check_circle_rounded, color: greenSuccess, size: 68)
                    : _isVerifying
                        ? const SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              strokeWidth: 4.0,
                              color: brandViolet,
                            ),
                          )
                        : const FaceIdIcon(
                            size: 78,
                            backgroundColor: Colors.transparent,
                            color: brandViolet,
                          ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            _isSuccess
                ? 'Face ID Verified!'
                : (_isVerifying ? 'Scanning Face...' : 'Authorize with Face ID'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textDark,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            _isSuccess
                ? 'Identity confirmed. Processing transfer...'
                : 'Position your face to confirm transfer authorization',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Recipient Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recipient',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          ),

          // Destination Bank Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Destination',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.recipientBank} • ${widget.recipientAccount}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
          ),

          // Total Transfer Amount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textDark,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: brandViolet,
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
        // Primary CTA: Authorize Face ID
        Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: brandViolet,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: brandViolet.withValues(alpha: 0.35),
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
            onPressed: _isVerifying || _isSuccess ? null : _handleAuthorize,
            icon: Icon(
              _isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.face_retouching_natural_rounded,
              color: Colors.white,
              size: 22,
            ),
            label: Text(
              _isVerifying
                  ? 'Verifying...'
                  : (_isSuccess ? 'Verified' : 'Authorize Face ID'),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
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
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextButton(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _isVerifying || _isSuccess ? null : () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textMuted,
                letterSpacing: 0.2,
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
