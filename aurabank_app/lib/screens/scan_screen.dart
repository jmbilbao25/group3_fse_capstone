import 'dart:async';
import 'package:flutter/material.dart';
import '../services/bank_service.dart';
import '../theme/aura_theme.dart';
import '../widgets/aura_logo.dart';
import 'face_id_verification_screen.dart';

enum ScanStep {
  viewfinder,
  scanning,
  form,
}

class ScanScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final bool enableAnimation;

  const ScanScreen({
    super.key,
    this.onBack,
    this.enableAnimation = true,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  final BankService _bankService = BankService();
  ScanStep _step = ScanStep.scanning;
  late final AnimationController _animController;
  Timer? _autoScanTimer;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  String? _selectedPurpose;

  String _recipientName = 'Jessie Mae Dela Paz';
  String _recipientAccount = '1234568898951';
  String _recipientBank = 'MeyBank';

  static const List<Map<String, dynamic>> _sourceAccounts = [
    {
      'type': 'Savings',
      'title': 'Savings Account',
      'accountNo': '123456789123',
      'bankLabel': 'Aura Bank',
      'balance': 50000.0,
      'icon': Icons.account_balance_rounded,
    },
    {
      'type': 'Current',
      'title': 'Current Account',
      'accountNo': '123456789124',
      'bankLabel': 'Aura Bank',
      'balance': 125000.0,
      'icon': Icons.account_balance_wallet_rounded,
    },
    {
      'type': 'Credit',
      'title': 'Credit Account',
      'accountNo': '123456789125',
      'bankLabel': 'Aura Bank',
      'balance': 75000.0,
      'icon': Icons.credit_card_rounded,
    },
  ];

  int? _selectedSourceIndex;
  bool _isSourceDropdownOpen = false;
  bool _isPurposeDropdownOpen = false;

  static const List<String> _purposeOptions = [
    'Remittance',
    'Funds Transfer',
    'Bills Payment',
    'Savings',
  ];

  static const Color brandViolet = AuraColors.primary;
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color cardBorder = Color(0xFFF1F5F9);
  static const Color greenLaser = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    if (widget.enableAnimation) {
      _animController.repeat(reverse: true);
      _startScanTimer();
    }
  }

  void _startScanTimer() {
    _autoScanTimer?.cancel();
    if (!widget.enableAnimation) return;
    if (_step == ScanStep.scanning) {
      _autoScanTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _step == ScanStep.scanning) {
          setState(() {
            _step = ScanStep.form;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    _animController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _onTriggerScan() {
    setState(() {
      _step = ScanStep.scanning;
    });
    if (widget.enableAnimation) {
      _animController.repeat(reverse: true);
      _startScanTimer();
    }
  }

  void _onStopScan() {
    _autoScanTimer?.cancel();
    _animController.stop();
    setState(() {
      _step = ScanStep.viewfinder;
    });
  }

  void _handleBack() {
    if (_step == ScanStep.form) {
      _autoScanTimer?.cancel();
      _animController.stop();
      setState(() => _step = ScanStep.viewfinder);
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: _step == ScanStep.form ? const Color(0xFFF8FAFC) : Colors.black,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _step == ScanStep.form ? _buildScannedFormView() : _buildScannerView(),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1 & 2. SCANNER VIEW (Scan-IMAGE 3 & Scan-image 3)
  // -------------------------------------------------------------
  Widget _buildScannerView() {
    final isScanning = _step == ScanStep.scanning;

    return Column(
      children: [
        // Top Transparent Header (Back + Aura Bank Pill)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Circular Back Button
              _buildCircularBackButton(onTap: _handleBack),
              const SizedBox(width: 12),
              // Aura Bank Pill
              _buildAuraBankPill(),
            ],
          ),
        ),

        const Spacer(),

        // Camera Viewfinder Box with 4 Corner Brackets
        Center(
          child: GestureDetector(
            onTap: () {
              if (isScanning) {
                // Instantly resolve scanned QR on tap
                _autoScanTimer?.cancel();
                setState(() => _step = ScanStep.form);
              } else {
                _onTriggerScan();
              }
            },
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Viewfinder 4 Corner Brackets
                  CustomPaint(
                    size: const Size(290, 290),
                    painter: _ViewfinderCornersPainter(
                      color: isScanning ? greenLaser : Colors.white70,
                      bracketLength: 34,
                      strokeWidth: 3.5,
                      borderRadius: 24,
                    ),
                  ),

                  // QR Code Matrix Surface
                  Container(
                    width: 226,
                    height: 226,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CustomPaint(
                      painter: _LargeQrPainter(),
                    ),
                  ),

                  // Animated Green Laser Beam Sweep
                  if (isScanning)
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Positioned(
                          top: 36 + (218 * _animController.value),
                          left: 36,
                          right: 36,
                          child: Container(
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: greenLaser,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: greenLaser.withValues(alpha: 0.9),
                                  blurRadius: 10,
                                  spreadRadius: 2.5,
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
        ),

        const SizedBox(height: 24),

        // Start / Stop Scan Toggle Button
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextButton(
            onPressed: isScanning ? _onStopScan : _onTriggerScan,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: textDark,
            ),
            child: Text(
              isScanning ? 'Stop Scan' : 'Start Scan',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: textDark,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),

        const Spacer(),

        // Bottom Actions: Upload from Gallery & Generate QR
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: _buildBottomGlassButton(
                  icon: Icons.image_outlined,
                  label: 'Upload\nfrom Gallery',
                  onTap: _showGalleryUploadModal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildBottomGlassButton(
                  icon: Icons.qr_code_2_rounded,
                  label: 'Generate\nQR',
                  onTap: _showMyQrModal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 3. SCANNED DETAILS & SEND FORM (Scan-image 5)
  // -------------------------------------------------------------
  Widget _buildScannedFormView() {
    final currentBalance = _selectedSourceIndex != null
        ? (_sourceAccounts[_selectedSourceIndex!]['balance'] as double)
        : 50000.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header (Back + Aura Bank Pill)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildCircularBackButton(onTap: _handleBack),
                const SizedBox(width: 12),
                _buildAuraBankPill(),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 1. Source Account Card ("From:" - Inline Dropdown)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isSourceDropdownOpen ? brandViolet : cardBorder,
                width: _isSourceDropdownOpen ? 1.5 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    setState(() => _isSourceDropdownOpen = !_isSourceDropdownOpen);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From:',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (_selectedSourceIndex == null)
                              const Text(
                                'Select source account',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: textMuted,
                                ),
                              )
                            else ...[
                              Text(
                                _sourceAccounts[_selectedSourceIndex!]['title'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_sourceAccounts[_selectedSourceIndex!]['bankLabel']}: ${_sourceAccounts[_selectedSourceIndex!]['accountNo']}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _isSourceDropdownOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: brandViolet,
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isSourceDropdownOpen) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(color: cardBorder, height: 1, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: List.generate(_sourceAccounts.length, (index) {
                        final acc = _sourceAccounts[index];
                        final isSelected = _selectedSourceIndex == index;
                        return Container(
                          margin: EdgeInsets.only(bottom: index == _sourceAccounts.length - 1 ? 0 : 8),
                          decoration: BoxDecoration(
                            color: isSelected ? brandViolet.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? brandViolet : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _selectedSourceIndex = index;
                                _isSourceDropdownOpen = false;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: isSelected ? brandViolet : brandViolet.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      acc['icon'] as IconData,
                                      color: isSelected ? Colors.white : brandViolet,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          acc['title'] as String,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected ? brandViolet : textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${acc['bankLabel']} • ${acc['accountNo']}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'PHP ${_formatAmount(acc['balance'] as double)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Available',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Recipient & Amount Card (Scan-image 5)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipient Profile Row
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
                            _recipientName,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: textDark,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _recipientBank,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                          Text(
                            'Account No. $_recipientAccount',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Amount Input Box (Gray Pill Box in Scan-image 5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'PHP ',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: textDark,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textDark,
                            letterSpacing: -0.3,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: '0',
                            hintStyle: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF94A3B8),
                              letterSpacing: -0.3,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Balance & Limit Stacked (Scan-image 5)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Balance: PHP ${_formatAmount(currentBalance)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Transfer Limit: PHP 50,000.00',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Purpose & Remarks Card (Scan-image 5)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: cardBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Purpose',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),

                // Purpose Inline Dropdown Pill
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() {
                      _isPurposeDropdownOpen = !_isPurposeDropdownOpen;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedPurpose ?? 'Select transfer purpose',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _selectedPurpose != null ? textDark : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Icon(
                          _isPurposeDropdownOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: brandViolet,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),

                // Inline Dropdown Options Menu
                if (_isPurposeDropdownOpen) ...[
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: _purposeOptions.map((purpose) {
                          final isSelected = _selectedPurpose == purpose;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPurpose = purpose;
                                _isPurposeDropdownOpen = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? brandViolet.withValues(alpha: 0.08) : Colors.transparent,
                                border: purpose != _purposeOptions.last
                                    ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? brandViolet : const Color(0xFF94A3B8),
                                    size: 19,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      purpose,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? brandViolet : textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                const Text(
                  'Remarks (Optional)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 8),

                // Remarks Input Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _remarksController,
                    style: const TextStyle(fontSize: 13.5, color: textDark, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Enter details',
                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Primary CTA: "Send Money"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
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
                onPressed: _onProceedToSend,
                child: const Text(
                  'Send Money',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
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

  void _onProceedToSend() {
    final cleaned = _amountController.text.replaceAll(',', '').trim();
    final amount = double.tryParse(cleaned) ?? 0.0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a valid amount'),
          backgroundColor: brandViolet,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final senderAccount = _selectedSourceIndex != null
        ? _sourceAccounts[_selectedSourceIndex!]['accountNo'] as String
        : _sourceAccounts[0]['accountNo'] as String;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FaceIdVerificationScreen(
          senderName: _bankService.user.name,
          senderAccount: senderAccount,
          recipientName: _recipientName,
          recipientAccount: _recipientAccount,
          recipientBank: _recipientBank,
          amount: amount,
          fee: 0.0,
          remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
          autoAuthenticate: false,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // REUSABLE HEADER & WIDGET HELPERS
  // -------------------------------------------------------------
  Widget _buildCircularBackButton({required VoidCallback onTap}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: textDark),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildAuraBankPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuraLogo(size: 20, style: AuraLogoStyle.violet, borderRadius: 5),
          SizedBox(width: 8),
          Text(
            'Aura Bank',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: textDark,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: textDark,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(icon, size: 20, color: textDark),
        label: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: textDark),
        ),
        onPressed: onTap,
      ),
    );
  }

  void _showMyQrModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x380F172A),
                    blurRadius: 36,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AuraLogo(size: 42, style: AuraLogoStyle.violet, borderRadius: 10),
                    const SizedBox(height: 12),
                    Text(
                      _bankService.user.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: textDark),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Aura Account: ${_bankService.savingsAccountNumber}',
                      style: const TextStyle(fontSize: 12, color: textMuted, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: 190,
                      height: 190,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: CustomPaint(painter: _LargeQrPainter()),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Receive Money via QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Scan to transfer funds instantly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGalleryUploadModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x380F172A),
                    blurRadius: 36,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: brandViolet.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.photo_library_rounded, color: brandViolet, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload from Gallery',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: textDark,
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Select QR image from your photos',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Primary "Choose Photo / Files" browse trigger
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.of(context).pop();
                      _decodeSelectedQr(
                        name: 'Jessie Mae R. Dela Paz',
                        account: '1154848785378',
                        bank: 'MeyBank',
                        source: 'Device photo album',
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: brandViolet.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_photo_alternate_rounded, color: brandViolet, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Browse Photo Library',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textDark,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'PNG, JPG, or screenshot with QR code',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: textMuted, size: 22),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    'RECENT QR PHOTOS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Recent items list
                  _buildGalleryQrItem(
                    name: 'Jessie Mae R. Dela Paz',
                    bank: 'MeyBank',
                    account: '1154848785378',
                    date: 'Saved today',
                    onTap: () {
                      Navigator.of(context).pop();
                      _decodeSelectedQr(
                        name: 'Jessie Mae R. Dela Paz',
                        account: '1154848785378',
                        bank: 'MeyBank',
                        source: 'MeyBank_QR_Jessie.png',
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildGalleryQrItem(
                    name: 'Marco Vance',
                    bank: 'BDO Unibank',
                    account: '0029481928471',
                    date: 'Saved Oct 06',
                    onTap: () {
                      Navigator.of(context).pop();
                      _decodeSelectedQr(
                        name: 'Marco Vance',
                        account: '0029481928471',
                        bank: 'BDO Unibank',
                        source: 'QR_BDO_Marco.png',
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildGalleryQrItem(
                    name: 'Aura Merchant Pay',
                    bank: 'Aura Bank',
                    account: '0917234859102',
                    date: 'Saved Oct 04',
                    onTap: () {
                      Navigator.of(context).pop();
                      _decodeSelectedQr(
                        name: 'Aura Merchant Pay',
                        account: '0917234859102',
                        bank: 'Aura Bank',
                        source: 'Merchant_Invoice_QR.png',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  void _decodeSelectedQr({
    required String name,
    required String account,
    required String bank,
    required String source,
  }) {
    _autoScanTimer?.cancel();
    _animController.stop();

    setState(() {
      _recipientName = name;
      _recipientAccount = account;
      _recipientBank = bank;
      _step = ScanStep.form;
    });
  }

  Widget _buildGalleryQrItem({
    required String name,
    required String bank,
    required String account,
    required String date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: CustomPaint(painter: _LargeQrPainter()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$bank • $account',
                    style: const TextStyle(
                      fontSize: 11,
                      color: textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: brandViolet.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Select',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: brandViolet,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 10,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// VIEWFINDER 4 CORNER BRACKETS PAINTER
// -------------------------------------------------------------
class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;
  final double bracketLength;
  final double strokeWidth;
  final double borderRadius;

  _ViewfinderCornersPainter({
    required this.color,
    required this.bracketLength,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final l = bracketLength;
    final r = borderRadius;

    // Top-Left
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r), clockwise: false)
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r), clockwise: false)
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter oldDelegate) =>
      oldDelegate.color != color;
}

// -------------------------------------------------------------
// QR CODE MATRIX PAINTER
// -------------------------------------------------------------
class _LargeQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E1E2D)
      ..style = PaintingStyle.fill;

    final cell = size.width / 11.0;

    void drawFinder(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, cell * 3.5, cell * 3.5), paint);
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 0.7, y + cell * 0.7, cell * 2.1, cell * 2.1),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        Rect.fromLTWH(x + cell * 1.1, y + cell * 1.1, cell * 1.3, cell * 1.3),
        paint,
      );
    }

    drawFinder(0, 0);
    drawFinder(size.width - cell * 3.5, 0);
    drawFinder(0, size.height - cell * 3.5);

    // Grid dots
    for (int r = 0; r < 11; r++) {
      for (int c = 0; c < 11; c++) {
        if ((r < 4 && c < 4) || (r < 4 && c > 6) || (r > 6 && c < 4)) continue;
        if ((r + c * 3) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell + cell * 0.1, r * cell + cell * 0.1, cell * 0.8, cell * 0.8),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
