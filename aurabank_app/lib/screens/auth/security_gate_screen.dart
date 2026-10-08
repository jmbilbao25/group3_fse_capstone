import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/aura_theme.dart';
import '../app_shell.dart';

enum SecurityGateMode {
  gate0Scanning,
  screenSharingDetected,
  transferBlocked,
}

class ThreatWarningModel {
  final String key;
  final String title;
  final String description;
  final IconData leftIcon;
  final IconData centerIcon;
  final IconData rightIcon;
  final bool isCritical;

  const ThreatWarningModel({
    required this.key,
    required this.title,
    required this.description,
    required this.leftIcon,
    required this.centerIcon,
    required this.rightIcon,
    required this.isCritical,
  });
}

class SecurityGateScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final SecurityGateMode initialMode;

  const SecurityGateScreen({
    super.key,
    this.onBack,
    this.initialMode = SecurityGateMode.gate0Scanning,
  });

  @override
  State<SecurityGateScreen> createState() => _SecurityGateScreenState();
}

class _SecurityGateScreenState extends State<SecurityGateScreen>
    with SingleTickerProviderStateMixin {
  late SecurityGateMode _currentMode;
  late AnimationController _rotationController;

  // Gate 0 progressive messages
  int _statusIndex = 0;
  final List<String> _scanStatuses = [
    'Securing connection...',
    'Verifying transfer details...',
    'Checking account protection...',
    'Finalizing verification...',
  ];
  Timer? _statusTimer;

  // Screen sharing state & 5 Laya Threat Categories
  bool _transferCancelled = false;
  bool _isPaused = false;
  int _pauseSecondsRemaining = 597; // 09:57
  Timer? _pauseTimer;

  final List<ThreatWarningModel> _threats = const [
    ThreatWarningModel(
      key: 'Remote access',
      title: 'Screen sharing or remote app detected',
      description:
          'Bank staff never ask you to share your screen. Someone may be viewing or controlling this session.',
      leftIcon: Icons.phone_iphone_rounded,
      centerIcon: Icons.screen_share_rounded,
      rightIcon: Icons.visibility_outlined,
      isCritical: true,
    ),
    ThreatWarningModel(
      key: 'Live call',
      title: 'You are on a call right now',
      description:
          'Impostors posing as police or bank staff stay on the line to pressure you into sending money.',
      leftIcon: Icons.person_rounded,
      centerIcon: Icons.phone_in_talk_rounded,
      rightIcon: Icons.stop_circle_outlined,
      isCritical: true,
    ),
    ThreatWarningModel(
      key: 'Purpose mismatch',
      title: 'Company payment to an unverified personal account',
      description:
          'Official institutions and corporate entities do not receive transfers through personal accounts.',
      leftIcon: Icons.account_balance_rounded,
      centerIcon: Icons.warning_amber_rounded,
      rightIcon: Icons.person_outline_rounded,
      isCritical: false,
    ),
    ThreatWarningModel(
      key: 'Pasted account',
      title: 'Account number pasted from another app',
      description:
          'Transfers requested over chat for tasks, prizes or crypto commissions are irreversible.',
      leftIcon: Icons.chat_bubble_outline_rounded,
      centerIcon: Icons.content_paste_rounded,
      rightIcon: Icons.account_balance_rounded,
      isCritical: false,
    ),
    ThreatWarningModel(
      key: 'General',
      title: 'Please re-verify the details',
      description:
          'Check the recipient and amount once more before you continue.',
      leftIcon: Icons.account_balance_rounded,
      centerIcon: Icons.shield_outlined,
      rightIcon: Icons.person_outline_rounded,
      isCritical: false,
    ),
  ];
  int _selectedThreatIndex = 0;
  int _continueCountdown = 3;
  Timer? _continueTimer;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _startStatusCycle();
    if (_currentMode == SecurityGateMode.screenSharingDetected) {
      _startContinueTimer();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _statusTimer?.cancel();
    _pauseTimer?.cancel();
    _continueTimer?.cancel();
    super.dispose();
  }

  void _selectThreat(int index) {
    setState(() {
      _selectedThreatIndex = index;
    });
    _startContinueTimer();
  }

  void _startContinueTimer() {
    _continueTimer?.cancel();
    setState(() {
      _continueCountdown = 3;
    });
    _continueTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_continueCountdown > 1) {
        setState(() => _continueCountdown--);
      } else {
        setState(() => _continueCountdown = 0);
        timer.cancel();
      }
    });
  }

  void _startStatusCycle() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (!mounted) return;
      setState(() {
        _statusIndex = (_statusIndex + 1) % _scanStatuses.length;
      });
    });
  }

  void _startPauseCountdown() {
    _pauseTimer?.cancel();
    setState(() {
      _isPaused = true;
      _pauseSecondsRemaining = 597;
    });
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_pauseSecondsRemaining > 0) {
        setState(() => _pauseSecondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedPauseTime {
    final m = _pauseSecondsRemaining ~/ 60;
    final s = _pauseSecondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Simulation Mode Selector Bar (for easy evaluation of all Figma fraud gates)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTabItem('Security Scan', SecurityGateMode.gate0Scanning),
                  _buildTabItem('Screen Share', SecurityGateMode.screenSharingDetected),
                  _buildTabItem('Blocked Anomaly', SecurityGateMode.transferBlocked),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Top Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AuraColors.textPrimary),
                        SizedBox(width: 6),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AuraColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge based on mode
                  if (_currentMode == SecurityGateMode.gate0Scanning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AuraColors.tintPurple,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AuraColors.borderPurple),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.shield_rounded, size: 12, color: AuraColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'Security Shield',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AuraColors.primary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_currentMode == SecurityGateMode.screenSharingDetected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, color: Color(0xFFDC2626), size: 7),
                          SizedBox(width: 5),
                          Text(
                            'Critical Risk',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, color: Color(0xFFDC2626), size: 7),
                          SizedBox(width: 5),
                          Text(
                            'TRANSACTION BLOCKED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Main Body Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: _buildCurrentView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String label, SecurityGateMode mode) {
    final isSelected = _currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentMode = mode);
          if (mode == SecurityGateMode.screenSharingDetected) {
            _startContinueTimer();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AuraColors.primary : AuraColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    switch (_currentMode) {
      case SecurityGateMode.gate0Scanning:
        return _buildGate0ScanningView();
      case SecurityGateMode.screenSharingDetected:
        return _buildScreenSharingView();
      case SecurityGateMode.transferBlocked:
        return _buildTransferBlockedView();
    }
  }

  // 1. GATE 0 SCANNING (image_52_0.png)
  Widget _buildGate0ScanningView() {
    return Column(
      children: [
        const SizedBox(height: 50),

        // Glowing Shield with Animated Circular Radar
        SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Halo
              Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AuraColors.accentLight.withValues(alpha: 0.08),
                ),
              ),

              // Rotating Radar Arc
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(180, 180),
                      painter: _RadarArcPainter(),
                    ),
                  );
                },
              ),

              // Center Shield Badge
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF380084), Color(0xFF6B11D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AuraColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 48),

        // Title
        const Text(
          'Checking your transfer',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AuraColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        // Progressive Subtitle
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _scanStatuses[_statusIndex],
            key: ValueKey<int>(_statusIndex),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AuraColors.textMuted,
            ),
          ),
        ),

        const SizedBox(height: 60),

        // Simulation Triggers
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Column(
            children: [
              const Text(
                'Security Anomaly Simulation Controls',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AuraColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _currentMode = SecurityGateMode.screenSharingDetected),
                      child: const Text('Inject Screen Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => setState(() => _currentMode = SecurityGateMode.transferBlocked),
                      child: const Text('Inject Velocity Anomaly', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. SCREEN SHARING OR LAYA THREAT WARNING VIEW (5 Threat Types)
  Widget _buildScreenSharingView() {
    final threat = _threats[_selectedThreatIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 5 Laya Threat Category Chips
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_threats.length, (index) {
                final item = _threats[index];
                final isSelected = _selectedThreatIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      item.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : AuraColors.textSecondary,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: item.isCritical
                        ? const Color(0xFFE11D48)
                        : const Color(0xFFD97706),
                    backgroundColor: const Color(0xFFF3F4F6),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : const Color(0xFFE5E7EB),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (selected) {
                      if (selected) _selectThreat(index);
                    },
                  ),
                );
              }),
            ),
          ),
        ),

        // Connected Device / Threat Diagram Card
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: threat.isCritical
                ? const Color(0xFFFFF5F5)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: threat.isCritical
                  ? const Color(0xFFFFE4E6)
                  : const Color(0xFFFEF3C7),
            ),
            boxShadow: [
              BoxShadow(
                color: (threat.isCritical
                        ? const Color(0xFFE11D48)
                        : const Color(0xFFD97706))
                    .withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Icon(
                  threat.leftIcon,
                  color: AuraColors.textSecondary,
                  size: 26,
                ),
              ),

              // Dashed Line
              CustomPaint(
                size: const Size(42, 2),
                painter: _DashedLinePainter(
                  color: threat.isCritical
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFFDE68A),
                ),
              ),

              // Center Alert Monitor Container
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: threat.isCritical
                          ? const Color(0xFFE11D48)
                          : const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (threat.isCritical
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFFD97706))
                              .withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      threat.centerIcon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '!',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Dashed Line
              CustomPaint(
                size: const Size(42, 2),
                painter: _DashedLinePainter(
                  color: threat.isCritical
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFFDE68A),
                ),
              ),

              // Right icon container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Icon(
                  threat.rightIcon,
                  color: AuraColors.textSecondary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ADVISORY WARNING Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFB45309)),
              SizedBox(width: 6),
              Text(
                'ADVISORY WARNING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Title
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            threat.title,
            key: ValueKey<String>(threat.title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.25,
              color: AuraColors.textPrimary,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              threat.description,
              key: ValueKey<String>(threat.description),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AuraColors.textSecondary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Action 1: Cancel transfer / Transfer Cancelled (image_61_0.png)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _transferCancelled
                  ? const Color(0xFF059669)
                  : AuraColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              shadowColor: AuraColors.primary.withValues(alpha: 0.3),
            ),
            onPressed: () {
              setState(() => _transferCancelled = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction cancelled safely to prevent unauthorized transfer.'),
                  backgroundColor: Color(0xFF059669),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _transferCancelled ? Icons.check_rounded : Icons.close_rounded,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  _transferCancelled ? 'Transfer Cancelled' : 'Cancel transfer',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Action 2: Pause for 10 minutes / Paused (09:57) (image_62_0.png)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(
                color: _isPaused ? const Color(0xFFFBBF24) : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            onPressed: _isPaused ? null : _startPauseCountdown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: _isPaused ? const Color(0xFFB45309) : AuraColors.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isPaused ? 'Paused ($_formattedPauseTime)' : 'Pause for 10 minutes',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isPaused ? const Color(0xFFB45309) : AuraColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Action 3: Mandatory 3-second delay text button
        TextButton(
          onPressed: _continueCountdown == 0
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Step-up verification required to override screen share barrier.'),
                      backgroundColor: AuraColors.primary,
                    ),
                  );
                }
              : null,
          child: Text(
            _continueCountdown > 0
                ? 'Continue in $_continueCountdown'
                : 'I understand, continue',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _continueCountdown == 0
                  ? AuraColors.textPrimary
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    );
  }

  // 3. TRANSFER BLOCKED / VELOCITY ANOMALY (image_66_0.png)
  Widget _buildTransferBlockedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),

        // Red Octagon Stop Badge with Halo
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFEE2E2).withValues(alpha: 0.6),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.pan_tool_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),

        const SizedBox(height: 36),

        // Title
        const Text(
          'Transfer blocked',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: AuraColors.textPrimary,
          ),
        ),

        const SizedBox(height: 12),

        // Subtitle
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'We stopped this transfer to protect your money. Contact support if this was you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AuraColors.textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 50),

        // Button 1: Back to start
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E2D),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
            ),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const AppShell(initialIndex: 0)),
                (route) => false,
              );
            },
            child: const Text(
              'Back to start',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Button 2: Contact Aura Support
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFAF7FF),
              side: const BorderSide(color: Color(0xFFE9D5FF), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connected to Priority Fraud Concierge: Case #AUR-SEC-9941'),
                  backgroundColor: AuraColors.primary,
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.support_agent_rounded, size: 18, color: AuraColors.primary),
                SizedBox(width: 8),
                Text(
                  'Contact Aura Support',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AuraColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Radar arc custom painter for Gate 0
class _RadarArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final paint = Paint()
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          Color(0xFF8B5CF6),
          Color(0xFF5E17EB),
        ],
        stops: [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Dashed line painter
class _DashedLinePainter extends CustomPainter {
  final Color color;

  _DashedLinePainter({this.color = const Color(0xFFFDA4AF)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
