import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_persona.dart';
import '../services/auth_api_service.dart';
import '../services/otp_service.dart';
import '../widgets/brand_logo.dart';

class OtpVerificationScreen extends StatefulWidget {
  final UserPersona user;
  final String userId;
  final String maskedEmail;
  final ValueChanged<UserPersona> onVerified;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const OtpVerificationScreen({
    super.key,
    required this.user,
    required this.userId,
    required this.maskedEmail,
    required this.onVerified,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  final _otpService = OtpService();
  final _authApiService = AuthApiService();

  bool _isVerifying = false;
  bool _isCheckingMailHog = false;
  MailHogEmail? _latestEmail;
  String? _errorMessage;
  int _secondsRemaining = 300; // 5 minutes
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMailHogEmail();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _secondsRemaining = 300;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get _currentEnteredOtp {
    return _controllers.map((c) => c.text).join();
  }

  void _autoFillOtp(String code) {
    if (code.length != 6) return;
    for (int i = 0; i < 6; i++) {
      _controllers[i].text = code[i];
    }
    setState(() {
      _errorMessage = null;
    });
    _handleVerify();
  }

  Future<void> _fetchMailHogEmail() async {
    setState(() {
      _isCheckingMailHog = true;
    });

    final email = await _otpService.fetchLatestEmail(
      recipientEmail: widget.user.email,
    );

    if (!mounted) return;

    setState(() {
      _latestEmail = email;
      _isCheckingMailHog = false;
    });

    if (email != null && email.otpCode != null) {
      _showIncomingEmailSnackBar(email);
    }
  }

  void _showIncomingEmailSnackBar(MailHogEmail email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E2229),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.mark_email_unread_rounded, color: Color(0xFF6B7FFF), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Live MailHog: New OTP Email Received',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Code: ${email.otpCode ?? 'Found'} • Tap to view email or auto-fill',
                    style: TextStyle(color: Colors.grey[300], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View Email',
          textColor: const Color(0xFF6B7FFF),
          onPressed: _openEmailModal,
        ),
      ),
    );
  }

  void _openEmailModal() {
    final isDark = widget.isDarkMode;
    final email = _latestEmail;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2229) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(100),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A4CD6).withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.email_outlined,
                            color: Color(0xFF3A4CD6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MailHog Live Inbox (:8025)',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Captured from backend notification-service',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (email != null) ...[
                    // Email Metadata
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14171C) : const Color(0xFFF6F8FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C323D) : const Color(0xFFE4E6EA),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From: ${email.from}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'To: ${email.to}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Subject: ${email.subject}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email Body
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14171C) : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C323D) : const Color(0xFFE4E6EA),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Your First-Time Login verification code is:',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A4CD6).withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF3A4CD6)),
                            ),
                            child: Text(
                              email.otpCode ?? '------',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                color: Color(0xFF3A4CD6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Expires in 5 minutes • Validated strictly by backend Redis store',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (email.otpCode != null) {
                                Clipboard.setData(ClipboardData(text: email.otpCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('OTP copied to clipboard!')),
                                );
                              }
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy Code'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('btn_autofill_verify'),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              if (email.otpCode != null) {
                                _autoFillOtp(email.otpCode!);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF3A4CD6),
                            ),
                            icon: const Icon(Icons.bolt_rounded, size: 18),
                            label: const Text('Auto-Fill & Verify'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    // MailHog Not Reachable or Empty
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withAlpha(120)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 28),
                          const SizedBox(height: 10),
                          const Text(
                            'Connecting to MailHog (:8025)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'The backend notification-service dispatches the OTP email via MailHog SMTP (:1025).\n\nIf MailHog is running in Docker, you can inspect all incoming emails in your browser at:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            'http://$defaultMailHogHost:8025',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF3A4CD6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await _fetchMailHogEmail();
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        _openEmailModal();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh from MailHog API'),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleVerify() async {
    final code = _currentEnteredOtp;
    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the code.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result = await _authApiService.verifyLoginOtp(
        userId: widget.userId,
        otp: code,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _isVerifying = false;
        });
        widget.onVerified(widget.user);
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = result.errorMessage ?? 'Invalid verification code. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Verification error: $e';
      });
    }
  }

  Future<void> _handleResend() async {
    // In strict backend mode, trigger login again to have account-service re-generate and send OTP
    setState(() {
      _errorMessage = null;
    });

    await _fetchMailHogEmail();
    _startTimer();

    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: widget.isDarkMode ? 'Switch to Light mode' : 'Switch to Dark mode',
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLockup(markSize: 44),
                  const SizedBox(height: 24),

                  // Icon & Heading
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A4CD6).withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 32,
                        color: Color(0xFF3A4CD6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'First-Time Login Verification',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Because this is your first login to AuraBank, enter the 6-digit code sent to:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    widget.maskedEmail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3A4CD6),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // View Email Banner / Action
                  InkWell(
                    onTap: _openEmailModal,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A4CD6).withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3A4CD6).withAlpha(70),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_unread_rounded,
                              size: 20, color: Color(0xFF3A4CD6)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _latestEmail != null
                                  ? 'View Received OTP Email (${_latestEmail!.otpCode ?? "Ready"})'
                                  : 'View MailHog Inbox (:8025)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3A4CD6),
                              ),
                            ),
                          ),
                          if (_isCheckingMailHog)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded,
                                size: 20, color: Color(0xFF3A4CD6)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withAlpha(80)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6 Digit Input Cells
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: TextFormField(
                          key: Key('otp_digit_$index'),
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (val) {
                            if (val.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (val.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            if (_currentEnteredOtp.length == 6) {
                              _handleVerify();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Countdown & Resend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: _secondsRemaining > 0 ? Colors.grey : Colors.red,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _secondsRemaining > 0
                                ? 'Expires in $_formattedTime'
                                : 'Code expired',
                            style: TextStyle(
                              fontSize: 13,
                              color: _secondsRemaining > 0 ? Colors.grey : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _secondsRemaining == 0 ? _handleResend : null,
                        child: const Text('Resend Code'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Verify Button
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _isVerifying ? null : _handleVerify,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3A4CD6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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
                              'Verify & Proceed to Dashboard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Security disclaimer
                  Center(
                    child: Text(
                      'Secured by Aura Multi-Factor Authentication Engine',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : const Color(0xFF6E7787),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
