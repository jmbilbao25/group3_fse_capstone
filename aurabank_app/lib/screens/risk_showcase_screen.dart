import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

enum ShowcaseScenario {
  allowed,
  warning,
  blocked,
}

enum ShowcaseNode {
  transferForm, // T: Customer transfer
  gate0Scan, // G: Gate 0
  xgboostScore, // X: XGBoost S2
  nanojevContext, // N: NanoJev
  biometrics, // A: Allow Biometric
  transferSent, // D: Settlement Ledger Commit
  advisoryWarning, // V: Advisory Threat Warning
  coolOffHold, // H: 10-minute cool-off
  transferCancelled, // C: Cancelled (Scam Avoided)
  transferBlocked, // B: Hard Stop Blocked
  stepUpMpin, // S: Step-up MPIN
}

class ThreatModel {
  final String key;
  final String title;
  final String description;
  final IconData leftIcon;
  final IconData centerIcon;
  final IconData rightIcon;
  final bool isCritical;

  const ThreatModel({
    required this.key,
    required this.title,
    required this.description,
    required this.leftIcon,
    required this.centerIcon,
    required this.rightIcon,
    required this.isCritical,
  });
}

class RiskEngineShowcaseScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const RiskEngineShowcaseScreen({super.key, this.onBack});

  @override
  State<RiskEngineShowcaseScreen> createState() =>
      _RiskEngineShowcaseScreenState();
}

class _RiskEngineShowcaseScreenState extends State<RiskEngineShowcaseScreen>
    with SingleTickerProviderStateMixin {
  ShowcaseScenario _scenario = ShowcaseScenario.allowed;
  ShowcaseNode _currentNode = ShowcaseNode.transferForm;
  late AnimationController _rotationController;

  // Scan progressive messages
  int _scanStatusIndex = 0;
  final List<String> _scanStatuses = [
    'Checking device and location...',
    'Scoring the transfer...',
    'Reading the context...',
  ];

  // 5 NanoJev Threats matching prototype W array
  final List<ThreatModel> _threats = const [
    ThreatModel(
      key: 'Remote access',
      title: 'Screen sharing or remote app detected',
      description:
          'Bank staff never ask you to share your screen. Someone may be viewing or controlling this session.',
      leftIcon: Icons.phone_iphone_rounded,
      centerIcon: Icons.screen_share_rounded,
      rightIcon: Icons.visibility_outlined,
      isCritical: true,
    ),
    ThreatModel(
      key: 'Live call',
      title: 'You are on a call right now',
      description:
          'Impostors posing as police or bank staff stay on the line to pressure you into sending money.',
      leftIcon: Icons.person_rounded,
      centerIcon: Icons.phone_in_talk_rounded,
      rightIcon: Icons.stop_circle_outlined,
      isCritical: true,
    ),
    ThreatModel(
      key: 'Purpose mismatch',
      title: 'Company payment to an unverified personal account',
      description:
          'Official institutions and corporate entities do not receive transfers through personal accounts.',
      leftIcon: Icons.account_balance_rounded,
      centerIcon: Icons.warning_amber_rounded,
      rightIcon: Icons.person_outline_rounded,
      isCritical: false,
    ),
    ThreatModel(
      key: 'Pasted account',
      title: 'Account number pasted from another app',
      description:
          'Transfers requested over chat for tasks, prizes or crypto commissions are irreversible.',
      leftIcon: Icons.chat_bubble_outline_rounded,
      centerIcon: Icons.content_paste_rounded,
      rightIcon: Icons.account_balance_rounded,
      isCritical: false,
    ),
    ThreatModel(
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

  // Timers & countdowns
  int _continueCountdown = 3;
  Timer? _continueTimer;

  int _pauseSecondsRemaining = 600; // 10:00
  Timer? _pauseTimer;

  int _playbackToken = 0;
  final String _enteredMpin = '';

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _continueTimer?.cancel();
    _pauseTimer?.cancel();
    super.dispose();
  }

  void _startScenario(ShowcaseScenario sc) {
    final token = ++_playbackToken;
    setState(() {
      _scenario = sc;
      _currentNode = ShowcaseNode.transferForm;
      _scanStatusIndex = 0;
    });

    // Step 1: Form -> Scanning
    Timer(const Duration(milliseconds: 700), () {
      if (token != _playbackToken || !mounted) return;
      setState(() {
        _currentNode = ShowcaseNode.gate0Scan;
        _scanStatusIndex = 0;
      });

      // Step 2: Gate 0
      Timer(const Duration(milliseconds: 900), () {
        if (token != _playbackToken || !mounted) return;
        if (sc == ShowcaseScenario.blocked) {
          setState(() => _currentNode = ShowcaseNode.transferBlocked);
          return;
        }

        setState(() {
          _currentNode = ShowcaseNode.xgboostScore;
          _scanStatusIndex = 1;
        });

        // Step 3: XGBoost S2 -> NanoJev
        Timer(const Duration(milliseconds: 900), () {
          if (token != _playbackToken || !mounted) return;
          setState(() {
            _currentNode = ShowcaseNode.nanojevContext;
            _scanStatusIndex = 2;
          });

          // Step 4: Outcome
          Timer(const Duration(milliseconds: 900), () {
            if (token != _playbackToken || !mounted) return;
            if (sc == ShowcaseScenario.warning) {
              _goToNode(ShowcaseNode.advisoryWarning);
            } else {
              _goToNode(ShowcaseNode.biometrics);
            }
          });
        });
      });
    });
  }

  void _goToNode(ShowcaseNode node) {
    _playbackToken++;
    setState(() {
      _currentNode = node;
    });

    if (node == ShowcaseNode.advisoryWarning) {
      _startContinueCountdown();
    } else if (node == ShowcaseNode.coolOffHold) {
      _startHoldCountdown();
    }
  }

  void _startContinueCountdown() {
    _continueTimer?.cancel();
    setState(() => _continueCountdown = 3);
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

  void _startHoldCountdown() {
    _pauseTimer?.cancel();
    setState(() => _pauseSecondsRemaining = 600);
    _pauseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_pauseSecondsRemaining > 0) {
        setState(() => _pauseSecondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedHoldTime {
    final m = _pauseSecondsRemaining ~/ 60;
    final s = _pauseSecondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _selectThreat(int index) {
    setState(() {
      _selectedThreatIndex = index;
    });
    if (_currentNode == ShowcaseNode.advisoryWarning) {
      _startContinueCountdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AuraColors.textPrimary),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: const Text(
          'Risk Engine Showcase',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AuraColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AuraColors.tintPurple,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuraColors.borderPurple),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.shield_rounded, size: 13, color: AuraColors.primary),
                SizedBox(width: 4),
                Text(
                  'Aura Defense',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AuraColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Scenario Selector Bar (matching HTML <div class="seg">)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildScenarioTab(
                        'Allowed', ShowcaseScenario.allowed, const Color(0xFF059669)),
                    _buildScenarioTab(
                        'Warning', ShowcaseScenario.warning, const Color(0xFFD97706)),
                    _buildScenarioTab(
                        'Blocked', ShowcaseScenario.blocked, const Color(0xFFDC2626)),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Select a scenario or tap the flow. The simulated banking app follows along.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AuraColors.textMuted),
              ),

              const SizedBox(height: 14),

              // Interactive Pipeline Stepper
              _buildPipelineBreadcrumb(),

              const SizedBox(height: 16),

              // Simulated Mobile Phone Container
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _currentNode == ShowcaseNode.advisoryWarning
                        ? (_threats[_selectedThreatIndex].isCritical
                            ? const Color(0xFFFDA4AF)
                            : const Color(0xFFFDE68A))
                        : const Color(0xFFE5E7EB),
                    width: _currentNode == ShowcaseNode.advisoryWarning ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Phone Top Notch & Status Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      color: const Color(0xFFFAF7FF),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('9:41',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AuraColors.textPrimary)),
                          Row(
                            children: [
                              Icon(Icons.wifi_rounded,
                                  size: 14, color: AuraColors.textPrimary),
                              SizedBox(width: 4),
                              Icon(Icons.battery_full_rounded,
                                  size: 15, color: AuraColors.textPrimary),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Phone Screen Content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 18),
                      child: _buildPhoneContent(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5 Threat Chips (visible when in Warning scenario or node)
              if (_scenario == ShowcaseScenario.warning ||
                  _currentNode == ShowcaseNode.advisoryWarning)
                _buildThreatChipsBar(),

              const SizedBox(height: 12),

              // Explanatory Caption Card (matching #cap in HTML prototype)
              _buildEngineStageCard(),

              const SizedBox(height: 14),

              // Footnote
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Simulated demo for illustration. The memo is ignored. Warning types are listed in the engine\'s priority order, and NanoJev can only raise friction, never lower it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AuraColors.textMuted, height: 1.35),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScenarioTab(
      String label, ShowcaseScenario scenario, Color accentColor) {
    final isSelected = _scenario == scenario;
    return Expanded(
      child: GestureDetector(
        onTap: () => _startScenario(scenario),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? accentColor : AuraColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineBreadcrumb() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildBreadcrumbNode('Customer Transfer', ShowcaseNode.transferForm),
          _buildBreadcrumbArrow(),
          _buildBreadcrumbNode('Gate 0', ShowcaseNode.gate0Scan),
          _buildBreadcrumbArrow(),
          _buildBreadcrumbNode('XGBoost S2', ShowcaseNode.xgboostScore),
          _buildBreadcrumbArrow(),
          _buildBreadcrumbNode('NanoJev', ShowcaseNode.nanojevContext),
          _buildBreadcrumbArrow(),
          _buildBreadcrumbNode(
            _scenario == ShowcaseScenario.blocked
                ? 'Blocked'
                : (_scenario == ShowcaseScenario.warning
                    ? 'Advisory'
                    : 'Allow Biometrics'),
            _scenario == ShowcaseScenario.blocked
                ? ShowcaseNode.transferBlocked
                : (_scenario == ShowcaseScenario.warning
                    ? ShowcaseNode.advisoryWarning
                    : ShowcaseNode.biometrics),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbNode(String label, ShowcaseNode node) {
    final isActive = _currentNode == node;
    return GestureDetector(
      onTap: () => _goToNode(node),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AuraColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? AuraColors.primary : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? Colors.white : AuraColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.arrow_forward_ios_rounded,
          size: 10, color: Color(0xFF9CA3AF)),
    );
  }

  Widget _buildPhoneContent() {
    switch (_currentNode) {
      case ShowcaseNode.transferForm:
        return _buildPhoneFormView();
      case ShowcaseNode.gate0Scan:
      case ShowcaseNode.xgboostScore:
      case ShowcaseNode.nanojevContext:
        return _buildPhoneScanningView();
      case ShowcaseNode.biometrics:
        return _buildPhoneBiometricView();
      case ShowcaseNode.transferSent:
        return _buildPhoneSentView();
      case ShowcaseNode.advisoryWarning:
        return _buildPhoneWarningView();
      case ShowcaseNode.coolOffHold:
        return _buildPhoneHoldView();
      case ShowcaseNode.transferCancelled:
        return _buildPhoneCancelledView();
      case ShowcaseNode.transferBlocked:
        return _buildPhoneBlockedView();
      case ShowcaseNode.stepUpMpin:
        return _buildPhoneStepUpView();
    }
  }

  // A. Customer Transfer Form (p-form)
  Widget _buildPhoneFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Send money',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AuraColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),

        // From account card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF3F4F6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FROM',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AuraColors.textMuted)),
                  SizedBox(height: 2),
                  Text('Savings ••••4821',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AuraColors.textPrimary)),
                ],
              ),
              Text('₱52,300.00',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AuraColors.primary)),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Payee & Amount details
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDE9FE)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('To Payee',
                      style:
                          TextStyle(fontSize: 12, color: AuraColors.textMuted)),
                  Text('Maria Santos',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AuraColors.textPrimary)),
                ],
              ),
              const Divider(height: 18, color: Color(0xFFF3F4F6)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Amount',
                      style:
                          TextStyle(fontSize: 12, color: AuraColors.textMuted)),
                  Text(
                    '₱18,500.00',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AuraColors.primary),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Action: Send ₱18,500.00
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: () => _startScenario(_scenario),
            child: const Text('Send ₱18,500.00',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  // B. Scanning View (p-check)
  Widget _buildPhoneScanningView() {
    return Column(
      children: [
        const SizedBox(height: 10),

        // Rotating Shield
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AuraColors.tintPurple,
                ),
              ),
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(110, 110),
                      painter: _SimpleRadarPainter(),
                    ),
                  );
                },
              ),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF380084), Color(0xFF6B11D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 30),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'Checking your transfer',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: AuraColors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          _scanStatuses[_scanStatusIndex],
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AuraColors.primary,
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // C. Biometrics View (p-bio)
  Widget _buildPhoneBiometricView() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AuraColors.tintPurple,
          ),
          child: const Icon(Icons.face_rounded,
              color: AuraColors.primary, size: 44),
        ),
        const SizedBox(height: 14),
        const Text(
          'Approve with biometrics',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Look at your phone to confirm it\'s really you.',
          style: TextStyle(fontSize: 12, color: AuraColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.transferSent),
            child: const Text('Look to approve',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // D. Transfer Sent (p-done)
  Widget _buildPhoneSentView() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFD1FAE5),
          ),
          child: const Icon(Icons.check_rounded,
              color: Color(0xFF059669), size: 42),
        ),
        const SizedBox(height: 14),
        const Text(
          'Transfer sent',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          '₱18,500.00 to Maria Santos is on its way.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AuraColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(23)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.transferForm),
            child: const Text('Start over',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AuraColors.textPrimary)),
          ),
        ),
      ],
    );
  }

  // E. Advisory Warning (p-warn)
  Widget _buildPhoneWarningView() {
    final threat = _threats[_selectedThreatIndex];

    return Column(
      children: [
        // Connected Device Diagram Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: threat.isCritical
                ? const Color(0xFFFFF5F5)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: threat.isCritical
                  ? const Color(0xFFFFE4E6)
                  : const Color(0xFFFEF3C7),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Icon(threat.leftIcon,
                    color: AuraColors.textSecondary, size: 22),
              ),
              CustomPaint(
                size: const Size(28, 2),
                painter: _SimpleDashedPainter(
                  color: threat.isCritical
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFFDE68A),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: threat.isCritical
                          ? const Color(0xFFE11D48)
                          : const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(threat.centerIcon,
                        color: Colors.white, size: 28),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Text('!',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ),
                  ),
                ],
              ),
              CustomPaint(
                size: const Size(28, 2),
                painter: _SimpleDashedPainter(
                  color: threat.isCritical
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFFDE68A),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3F4F6)),
                ),
                child: Icon(threat.rightIcon,
                    color: AuraColors.textSecondary, size: 22),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ADVISORY WARNING Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'ADVISORY WARNING',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Color(0xFFB45309)),
          ),
        ),

        const SizedBox(height: 8),

        // Title
        Text(
          threat.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.25,
            color: AuraColors.textPrimary,
          ),
        ),

        const SizedBox(height: 6),

        // Description
        Text(
          threat.description,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12, height: 1.35, color: AuraColors.textSecondary),
        ),

        const SizedBox(height: 18),

        // Button 1: Cancel transfer -> p-cancel
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.transferCancelled),
            child: const Text('Cancel transfer',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),

        const SizedBox(height: 8),

        // Button 2: Pause for 10 minutes -> p-hold
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.coolOffHold),
            child: const Text('Pause for 10 minutes',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AuraColors.textPrimary)),
          ),
        ),

        const SizedBox(height: 6),

        // Button 3: 3-Second countdown -> p-bio
        TextButton(
          onPressed: _continueCountdown == 0
              ? () => _goToNode(ShowcaseNode.biometrics)
              : null,
          child: Text(
            _continueCountdown > 0
                ? 'Continue in $_continueCountdown'
                : 'I understand, continue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _continueCountdown == 0
                  ? AuraColors.primary
                  : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ],
    );
  }

  // F. 10-Minute Cool-Off (p-hold)
  Widget _buildPhoneHoldView() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFEF3C7),
          ),
          child: const Icon(Icons.access_time_filled_rounded,
              color: Color(0xFFD97706), size: 38),
        ),
        const SizedBox(height: 14),
        const Text(
          '10-minute cool-off',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your funds stay in your account while you verify the recipient.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AuraColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Text(
            _formattedHoldTime,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontFamily: 'monospace',
              color: Color(0xFFB45309),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.transferForm),
            child: const Text('Start over',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AuraColors.textPrimary)),
          ),
        ),
      ],
    );
  }

  // G. Transfer Cancelled (p-cancel)
  Widget _buildPhoneCancelledView() {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE5E7EB),
          ),
          child: const Icon(Icons.shield_rounded,
              color: Color(0xFF4B5563), size: 38),
        ),
        const SizedBox(height: 14),
        const Text(
          'Transfer cancelled',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'No money moved. You may have avoided a scam.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AuraColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.transferForm),
            child: const Text('Start over',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AuraColors.textPrimary)),
          ),
        ),
      ],
    );
  }

  // H. Transfer Blocked (p-blocked)
  Widget _buildPhoneBlockedView() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFEE2E2),
          ),
          child: const Icon(Icons.pan_tool_rounded,
              color: Color(0xFFDC2626), size: 40),
        ),
        const SizedBox(height: 14),
        const Text(
          'Transfer blocked',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'We stopped this transfer to protect your money. Contact support if this was you.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AuraColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFE4E6)),
          ),
          child: const Text(
            'Velocity above 1,000 km/h or baseline score 0.50+ stops the transfer outright. No SMS OTP and no bypass.',
            style: TextStyle(fontSize: 11, color: AuraColors.textSecondary),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E1E2D),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.transferForm),
            child: const Text('Back to start',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // I. Step-Up MPIN (p-stepup)
  Widget _buildPhoneStepUpView() {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFEF3C7),
          ),
          child: const Icon(Icons.lock_rounded,
              color: Color(0xFFD97706), size: 32),
        ),
        const SizedBox(height: 12),
        const Text(
          'Confirm it\'s you',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AuraColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Use your biometrics and enter your MPIN on this device.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AuraColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final isFilled = index < _enteredMpin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? AuraColors.primary : Colors.white,
                border: Border.all(
                  color: isFilled
                      ? AuraColors.primary
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AuraColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: () => _goToNode(ShowcaseNode.transferSent),
            child: const Text('Approve',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // 5 Threat Chips Bar
  Widget _buildThreatChipsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_threats.length, (index) {
          final threat = _threats[index];
          final isSelected = _selectedThreatIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ChoiceChip(
              label: Text(
                threat.key,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AuraColors.textSecondary,
                ),
              ),
              selected: isSelected,
              selectedColor: threat.isCritical
                  ? const Color(0xFFE11D48)
                  : const Color(0xFFD97706),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? Colors.transparent
                    : const Color(0xFFE5E7EB),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onSelected: (selected) {
                if (selected) {
                  _selectThreat(index);
                  if (_currentNode != ShowcaseNode.advisoryWarning) {
                    _goToNode(ShowcaseNode.advisoryWarning);
                  }
                }
              },
            ),
          );
        }),
      ),
    );
  }

  // Explanatory Stage Details Card (#cap)
  Widget _buildEngineStageCard() {
    String stageType;
    String stageTitle;
    String stageDesc;

    switch (_currentNode) {
      case ShowcaseNode.transferForm:
        stageType = 'Customer enters transfer';
        stageTitle = 'Customer transfer (T)';
        stageDesc =
            'The customer enters payee and amount. Device telemetry travels with the request. The memo is ignored.';
        break;
      case ShowcaseNode.gate0Scan:
        stageType = 'Backend decision';
        stageTitle = 'Gate 0: Hard rules (G)';
        stageDesc =
            'Velocity above 1,000 km/h, tampering or mock GPS blocks the transfer outright.';
        break;
      case ShowcaseNode.xgboostScore:
        stageType = 'Backend decision';
        stageTitle = 'XGBoost S2: Baseline tier (X)';
        stageDesc =
            'Scores spike ratio, balance drain and payee age. 0.50+ blocks, 0.40+ steps up, below that continues.';
        break;
      case ShowcaseNode.nanojevContext:
        stageType = 'Backend decision';
        stageTitle = 'NanoJev: Threat synthesis (N)';
        stageDesc =
            'Reads remote-app, call, clipboard and payee signals. It can raise friction but never lower it.';
        break;
      case ShowcaseNode.biometrics:
        stageType = 'Customer sees';
        stageTitle = 'Allow: Biometric (A)';
        stageDesc =
            'Clean context: hardware biometrics approve the transfer. Zero SMS OTP.';
        break;
      case ShowcaseNode.transferSent:
        stageType = 'Customer sees';
        stageTitle = 'Ledger settlement (D)';
        stageDesc =
            'Biometric confirmed, funds committed. Audit log and review queue are written asynchronously.';
        break;
      case ShowcaseNode.advisoryWarning:
        stageType = 'Customer sees';
        stageTitle = 'Advisory warning (V)';
        stageDesc =
            'Threat found: the customer sees a plain-language dialog with a short read delay. Switch the threat type above.';
        break;
      case ShowcaseNode.coolOffHold:
        stageType = 'Customer sees';
        stageTitle = '10-minute cool-off (H)';
        stageDesc =
            'The customer paused. Funds stay in the account while they verify.';
        break;
      case ShowcaseNode.transferCancelled:
        stageType = 'Customer sees';
        stageTitle = 'Cancelled (C)';
        stageDesc =
            'The customer cancelled after the warning: a possible scam, avoided.';
        break;
      case ShowcaseNode.transferBlocked:
        stageType = 'Customer sees';
        stageTitle = 'Blocked (B)';
        stageDesc =
            'A hard rule or a baseline score of 0.50+ stops the transfer. No SMS OTP and no bypass.';
        break;
      case ShowcaseNode.stepUpMpin:
        stageType = 'Customer sees';
        stageTitle = 'Step-up (S)';
        stageDesc =
            'Medium risk: the bound primary device asks for biometrics and an MPIN.';
        break;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stageType.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: AuraColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            stageTitle,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AuraColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            stageDesc,
            style: const TextStyle(
                fontSize: 11, height: 1.4, color: AuraColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SimpleRadarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

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
      ..strokeWidth = 3.5;

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

class _SimpleDashedPainter extends CustomPainter {
  final Color color;

  _SimpleDashedPainter({this.color = const Color(0xFFFDA4AF)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    const dashWidth = 3.5;
    const dashSpace = 3.5;
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
