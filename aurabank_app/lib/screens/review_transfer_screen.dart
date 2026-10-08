import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import 'login_page_face_id.dart' show FaceIdIcon;
import 'receipt_screen.dart';

class ReviewTransferScreen extends StatefulWidget {
  final String senderName;
  final String senderAccount;
  final String recipientName;
  final String recipientAccount;
  final String recipientBank;
  final double amount;
  final double fee;
  final String? remarks;

  const ReviewTransferScreen({
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
  State<ReviewTransferScreen> createState() => _ReviewTransferScreenState();
}

class _ReviewTransferScreenState extends State<ReviewTransferScreen> {
  final BankService _bankService = BankService();
  bool _isFavorite = false;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color cardBorder = Color(0xFFF1F5F9);
  static const Color greenSuccess = Color(0xFF10B981);

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
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header (Symmetrical 42x42 Back Button + Centered Title)
                  _buildTopHeader(),

                  const SizedBox(height: 18),

                  // Sender & Recipient Flow Card (Image 2 style)
                  _buildSenderRecipientCard(),

                  const SizedBox(height: 16),

                  // Heroic Amount & Transfer Summary Card (Image 2 style)
                  _buildAmountSummaryCard(),

                  const SizedBox(height: 16),

                  // "Add as Favorite" Card
                  _buildFavoriteCard(),

                  const SizedBox(height: 24),

                  // Dual High-Impact Action CTAs (Image 2 style)
                  _buildActionButtons(),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Symmetrical top navigation header with elevated circular back button
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Elevated Back Button
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: textDark),
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Centered Title
          const Text(
            'Review Transfer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textDark,
              letterSpacing: -0.3,
            ),
          ),

          // Symmetrical spacer to guarantee title remains optically centered
          const SizedBox(width: 42, height: 42),
        ],
      ),
    );
  }

  /// Sender & Recipient dossier card matching Image 2 layout
  Widget _buildSenderRecipientCard() {
    final senderDisplay = widget.senderName.trim().isNotEmpty ? widget.senderName : 'Elijah Riley Montefalco';
    final senderAccDisplay = widget.senderAccount.trim().isNotEmpty ? widget.senderAccount : '123256847878';
    final recipientDisplay = widget.recipientName.trim().isNotEmpty ? widget.recipientName : 'Jessie Mae Dela Paz';
    final recipientAccDisplay = widget.recipientAccount.trim().isNotEmpty ? widget.recipientAccount : '154847878751';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sender Section
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: brandViolet,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderDisplay,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Account No. $senderAccDisplay',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Double Arrow Down Directional Transfer Glyph
          const Center(
            child: Icon(
              Icons.keyboard_double_arrow_down_rounded,
              color: Color(0xFF7C3AED),
              size: 26,
            ),
          ),

          const SizedBox(height: 12),

          // Recipient Section
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3E8FF), // Mauve/Lilac background
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: brandViolet,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipientDisplay,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Account No. $recipientAccDisplay',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Heroic Transfer Summary Card matching Image 2 typography
  Widget _buildAmountSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Transfer Amount Line with Heroic Typography
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Amount',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        'PHP ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      Text(
                        _formatAmount(widget.amount),
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Transfer Fee Line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Transfer Fee',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  widget.fee == 0.0 ? 'FREE' : 'PHP ${_formatAmount(widget.fee)}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: widget.fee == 0.0 ? greenSuccess : textDark,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Subtle hairline divider
          const Divider(color: cardBorder, height: 1, thickness: 1),

          const SizedBox(height: 16),

          // Total Amount Line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    'PHP ${_formatAmount(widget.amount + widget.fee)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textDark,
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

  /// "Add as Favorite" Card with interactive heart toggle
  Widget _buildFavoriteCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Add as Favorite',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isFavorite = !_isFavorite),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(
                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFavorite ? const Color(0xFFE11D48) : brandViolet,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dual High-Contrast Action CTAs (Image 2 Elevated Style)
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Primary CTA: "Confirm & Send"
          Container(
            width: double.infinity,
            height: 52,
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _showBiometricAuthModal,
              child: const Text(
                'Confirm & Send',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary CTA: "Cancel Transaction" (Image 2 Elevated White Pill Button)
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel Transaction',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: brandViolet,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBiometricAuthModal() {
    final user = _bankService.user;
    final bool hasFaceId = user.faceIdEnabled;
    final bool hasFingerprint = user.fingerprintEnabled;

    // Determine initial biometric type based on what is turned on in user settings:
    // If only Face ID is on -> Face ID
    // If only Fingerprint is on -> Fingerprint
    // If both are on -> Default to Face ID (with toggle between Face ID & Fingerprint)
    // If neither is on -> fallback to Fingerprint
    bool useFaceId = hasFaceId || (!hasFingerprint);
    if (!hasFaceId && hasFingerprint) {
      useFaceId = false;
    }

    bool isVerifying = false;
    bool isSuccess = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> executeBiometricAuth() async {
              if (isVerifying || isSuccess) return;
              setModalState(() {
                isVerifying = true;
              });

              // Realistic biometric verification handshake
              await Future.delayed(const Duration(milliseconds: 650));

              if (!context.mounted) return;
              setModalState(() {
                isVerifying = false;
                isSuccess = true;
              });

              await Future.delayed(const Duration(milliseconds: 350));
              if (!context.mounted) return;

              final navigator = Navigator.of(context);
              navigator.pop();

              final result = await _bankService.executeTransfer(
                targetAccount: widget.recipientAccount,
                recipientName: widget.recipientName,
                amount: widget.amount,
                destinationBank: widget.recipientBank,
                remarks: widget.remarks,
              );

              if (!mounted) return;
              Navigator.of(this.context).pushReplacement(
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

            final String authTitle = isSuccess
                ? 'Biometrics Verified!'
                : (useFaceId ? 'Authorize with Face ID' : 'Authorize with Fingerprint');

            final String authSubtitle = isSuccess
                ? 'Transfer approved. Finalizing ledger...'
                : (useFaceId
                    ? 'Look at screen or tap to authorize transfer'
                    : 'Touch sensor or tap to authorize transfer');

            final String ctaLabel = isVerifying
                ? 'Verifying...'
                : (useFaceId ? 'Authorize Face ID' : 'Authorize Fingerprint');

            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 36,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Drag Indicator Bar
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // If both Face ID & Fingerprint are enabled in settings, show toggle
                      if (hasFaceId && hasFingerprint && !isVerifying && !isSuccess) ...[
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setModalState(() => useFaceId = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: useFaceId ? brandViolet : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.face_retouching_natural_rounded,
                                        size: 16,
                                        color: useFaceId ? Colors.white : textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Face ID',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: useFaceId ? Colors.white : textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setModalState(() => useFaceId = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: !useFaceId ? brandViolet : Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.fingerprint_rounded,
                                        size: 16,
                                        color: !useFaceId ? Colors.white : textMuted,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Fingerprint',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: !useFaceId ? Colors.white : textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ] else ...[
                        const SizedBox(height: 8),
                      ],

                      // Glowing Biometric Centerpiece Sensor
                      GestureDetector(
                        onTap: isVerifying ? null : executeBiometricAuth,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSuccess
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : brandViolet.withValues(alpha: 0.08),
                            border: Border.all(
                              color: isSuccess ? const Color(0xFF10B981) : brandViolet.withValues(alpha: 0.3),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isSuccess ? const Color(0xFF10B981) : brandViolet).withValues(alpha: 0.16),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isSuccess
                                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 52)
                                : isVerifying
                                    ? const SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(strokeWidth: 3.5, color: brandViolet),
                                      )
                                    : useFaceId
                                        ? const FaceIdIcon(size: 56, backgroundColor: Colors.transparent, color: brandViolet)
                                        : const Icon(Icons.fingerprint_rounded, color: brandViolet, size: 52),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Title
                      Text(
                        authTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Subtitle
                      Text(
                        authSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Recap Transfer Capsule
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Transfer Amount',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: brandViolet,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Primary Biometric CTA
                      Container(
                        width: double.infinity,
                        height: 52,
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
                          onPressed: isVerifying ? null : executeBiometricAuth,
                          icon: Icon(
                            useFaceId ? Icons.face_retouching_natural_rounded : Icons.fingerprint_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: Text(
                            ctaLabel,
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

                      // Secondary Cancel CTA
                      Container(
                        width: double.infinity,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: isVerifying ? null : () => Navigator.of(context).pop(),
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
                  ),
                ),
              ),
            );
          },
        );
      },
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
