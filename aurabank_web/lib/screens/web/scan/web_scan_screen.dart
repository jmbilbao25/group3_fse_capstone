import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:aurabank_core/services/bank_service.dart';
import 'package:aurabank_core/theme/aura_theme.dart';
import '../transfer/web_transfer_screen.dart';

class WebScanScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onTransfer;

  const WebScanScreen({super.key, this.onBack, this.onTransfer});

  @override
  State<WebScanScreen> createState() => _WebScanScreenState();
}

class _WebScanScreenState extends State<WebScanScreen> {
  final BankService _bankService = BankService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _payeeCodeController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  bool _isProcessingImage = false;

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = AuraColors.textPrimary;
  static const Color textGray = AuraColors.textMuted;
  static const Color bgSurface = Color(0xFFF9FAFB);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color accentGreen = Color(0xFF16A34A);

  @override
  void initState() {
    super.initState();
    _bankService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    _payeeCodeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _pickQrFromFile() async {
    setState(() => _isProcessingImage = true);
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // On web/desktop file picker, process the payload or simulate QR reading
        await Future.delayed(const Duration(milliseconds: 600));
        _handleDetectedQr('aura://pay?account=AURA-8829-4102&name=Stripe+Merchant+Services&amount=250.00');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing file: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _handleDetectedQr(String rawData) {
    String targetAccount = rawData;
    String targetName = 'Merchant / Recipient';
    String? amount;

    if (rawData.contains('account=')) {
      final uri = Uri.tryParse(rawData);
      if (uri != null) {
        targetAccount = uri.queryParameters['account'] ?? rawData;
        targetName = uri.queryParameters['name']?.replaceAll('+', ' ') ?? 'Aura Payee';
        amount = uri.queryParameters['amount'];
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.qr_code_2_rounded, color: accentGreen, size: 24),
            ),
            const SizedBox(width: 12),
            const Text('QR Code Decoded', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment recipient identified:', style: TextStyle(fontSize: 13, color: textGray)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(targetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark)),
                  const SizedBox(height: 4),
                  Text('Account: $targetAccount', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: textGray)),
                  if (amount != null) ...[
                    const SizedBox(height: 6),
                    Text('Requested: \$$amount', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: brandViolet)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onTransfer != null) {
                widget.onTransfer!();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebTransferScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandViolet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Proceed to Transfer'),
          ),
        ],
      ),
    );
  }

  void _copyAccountCode() {
    Clipboard.setData(ClipboardData(text: _bankService.savingsAccountNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account clearance number copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = 'aura://pay?account=${_bankService.savingsAccountNumber}&name=${Uri.encodeComponent(_bankService.user.name)}';

    return Container(
      color: bgSurface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QR Settlement & Clearance Hub',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Instant desktop invoice clearance, QR routing, and corporate account wire payloads.',
                          style: TextStyle(
                            fontSize: 14,
                            color: textGray.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: accentGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'EMVCo Real-Time Clearance: Active',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Main Dual-Panel Layout
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN: My Account QR & Wire Specs
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: brandViolet.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.qr_code_rounded, color: brandViolet, size: 22),
                                ),
                                const SizedBox(width: 14),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'My Settlement QR',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: textDark,
                                      ),
                                    ),
                                    Text(
                                      'Scan or share to receive payments instantly',
                                      style: TextStyle(fontSize: 12.5, color: textGray),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // QR Code Presentation Frame
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: brandViolet.withValues(alpha: 0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: qrPayload,
                                    version: QrVersions.auto,
                                    size: 220.0,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: brandViolet,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: brandViolet.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'PREMIER SAVINGS',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: brandViolet,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _bankService.user.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Copyable Account Number Banner
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Account Clearance Code', style: TextStyle(fontSize: 11, color: textGray, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(_bankService.savingsAccountNumber, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: textDark, fontFamily: 'monospace')),
                                    ],
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _copyAccountCode,
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.copy_rounded, size: 15, color: textDark),
                                    label: const Text('Copy', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDark)),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('High-resolution QR package downloaded')),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: cardBorder),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.download_rounded, size: 18, color: textDark),
                                    label: const Text('Export PNG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textDark)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _copyAccountCode,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: brandViolet,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.share_rounded, size: 18),
                                    label: const Text('Share Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 24),

                    // RIGHT COLUMN: Settle / Upload Invoice QR & Manual Route
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          // Dropzone Card
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Settle Payment via QR',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: textDark,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Upload an invoice screenshot or billing QR file',
                                          style: TextStyle(fontSize: 12.5, color: textGray),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'PNG / JPG / PDF',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Drag & Drop Zone
                                InkWell(
                                  onTap: _pickQrFromFile,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFD1D5DB),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        if (_isProcessingImage)
                                          const CircularProgressIndicator(color: brandViolet)
                                        else ...[
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: brandViolet.withValues(alpha: 0.08),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.cloud_upload_outlined, color: brandViolet, size: 30),
                                          ),
                                          const SizedBox(height: 14),
                                          const Text(
                                            'Click to upload or drag QR invoice here',
                                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textDark),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Our clearance engine will decode and populate payment details automatically',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 12, color: textGray),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Manual Route Entry
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Manual Payee Clearance',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Enter a merchant identifier or routing number if you do not have an image',
                                  style: TextStyle(fontSize: 12.5, color: textGray),
                                ),
                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _payeeCodeController,
                                        decoration: InputDecoration(
                                          labelText: 'Payee Account / Merchant ID',
                                          hintText: 'e.g. AURA-8829-4102',
                                          prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 20),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: _amountController,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Amount (USD)',
                                          hintText: '0.00',
                                          prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final code = _payeeCodeController.text.trim();
                                      if (code.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please enter a Payee Account or Merchant ID')),
                                        );
                                        return;
                                      }
                                      _handleDetectedQr(code);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF111827),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                    label: const Text('Verify & Settle Payee', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
