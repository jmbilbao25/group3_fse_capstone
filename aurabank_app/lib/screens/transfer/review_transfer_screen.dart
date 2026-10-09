import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/bank_service.dart';
import '../../services/biometric_service.dart';
import '../../services/security_service.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/require_device_approval.dart';
import '../../widgets/screen_sharing_warning_sheet.dart';
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

const Color brandViolet = AuraColors.primary;
const Color textDark = AuraColors.textPrimary;
const Color textGray = AuraColors.textMuted;
const Color cardBorder = AuraColors.cardBorder;
const Color greenSuccess = AuraColors.creditGreen;

class _ReviewTransferScreenState extends State<ReviewTransferScreen> {
  final BankService _bankService = BankService();
  late String _currentRemarks;
  String _riskScenario = 'AUTO'; // 'AUTO', 'SCAM', 'REMOTE', 'CALL', 'BLOCK'


  @override
  void initState() {
    super.initState();
    _currentRemarks = (widget.remarks != null && widget.remarks!.trim().isNotEmpty)
        ? widget.remarks!.trim()
        : 'Tuition fee allowance';
  }

  void _selectScenario(String key) {
    setState(() {
      _riskScenario = key;
      switch (key) {
        case 'SCAM':
          _currentRemarks = 'Guaranteed 50% crypto return';
          break;
        case 'REMOTE':
          _currentRemarks = 'IT remote support fee';
          break;
        case 'ANYDESK':
          _currentRemarks = 'AnyDesk remote connection support';
          break;
        case 'HOOKING':
          _currentRemarks = 'Memory hooking tamper test';
          break;
        case 'CANARY':
          _currentRemarks = 'HTTP Canary packet sniffer inspection';
          break;
        case 'CALL':
          _currentRemarks = 'Police bail bond deposit';
          break;
        case 'BLOCK':
          _currentRemarks = 'Emergency investment deposit';
          break;
        case 'GEO_ANOMALY':
          _currentRemarks = 'Overseas fund movement';
          _bankService.updateCustomerLocation(
            latitude: 51.5074,
            longitude: -0.1278,
            locationName: 'London, United Kingdom (Impossible Travel)',
          );
          break;
        case 'AUTO':
        default:
          _currentRemarks = (widget.remarks != null && widget.remarks!.trim().isNotEmpty)
              ? widget.remarks!.trim()
              : 'Tuition fee allowance';
          break;
      }
    });
  }

  void _showEditMemoDialog() {
    final controller = TextEditingController(text: _currentRemarks);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Transfer Memo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textDark),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter transfer purpose or memo',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: cardBorder),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandViolet,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _currentRemarks = controller.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showSimulationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuraColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Security Simulation Modes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a scenario to test risk engine outcomes.',
                style: TextStyle(fontSize: 13, color: textGray),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSimulationOption('AUTO', 'Standard (Normal)', 'Clean biometric transfer approval', Icons.check_circle_outline_rounded),
                      _buildSimulationOption('SCAM', 'Scam Warning', 'Simulates detected investment scam memo pattern', Icons.warning_amber_rounded),
                      _buildSimulationOption('REMOTE', 'Screen Sharing', 'Simulates active remote desktop app detected', Icons.screen_share_outlined),
                      _buildSimulationOption('ANYDESK', 'AnyDesk Remote App', 'Simulates running package com.anydesk.anydeskandroid', Icons.phone_android_rounded),
                      _buildSimulationOption('HOOKING', 'Frida / Xposed Hooking', 'Simulates memory hooking frameworks detected', Icons.memory_rounded),
                      _buildSimulationOption('CANARY', 'HTTP Canary Sniffer', 'Simulates packet inspection / MITM tool active', Icons.network_check_rounded),
                      _buildSimulationOption('CALL', 'Active Call', 'Simulates active phone call during transaction', Icons.phone_in_talk_outlined),
                      _buildSimulationOption('GEO_ANOMALY', 'Location Anomaly (London / Impossible Travel)', 'Simulates instant change of customer location to London, UK', Icons.wrong_location_rounded),
                      _buildSimulationOption('BLOCK', 'High Risk Block', 'Simulates restricted device or severe anomaly', Icons.block_flipped),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationOption(String key, String title, String subtitle, IconData icon) {
    final bool isSelected = _riskScenario == key;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        _selectScenario(key);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AuraColors.tintPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AuraColors.borderPurple : AuraColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AuraColors.primary : textGray, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AuraColors.primary : textDark,
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: textGray)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AuraColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                        color: textDark,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Review Transfer',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    color: textGray,
                    tooltip: 'Simulation Modes',
                    onPressed: _showSimulationBottomSheet,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Sender & Recipient Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Sender
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: AuraColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.senderName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Aura Bank No. ${widget.senderAccount}',
                                style: const TextStyle(fontSize: 11, color: textGray),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Center(
                      child: Icon(Icons.keyboard_double_arrow_down_rounded, color: textGray, size: 24),
                    ),
                    const SizedBox(height: 12),

                    // Recipient
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7928CA).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Color(0xFF7928CA), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.recipientName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.recipientBank} No. ${widget.recipientAccount}',
                                style: const TextStyle(fontSize: 11, color: textGray),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Amount Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildAmountRow('Transfer Amount', 'PHP ${_formatAmount(widget.amount)}'),
                    const SizedBox(height: 14),
                    _buildAmountRow('Transfer Fee', widget.fee == 0.0 ? 'FREE' : 'PHP ${_formatAmount(widget.fee)}', feeColor: greenSuccess),
                    const Divider(color: cardBorder, height: 28),
                    _buildAmountRow('Total Amount', 'PHP ${_formatAmount(widget.amount + widget.fee)}', isTotal: true),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Memo & Remarks Card (with edit icon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notes_rounded, color: AuraColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Payment Memo',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textGray),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentRemarks,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AuraColors.primary),
                      onPressed: _showEditMemoDialog,
                      tooltip: 'Edit Memo',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Aura Security Protection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AuraColors.tintPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.shield_rounded,
                            color: AuraColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Aura Security Protection',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Real-time protection is active for this transfer.',
                                style: TextStyle(fontSize: 11, color: textGray),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AuraColors.bgLavender,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded, size: 10, color: AuraColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AuraColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_riskScenario != 'AUTO') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AuraColors.bgLavender,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AuraColors.borderLavender),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.science_outlined, size: 13, color: AuraColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Simulation Active: $_riskScenario',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AuraColors.primary),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => _riskScenario = 'AUTO'),
                              child: const Icon(Icons.close_rounded, size: 14, color: textGray),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),


              const SizedBox(height: 24),

              // Confirm & Send Button
              RequireDeviceApproval(
                actionLabel: 'Transfer confirmations',
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: AuraColors.buttonShadow,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandViolet,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      elevation: 0,
                    ),
                    onPressed: _showConfirmationModal,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Confirm & Transfer',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel Transaction',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textGray),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {Color? feeColor, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? textDark : textGray,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            color: feeColor ?? textDark,
          ),
        ),
      ],
    );
  }

  void _showConfirmationModal() {
    if (!RequireDeviceApproval.canTransact(context)) {
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AuraColors.tintPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, color: AuraColors.primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Transfer',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
              ),
              const SizedBox(height: 8),
              Text(
                'You are sending PHP ${_formatAmount(widget.amount)} to ${widget.recipientName}. Please confirm to proceed with secure verification.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: textGray, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AuraColors.bgLavender,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AuraColors.borderLavender),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Amount', style: TextStyle(fontSize: 11, color: textGray)),
                        const SizedBox(height: 2),
                        Text(
                          'PHP ${_formatAmount(widget.amount)}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textDark),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Memo', style: TextStyle(fontSize: 11, color: textGray)),
                        const SizedBox(height: 2),
                        Text(
                          _currentRemarks,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _triggerMultiStageScan();
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Verify & Transfer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel Transaction', style: TextStyle(color: textGray, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  // Multi-Stage Risk Scan Overlay
  Future<void> _triggerMultiStageScan() async {
    final bool isThreatScenario = _riskScenario == 'SCAM' ||
        _riskScenario == 'REMOTE' ||
        _riskScenario == 'ANYDESK' ||
        _riskScenario == 'CANARY' ||
        _riskScenario == 'CALL' ||
        _riskScenario == 'GEO_ANOMALY';
    final bool isBlockScenario = _riskScenario == 'BLOCK' || _riskScenario == 'HOOKING';

    final List<String> runningPkgs = [];
    final List<String> threats = [];
    bool remoteApp = false;
    bool activeCall = false;
    bool hooking = false;
    bool rooted = false;
    bool isEmulator = false;

    if (_riskScenario == 'REMOTE') {
      remoteApp = true;
      threats.add('REMOTE_SCREEN_SHARE');
    } else if (_riskScenario == 'ANYDESK') {
      remoteApp = true;
      runningPkgs.add('com.anydesk.anydeskandroid');
      threats.add('REMOTE_ACCESS_ANYDESK');
    } else if (_riskScenario == 'HOOKING') {
      hooking = true;
      runningPkgs.addAll(['re.robv.android.xposed.installer', 'frida-server']);
      threats.addAll(['MEMORY_HOOKING_FRAMEWORK', 'FRIDA_SERVER_DETECTED']);
    } else if (_riskScenario == 'CANARY') {
      runningPkgs.add('com.guoshi.httpcanary');
      threats.add('PACKET_INSPECTION_TOOL');
    } else if (_riskScenario == 'CALL') {
      activeCall = true;
      threats.add('ACTIVE_VOICE_CALL_COERCION');
    } else if (_riskScenario == 'GEO_ANOMALY') {
      threats.add('IMPOSSIBLE_TRAVEL_GEO_ANOMALY');
      threats.add('UNRECOGNIZED_OVERSEAS_LOCATION');
    } else if (_riskScenario == 'BLOCK') {
      isEmulator = true;
      rooted = true;
      threats.add('ROOTED_DEVICE_EMULATOR');
    }

    bool alreadyWarnedScreenShare = false;
    if ((_riskScenario == 'REMOTE' || _riskScenario == 'ANYDESK') || SecurityService.simulateScreenSharing) {
      final userAction = await ScreenSharingWarningSheet.show(context);
      if (userAction == ScreenSharingUserAction.cancelTransaction) {
        _showTransferCancelledModal();
        return;
      } else if (userAction == ScreenSharingUserAction.pauseFor10Minutes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer paused for 10 minutes to protect your account.'),
            backgroundColor: Color(0xFFD97706),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      alreadyWarnedScreenShare = true;
    }

    // Show the animated scanner dialog
    if (!mounted) return;
    final scanResult = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RiskScanDialog(
        bankService: _bankService,
        targetAccount: widget.recipientAccount,
        amount: widget.amount,
        memo: _currentRemarks,
        isScreenSharing: remoteApp,
        callState: activeCall ? 'ACTIVE_CALL' : 'IDLE',
        inputMode: _riskScenario == 'SCAM' ? 'PASTED' : 'TYPED',
        isEmulator: isEmulator,
        runningPackages: runningPkgs,
        detectedThreats: threats,
        remoteAppActive: remoteApp,
        activeCall: activeCall,
        hooking: hooking,
        rooted: rooted,
        forcedThreat: isThreatScenario,
        forcedBlock: isBlockScenario,
      ),
    );

    if (!mounted || scanResult == null) return;

    final decision = (scanResult['decision'] ?? 'ALLOW').toString().toUpperCase();
    final bool isHardBlock = decision == 'BLOCK' ||
        isBlockScenario ||
        hooking ||
        (scanResult['hooking'] == true) ||
        (scanResult['rooted'] == true);

    if (isHardBlock) {
      _showBlockModal(scanResult);
    } else if (decision == 'ADVISORY_WARNING') {
      if (alreadyWarnedScreenShare) {
        // Already acknowledged screen sharing warning; proceed to biometric approval
        _showBiometricApprovalModal(scanResult);
      } else {
        _showAdvisoryWarningModal(scanResult);
      }
    } else if (decision == 'REQUIRE_2FA' || decision == 'STEP_UP') {
      _showStepUpModal();
    } else {
      _showBiometricApprovalModal(scanResult);
    }
  }

  // Biometric Approval Prompt
  void _showBiometricApprovalModal(Map<String, dynamic> risk) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuraColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AuraColors.tintPurple,
                shape: BoxShape.circle,
                border: Border.all(color: AuraColors.borderLavender, width: 2),
              ),
              child: const Icon(Icons.face_retouching_natural_rounded, color: AuraColors.primary, size: 38),
            ),
            const SizedBox(height: 16),
            const Text(
              'Approve with Biometrics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
            ),
            const SizedBox(height: 6),
            const Text(
              'Authorize with your biometrics to confirm this transfer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textGray, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Identity Verified • Secure Transfer',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuraColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                onPressed: () async {
                  final biometric = BiometricService();
                  final bool canAuth = await biometric.canAuthenticate();
                  if (canAuth) {
                    final bool verified = await biometric.authenticate(
                      reason: 'Authorize transfer of PHP ${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
                      biometricOnly: false,
                    );
                    if (!verified) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Biometric authorization was cancelled or unverified.'),
                            backgroundColor: Color(0xFF6B7280),
                          ),
                        );
                      }
                      return;
                    }
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                  if (mounted) {
                    await _executeTransferAndNavigate();
                  }
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fingerprint_rounded, size: 22),
                    SizedBox(width: 10),
                    Text('Confirm with Biometrics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel Transaction', style: TextStyle(color: textGray, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeTransferAndNavigate() async {
    if (!RequireDeviceApproval.canTransact(context)) {
      return;
    }

    // Show a quick settling HUD
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AuraColors.primary),
                SizedBox(height: 16),
                Text(
                  'Processing transfer securely...',
                  style: TextStyle(color: textDark, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final List<String> runningPkgs = [];
    final List<String> threats = [];
    bool remoteApp = false;
    bool activeCall = false;
    bool hooking = false;
    bool rooted = false;
    bool isEmulator = false;

    if (_riskScenario == 'REMOTE') {
      remoteApp = true;
      threats.add('REMOTE_SCREEN_SHARE');
    } else if (_riskScenario == 'ANYDESK') {
      remoteApp = true;
      runningPkgs.add('com.anydesk.anydeskandroid');
      threats.add('REMOTE_ACCESS_ANYDESK');
    } else if (_riskScenario == 'HOOKING') {
      hooking = true;
      runningPkgs.addAll(['re.robv.android.xposed.installer', 'frida-server']);
      threats.addAll(['MEMORY_HOOKING_FRAMEWORK', 'FRIDA_SERVER_DETECTED']);
    } else if (_riskScenario == 'CANARY') {
      runningPkgs.add('com.guoshi.httpcanary');
      threats.add('PACKET_INSPECTION_TOOL');
    } else if (_riskScenario == 'CALL') {
      activeCall = true;
      threats.add('ACTIVE_VOICE_CALL_COERCION');
    } else if (_riskScenario == 'BLOCK') {
      isEmulator = true;
      rooted = true;
      threats.add('ROOTED_DEVICE_EMULATOR');
    }

    final result = await _bankService.executeTransfer(
      targetAccount: widget.recipientAccount,
      recipientName: widget.recipientName,
      amount: widget.amount,
      destinationBank: widget.recipientBank,
      remarks: _currentRemarks,
      runningPackages: runningPkgs,
      detectedThreats: threats,
      remoteAppActive: remoteApp,
      activeCall: activeCall,
      hooking: hooking,
      rooted: rooted,
      isEmulator: isEmulator,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss settling dialog

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
          referenceNumber: result['reference'] ?? 'FT261008000000',
          failureReason: result['failureReason'],
        ),
      ),
    );
  }

  void _showBlockModal(Map<String, dynamic> risk) {
    final refCode = 'SEC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Suspicious Activity Detected',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'We stopped this transfer to protect your account. Suspicious activity or an unrecognized security environment was detected on your device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textGray, height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Security Status', style: TextStyle(fontSize: 12, color: textGray)),
                        Text(
                          'Protected',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Notice', style: TextStyle(fontSize: 12, color: textGray)),
                        Text(
                          'Suspicious activity detected',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Account Protection', style: TextStyle(fontSize: 12, color: textGray)),
                        Text(
                          'Funds 100% Preserved',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Security Reference', style: TextStyle(fontSize: 12, color: textGray)),
                        Text(
                          refCode,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textGray),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Return to Safety (No Money Moved)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdvisoryWarningModal(Map<String, dynamic> risk) {
    final warning = risk['warning_dialog'] as Map<String, dynamic>?;
    final threatCategory = warning?['threat_category'] ?? risk['threat_category'] ?? risk['primary_flag'] ?? 'GENERAL_ADVISORY';
    final title = warning?['title'] ?? 'Screen Sharing or Scam Typology Detected';
    final body = warning?['body_message'] ??
        'An active risk signal was flagged for this transfer. Bank personnel and legitimate organizations will NEVER ask you to share your screen, pay advance fees, or move money to "secure" an account.';
    final ackText = warning?['checkbox_acknowledgment_text'] ??
        'I confirm I understand this transfer is non-refundable and not an advance fee.';
    final causeOfSuspicion = risk['cause_of_suspicion'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AdvisoryWarningSheet(
          threatCategory: threatCategory.toString(),
          title: title,
          bodyMessage: body,
          ackText: ackText,
          amount: widget.amount,
          memoAnalysis: risk['memo_analysis'] as Map<String, dynamic>?,
          causeOfSuspicion: causeOfSuspicion?.toString(),
          onProceed: () {
            Navigator.of(ctx).pop();
            _showBiometricApprovalModal(risk);
          },
          onPause: () {
            Navigator.of(ctx).pop();
            _showTenMinuteHoldModal();
          },
          onCancel: () {
            Navigator.of(ctx).pop();
            _showTransferCancelledModal();
          },
        );
      },
    );
  }

  void _showTenMinuteHoldModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuraColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBEB),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_rounded, color: Color(0xFFD97706), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              '10-Minute Cool-Off Hold',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your funds stay safe in your account while you independently verify the recipient through official channels.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textGray, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Text(
                '10:00',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFB45309),
                  letterSpacing: 2.0,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuraColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Return to Safety', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferCancelledModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AuraColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield_rounded, color: Color(0xFF059669), size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transfer Cancelled',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
            ),
            const SizedBox(height: 8),
            const Text(
              'No money moved. Your funds remain intact and safe in your account.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textGray, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AuraColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Return to Dashboard', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStepUpModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AuraColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AuraColors.tintPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fingerprint_rounded, color: AuraColors.primary, size: 36),
              ),
              const SizedBox(height: 14),
              const Text(
                'Additional Verification Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Additional verification is required for this transfer. Please authorize with your Biometrics or MPIN on this registered device.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: textGray, height: 1.4),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final biometric = BiometricService();
                    final bool canAuth = await biometric.canAuthenticate();
                    if (canAuth) {
                      final bool verified = await biometric.authenticate(
                        reason: 'Authorize transfer of PHP ${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
                        biometricOnly: false,
                      );
                      if (!verified) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Biometric authorization was cancelled or unverified.'),
                              backgroundColor: Color(0xFF6B7280),
                            ),
                          );
                        }
                        return;
                      }
                    }
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (mounted) {
                      await _executeTransferAndNavigate();
                    }
                  },
                  child: const Text('Authorize with Biometrics', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel Transaction', style: TextStyle(color: textGray, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
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

// ---------------------------------------------------------------------------
// Security Verification Scanning Dialog
// ---------------------------------------------------------------------------
class _RiskScanDialog extends StatefulWidget {
  final BankService bankService;
  final String targetAccount;
  final double amount;
  final String memo;
  final bool isScreenSharing;
  final String callState;
  final String inputMode;
  final bool isEmulator;
  final List<String>? runningPackages;
  final List<String>? detectedThreats;
  final bool? remoteAppActive;
  final bool? activeCall;
  final bool? hooking;
  final bool? rooted;
  final bool forcedThreat;
  final bool forcedBlock;

  const _RiskScanDialog({
    required this.bankService,
    required this.targetAccount,
    required this.amount,
    required this.memo,
    required this.isScreenSharing,
    required this.callState,
    required this.inputMode,
    required this.isEmulator,
    this.runningPackages,
    this.detectedThreats,
    this.remoteAppActive,
    this.activeCall,
    this.hooking,
    this.rooted,
    required this.forcedThreat,
    required this.forcedBlock,
  });

  @override
  State<_RiskScanDialog> createState() => _RiskScanDialogState();
}

class _RiskScanDialogState extends State<_RiskScanDialog> {
  @override
  void initState() {
    super.initState();
    _executeScanWorkflow();
  }

  Future<void> _executeScanWorkflow() async {
    final apiFuture = widget.bankService.analyzeTransferRisk(
      targetAccount: widget.targetAccount,
      amount: widget.amount,
      memo: widget.memo,
      isScreenSharing: widget.isScreenSharing,
      callState: widget.callState,
      inputMode: widget.inputMode,
      isEmulator: widget.isEmulator,
      runningPackages: widget.runningPackages,
      detectedThreats: widget.detectedThreats,
      remoteAppActive: widget.remoteAppActive,
      activeCall: widget.activeCall,
      hooking: widget.hooking,
      rooted: widget.rooted,
    );

    final results = await Future.wait([
      apiFuture,
      Future.delayed(const Duration(milliseconds: 1200)),
    ]);

    if (!mounted) return;
    final apiRes = results[0] as Map<String, dynamic>;

    if (widget.forcedBlock || widget.hooking == true || widget.rooted == true) {
      Navigator.of(context).pop({
        ...apiRes,
        'decision': 'BLOCK',
        'fraud_score': 100,
        'primary_flag': 'HIGH_RISK_SUSPICIOUS_ENVIRONMENT',
        'threat_category': 'SUSPICIOUS_ACTIVITY',
        'cause_of_suspicion': 'Suspicious device environment detected',
      });
      return;
    }

    if (widget.detectedThreats != null && widget.detectedThreats!.contains('IMPOSSIBLE_TRAVEL_GEO_ANOMALY')) {
      Navigator.of(context).pop({
        ...apiRes,
        'decision': 'ADVISORY_WARNING',
        'fraud_score': 85,
        'primary_flag': 'GEO_VELOCITY_IMPOSSIBLE_TRAVEL',
        'threat_category': 'LOCATION_ANOMALY',
        'cause_of_suspicion': 'Impossible travel velocity detected: Location changed instantaneously to London, United Kingdom while registered baseline is Manila, Philippines.',
        'warning_dialog': {
          'title': 'Location Anomaly Detected',
          'threat_category': 'IMPOSSIBLE_TRAVEL',
          'body_message': 'Our security risk engine detected an impossible travel anomaly. Your session is currently reporting from London, United Kingdom, which deviates significantly from your baseline profile in Manila, Philippines.',
          'checkbox_acknowledgment_text': 'I verify that this location change is legitimate and I authorize this funds transfer.',
        },
      });
      return;
    }

    final backendDecision = (apiRes['decision'] ?? 'ALLOW').toString().toUpperCase();
    final finalDecision = (backendDecision == 'BLOCK' || widget.hooking == true || widget.rooted == true)
        ? 'BLOCK'
        : (widget.forcedThreat ? 'ADVISORY_WARNING' : backendDecision);

    Navigator.of(context).pop({
      ...apiRes,
      'decision': finalDecision,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 340,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aura Security Shield Indicator
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 76,
                      height: 76,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AuraColors.primary),
                        backgroundColor: AuraColors.tintPurple,
                      ),
                    ),
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: AuraColors.tintPurple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: AuraColors.primary,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Securing Transfer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait while we verify transaction safety...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textGray,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AuraColors.bgLavender,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AuraColors.borderLavender),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, color: AuraColors.primary, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Protected by 256-Bit Bank Encryption',
                      style: TextStyle(
                        color: AuraColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Advisory Warning Modal with Hazard Graphic & 3-Second Read Delay
// ---------------------------------------------------------------------------
class _AdvisoryWarningSheet extends StatefulWidget {
  final String threatCategory;
  final String title;
  final String bodyMessage;
  final String ackText;
  final double amount;
  final Map<String, dynamic>? memoAnalysis;
  final String? causeOfSuspicion;
  final VoidCallback onProceed;
  final VoidCallback onPause;
  final VoidCallback onCancel;

  const _AdvisoryWarningSheet({
    required this.threatCategory,
    required this.title,
    required this.bodyMessage,
    required this.ackText,
    required this.amount,
    this.memoAnalysis,
    this.causeOfSuspicion,
    required this.onProceed,
    required this.onPause,
    required this.onCancel,
  });

  @override
  State<_AdvisoryWarningSheet> createState() => _AdvisoryWarningSheetState();
}

class _AdvisoryWarningSheetState extends State<_AdvisoryWarningSheet> {
  bool _acknowledged = false;
  int _secondsRemaining = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _secondsRemaining = 0);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed = _acknowledged && _secondsRemaining == 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AuraColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Hazard Graphic Banner
          _buildHazardBanner(),

          const SizedBox(height: 14),

          // Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'ADVISORY NOTICE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF92400E),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textDark),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              widget.bodyMessage,
              style: const TextStyle(fontSize: 13, color: Color(0xFF78350F), height: 1.4),
            ),
          ),
          if (widget.memoAnalysis != null &&
              widget.memoAnalysis!['typology'] != null &&
              widget.memoAnalysis!['typology'] != 'none') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AuraColors.bgLavender,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AuraColors.borderLavender),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AuraColors.primary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security Notice: Unusual pattern detected in transfer memo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AuraColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.causeOfSuspicion != null && widget.causeOfSuspicion!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Security Notice: Unusual activity flagged on this transfer',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Checkbox Acknowledgment
          GestureDetector(
            onTap: () => setState(() => _acknowledged = !_acknowledged),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _acknowledged,
                    onChanged: (val) => setState(() => _acknowledged = val ?? false),
                    activeColor: const Color(0xFFD97706),
                    checkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.ackText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Primary: Cancel Transfer (Avoid Scam)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              onPressed: widget.onCancel,
              child: const Text('Cancel Transfer (Avoid Scam)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary: Pause for 10 minutes
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: textDark,
                side: const BorderSide(color: cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              onPressed: widget.onPause,
              child: const Text('Pause for 10 Minutes (Cool-off)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),

          // Tertiary: I understand, continue
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: canProceed ? widget.onProceed : null,
              child: Text(
                _secondsRemaining > 0
                    ? 'Review Threat Details (${_secondsRemaining}s)...'
                    : 'I Understand & Continue',
                style: TextStyle(
                  color: canProceed ? const Color(0xFFD97706) : textGray,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHazardBanner() {
    IconData icon1 = Icons.chat_bubble_outline_rounded;
    IconData icon2 = Icons.warning_amber_rounded;
    IconData icon3 = Icons.account_balance_rounded;

    if (widget.threatCategory.contains('REMOTE')) {
      icon1 = Icons.phone_android_rounded;
      icon2 = Icons.screen_share_rounded;
      icon3 = Icons.visibility_rounded;
    } else if (widget.threatCategory.contains('CALL')) {
      icon1 = Icons.person_rounded;
      icon2 = Icons.phone_in_talk_rounded;
      icon3 = Icons.stop_circle_rounded;
    }

    return Container(
      height: 84,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildHazardNode(icon1),
          _buildDottedConnector(),
          _buildHazardCenterNode(icon2),
          _buildDottedConnector(),
          _buildHazardNode(icon3),
        ],
      ),
    );
  }

  Widget _buildHazardNode(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Icon(icon, color: const Color(0xFFB45309), size: 20),
    );
  }

  Widget _buildHazardCenterNode(IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          Positioned(
            top: 3,
            right: 3,
            child: Container(
              width: 13,
              height: 13,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('!', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedConnector() {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFDE68A),
      ),
    );
  }
}
