import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_persona.dart';
import '../../services/auth_api_service.dart';
import '../../services/otp_service.dart';
import '../../theme/aura_theme.dart';
import 'pending_approval_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? rawEmail;
  final String? userId;
  final UserPersona? persona;
  final VoidCallback? onVerified;

  const OtpVerificationScreen({
    super.key,
    this.email = 'm••••@gmail.com',
    this.rawEmail,
    this.userId,
    this.persona,
    this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  /// Matches the backend's 5-minute OTP TTL.
  static const int _codeLifetimeSeconds = 300;

  int _secondsRemaining = _codeLifetimeSeconds;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMailHogEmail();
    });
  }

  Future<void> _fetchMailHogEmail() async {
    final email = await OtpService().fetchLatestEmail(
      recipientEmail: widget.rawEmail ?? widget.email,
    );
    if (!mounted || email == null || email.otpCode == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuraColors.primary,
        content: Text('Live MailHog OTP: ${email.otpCode}'),
        action: SnackBarAction(
          label: 'Auto-fill',
          textColor: Colors.white,
          onPressed: () {
            final code = email.otpCode!;
            for (int i = 0; i < 6 && i < code.length; i++) {
              _controllers[i].text = code[i];
            }
            setState(() {});
            _verifyCode();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = _codeLifetimeSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _currentOtp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // User pasted multiple characters
      final clean = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < clean.length; i++) {
        _controllers[i].text = clean[i];
      }
      if (clean.length >= 6) {
        _focusNodes[5].requestFocus();
      } else {
        _focusNodes[clean.length].requestFocus();
      }
      setState(() {});
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    setState(() {});
  }

  void _showIncompleteCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: const Text(
          'This page says',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Please enter the complete 6-digit code.',
          style: TextStyle(fontSize: 14, color: Color(0xFFD5DADF)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF1F3F4),
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _verifyCode() async {
    final otp = _currentOtp;
    if (otp.length < 6) {
      _showIncompleteCodeDialog();
      return;
    }

    if (_secondsRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code has expired. Tap "Resend code".'),
          backgroundColor: AuraColors.debitRed,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final result = await AuthApiService().verifyLoginOtp(
        userId: widget.userId ?? 'USR-0001',
        otp: otp,
      );

      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity verified securely with Aura Core Engine.'),
            backgroundColor: AuraColors.creditGreen,
          ),
        );

        if (widget.onVerified != null) {
          widget.onVerified!();
        } else {
          final isApproved = AuthApiService().isDeviceApproved;
          if (!isApproved) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (ctx) => PendingApprovalScreen(
                  user: widget.persona ??
                      UserPersona(
                        name: 'Aura User',
                        role: 'Customer',
                        email: widget.email,
                        password: '',
                        accountId: '1000-4491-0023',
                        balance: 250000.0,
                      ),
                  onApproved: () {
                    Navigator.of(ctx).pushReplacementNamed('/dashboard');
                  },
                  onCancel: () {
                    AuthApiService().logout();
                    Navigator.of(ctx).pop();
                  },
                ),
              ),
            );
          } else {
            Navigator.of(context).pushReplacementNamed('/dashboard');
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Invalid verification code. Please try again.'),
            backgroundColor: AuraColors.debitRed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification error: $e'),
          backgroundColor: AuraColors.debitRed,
        ),
      );
    }
  }

  void _resendCode() async {
    if (_isResending) return;
    setState(() => _isResending = true);
    final result = await AuthApiService().resendOtp(userId: widget.userId ?? 'USR-0001');
    if (!mounted) return;
    setState(() => _isResending = false);
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Could not send a new code.'),
          backgroundColor: AuraColors.debitRed,
        ),
      );
      return;
    }
    for (final c in _controllers) {
      c.clear();
    }
    _startCountdown();
    _focusNodes[0].requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('New 6-digit code dispatched to ${widget.email}'),
        backgroundColor: AuraColors.primary,
      ),
    );
    await _fetchMailHogEmail();
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _secondsRemaining <= 0;
    final formattedTime = '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:'
        '${(_secondsRemaining % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, box) => SingleChildScrollView(
          // Phone width on every screen, so the six boxes stay one group on desktop.
          padding: EdgeInsets.symmetric(horizontal: math.max(24.0, (box.maxWidth - 440) / 2), vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Back Arrow
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AuraColors.textPrimary, size: 24),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),

              const SizedBox(height: 24),

              // Envelope Icon Badge
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AuraColors.tintPurple,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AuraColors.borderPurple, width: 1),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  color: AuraColors.primary,
                  size: 28,
                ),
              ),

              const SizedBox(height: 22),

              // Title
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: AuraColors.textPrimary,
                ),
              ),

              const SizedBox(height: 10),

              // Description
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AuraColors.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: "We've sent a 6-digit verification code to "),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AuraColors.textPrimary,
                      ),
                    ),
                    const TextSpan(text: '.\nEnter the code below to continue.'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 6 PIN Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  final isFocused = _focusNodes[index].hasFocus;
                  final hasValue = _controllers[index].text.isNotEmpty;

                  return Container(
                    width: 48,
                    height: 58,
                    decoration: BoxDecoration(
                      color: hasValue ? AuraColors.bgLavender : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isFocused
                            ? AuraColors.primary
                            : hasValue
                                ? AuraColors.accentLight
                                : const Color(0xFFD5DADF),
                        width: isFocused ? 2.0 : 1.2,
                      ),
                      boxShadow: isFocused
                          ? [
                              BoxShadow(
                                color: AuraColors.primary.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AuraColors.primary,
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) => _onDigitChanged(index, val),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // Expiry Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Code expires in ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AuraColors.textSecondary,
                    ),
                  ),
                  Text(
                    isExpired ? 'Expired' : formattedTime,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isExpired ? AuraColors.debitRed : AuraColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Primary "Verify" Button (in main Royal Aura Violet)
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: AuraColors.buttonShadow,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  onPressed: _isVerifying ? null : _verifyCode,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 18),

              // Resend Code Button
              GestureDetector(
                onTap: _isResending ? null : _resendCode,
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: AuraColors.textSecondary),
                    children: [
                      TextSpan(text: "Didn't receive the code? "),
                      TextSpan(
                        text: 'Resend code',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AuraColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Security Notice Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F3F4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Text('🔒', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Never share your verification code with anyone. Aura Bank will never ask you to disclose your OTP.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AuraColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              // Need Help Footer
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.support_agent_rounded, size: 44, color: AuraColors.primary),
                          const SizedBox(height: 12),
                          const Text(
                            'Aura Priority Support',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Our Concierge Security Team is online 24/7.\nHotline: (02) 8888-AURA (2872)\nEmail: security@aurabank.ph',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AuraColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AuraColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 13, color: AuraColors.textSecondary),
                    children: [
                      TextSpan(text: 'Need help? '),
                      TextSpan(
                        text: 'Contact Support',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AuraColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        )),
      ),
    );
  }
}
