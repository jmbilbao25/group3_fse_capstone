import 'package:flutter/material.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/motion.dart';
import '../../widgets/aurora_background.dart';
import '../../models/user_persona.dart';
import '../../services/auth_api_service.dart';
import '../../services/bank_service.dart';
import '../../services/biometric_service.dart';
import '../../services/device_storage.dart';
import '../../services/notification_stream_service.dart';
import '../../services/security_service.dart';
import '../../widgets/aura_logo.dart';
import 'otp_verification_screen.dart';
import 'pending_approval_screen.dart';
import 'register_screen.dart';

/// Paper well, 56 px, label kept inside so a prefilled field stays named.
/// Shared with the register form so both sheets read as one family.
InputDecoration auraFieldDecoration(String label, {Widget? suffixIcon, String? hintText}) {
  final radius = BorderRadius.circular(16);
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    labelStyle: const TextStyle(color: AuraColors.textSecondary),
    filled: true,
    fillColor: AuraColors.canvas,
    contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
    suffixIcon: suffixIcon,
    enabledBorder: UnderlineInputBorder(
        borderRadius: radius, borderSide: BorderSide.none),
    focusedBorder: UnderlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AuraColors.ink, width: 2)),
    errorBorder: UnderlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AuraColors.debitRed, width: 1.2)),
    focusedErrorBorder: UnderlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: AuraColors.debitRed, width: 2)),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final BankService _bankService = BankService();
  final TextEditingController _usernameController =
      TextEditingController(text: 'elijahriley.montefalco@gmail.com');
  final TextEditingController _passwordController =
      TextEditingController(text: 'Montefalco@2026');
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showPasswordFields = false; // For biometric-first mode
  bool _hasAutoPrompted = false;

  static const Color brandViolet = Color(0xFF10171C);
  static const Color borderViolet = Color(0xFF2F78A8);
  static const Color disabledButtonBg = Color(0xFFF1EEFB);
  static const Color disabledButtonText = Color(0xFFD5CDF2);

  bool get _hasFingerprint => _bankService.user.fingerprintEnabled;
  bool get _hasFaceId => _bankService.user.faceIdEnabled;
  bool get _hasAnyBiometric => _hasFingerprint || _hasFaceId;

  @override
  void initState() {
    super.initState();
    NotificationStreamService().disconnect();
    _bankService.addListener(_onServiceUpdate);
    _loadPreferences();
  }

  void _loadPreferences() async {
    await _bankService.initPreferences();
    if (mounted) {
      setState(() {});
      if (_hasAnyBiometric && !_showPasswordFields && !_hasAutoPrompted) {
        _hasAutoPrompted = true;
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _hasAnyBiometric && !_showPasswordFields) {
            if (_hasFaceId) {
              _authenticateWithFaceId();
            } else if (_hasFingerprint) {
              _authenticateWithFingerprint();
            }
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _bankService.removeListener(_onServiceUpdate);
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _onSignIn() async {
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    final email = _usernameController.text.trim();
    final password = _passwordController.text;

    // 1. Pre-flight hardware & device integrity check
    final assessment = await SecurityService.assessDevice();
    if (assessment.isCompromised) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await SecurityService.showWarningDialogAndExit(
        context,
        reason: assessment.summary,
      );
      return;
    }

    // 2. Call AuthApiService to authenticate against backend
    final authResult = await AuthApiService().login(
      email: email,
      password: password,
      deviceId: DeviceIdentity().id,
      deviceName: DeviceIdentity().name,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (authResult.status == AuthStatus.mfaRequired) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => OtpVerificationScreen(
            email: authResult.maskedEmail ?? email,
            rawEmail: email,
            userId: authResult.userId ?? 'USR-0001',
            persona: authResult.persona,
            onVerified: () {
              Navigator.of(ctx).pop();
              if (AuthApiService().isDeviceApproved == false) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (pCtx) => PendingApprovalScreen(
                      user: authResult.persona ??
                          UserPersona(
                            name: 'Aura User',
                            role: 'Customer',
                            email: email,
                            password: password,
                            accountId: '1000-4491-0023',
                            balance: 250000.0,
                          ),
                      onApproved: () {
                        Navigator.of(pCtx).pushReplacementNamed('/dashboard');
                      },
                      onCancel: () {
                        AuthApiService().logout();
                        Navigator.of(pCtx).pop();
                      },
                    ),
                  ),
                );
              } else {
                Navigator.of(context).pushReplacementNamed('/dashboard');
              }
            },
          ),
        ),
      );
    } else if (authResult.status == AuthStatus.pendingApproval ||
        (authResult.status == AuthStatus.authenticated &&
            authResult.isApproved == false)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (pCtx) => PendingApprovalScreen(
            user: authResult.persona ??
                UserPersona(
                  name: 'Aura User',
                  role: 'Customer',
                  email: email,
                  password: password,
                  accountId: '1000-4491-0023',
                  balance: 250000.0,
                ),
            onApproved: () {
              Navigator.of(pCtx).pushReplacementNamed('/dashboard');
            },
            onCancel: () {
              AuthApiService().logout();
              Navigator.of(pCtx).pop();
            },
          ),
        ),
      );
    } else if (authResult.status == AuthStatus.authenticated) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authResult.errorMessage ??
              'Authentication failed. Please check credentials.'),
          backgroundColor: const Color(0xFFC53030),
        ),
      );
    }
  }

  void _authenticateWithFingerprint() {
    _showBiometricAuthSheet(
      title: 'Fingerprint Authentication',
      subtitle: 'Touch the fingerprint sensor to unlock Aura Bank',
      icon: const Icon(Icons.fingerprint_rounded, size: 70, color: brandViolet),
      authType: 'Fingerprint',
    );
  }

  void _authenticateWithFaceId() {
    _showBiometricAuthSheet(
      title: 'Face ID Verification',
      subtitle: 'Position your face in front of the camera',
      icon: SizedBox(
        width: 70,
        height: 70,
        child: CustomPaint(
          painter: _FaceIdIconPainter(color: brandViolet),
        ),
      ),
      authType: 'Face ID',
    );
  }

  void _showBiometricAuthSheet({
    required String title,
    required String subtitle,
    required Widget icon,
    required String authType,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _BiometricAuthModal(
        title: title,
        subtitle: subtitle,
        icon: icon,
        authType: authType,
        onSuccess: () {
          if (AuthApiService().currentAccessToken == null ||
              AuthApiService().currentAccessToken!.isEmpty) {
            AuthApiService().currentAccessToken =
                DeviceStorage.getAccessToken() ??
                    'bio-session-${DateTime.now().millisecondsSinceEpoch}';
          }
          if (AuthApiService().currentUserId == null ||
              AuthApiService().currentUserId!.isEmpty) {
            AuthApiService().currentUserId =
                DeviceStorage.getUserId() ?? 'USR-100001';
          }
          AuthApiService().currentIsApproved = true;
          Navigator.of(context).pop();
          Navigator.of(context).pushReplacementNamed('/dashboard');
        },
      ),
    );
  }

  /// Form Body: either standard credentials OR biometric-first view
  Widget _buildFormBody() => _hasAnyBiometric && !_showPasswordFields
      ? _buildBiometricFirstView()
      : _buildStandardLoginView();

  /// First name of the profile on this device, while its email is the one in
  /// the username field. Switch Account clears the field and the name goes.
  String? get _rememberedFirstName {
    final user = _bankService.user;
    return _usernameController.text.trim() == user.email
        ? user.name.split(' ').first
        : null;
  }

  Widget _buildGreeting({required bool onDark}) => ListenableBuilder(
        listenable: _usernameController,
        builder: (context, _) =>
            _LoginGreeting(firstName: _rememberedFirstName, onDark: onDark),
      );

  /// Form then footer, rising in just behind the greeting.
  Widget _buildSheetContents() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Reveal(delay: Reveal.stagger(0, base: 160), child: _buildFormBody()),
          Reveal(delay: Reveal.stagger(1, base: 160), child: _buildFooter()),
        ],
      );

  /// Wordmark with the account-opening entry opposite it, as on the landing
  /// header. The 48 px button sets the row height on both layouts.
  Widget _buildHeader({required bool onDark}) => Row(
        children: [
          AuraWordmark(size: 30, onDark: onDark),
          const Spacer(),
          TextButton(
            key: const ValueKey('createAccountLink'),
            style: TextButton.styleFrom(
                foregroundColor: onDark ? Colors.white : AuraColors.ink),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
            child: const Text('Create account'),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 600) return _buildWideLayout();

    // Phones: the aurora is the screen and the form is a paper sheet docked to
    // its bottom edge. Scaffold lifts the body above the keyboard (viewInsets);
    // the sky gives up its height first, then the whole column scrolls.
    return Scaffold(
      backgroundColor: AuraColors.ink,
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Both layers run under the sheet so its rounded
                        // corners sit on sky, not on a seam.
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: -40,
                          child: AuroraBackground(intensity: 0.9),
                        ),
                        // Night settles toward the sheet, so the greeting
                        // holds AA contrast whatever the curtains are doing.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -40,
                          height: 300,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0, 0.6],
                                colors: [
                                  AuraColors.ink.withValues(alpha: 0),
                                  AuraColors.ink.withValues(alpha: 0.8),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            // 12 + the 48 px header row keeps the wordmark where it sat at 20.
                            padding: const EdgeInsets.fromLTRB(24, 12, 12, 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(onDark: true),
                                const Spacer(),
                                const SizedBox(height: 48),
                                _buildGreeting(onDark: true),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    key: const ValueKey('loginSheet'),
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                    decoration: const BoxDecoration(
                      color: AuraColors.surface,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SafeArea(top: false, child: _buildSheetContents()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tablet and desktop: the same sky fills the window and the paper sheet
  /// floats in its centre, carrying the greeting in ink.
  Widget _buildWideLayout() {
    return Scaffold(
      backgroundColor: AuraColors.ink,
      body: AuroraBackground(
        intensity: 0.9,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                key: const ValueKey('loginSheet'),
                width: 440,
                // 27 + the 48 px header row keeps the wordmark where it sat at 36.
                padding: const EdgeInsets.fromLTRB(36, 27, 36, 16),
                decoration: BoxDecoration(
                  color: AuraColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AuraColors.primaryDark.withValues(alpha: 0.5),
                      blurRadius: 48,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(onDark: false),
                    const SizedBox(height: 23),
                    _buildGreeting(onDark: false),
                    const SizedBox(height: 28),
                    _buildSheetContents(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Footer: Forgot Passcode? • Switch Account
  Widget _buildFooter() {
    final link = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              style: link.copyWith(
                  foregroundColor:
                      const WidgetStatePropertyAll(AuraColors.textSecondary)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Password recovery link sent to your registered email.'),
                    backgroundColor: brandViolet,
                  ),
                );
              },
              child: const Text(
                "Forgot Passcode?",
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.circle, size: 4, color: AuraColors.textMuted),
            TextButton(
              style: link,
              onPressed: () {
                _usernameController.clear();
                _passwordController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Account switched. Enter your credentials.'),
                    backgroundColor: brandViolet,
                  ),
                );
              },
              child: const Text(
                "Switch Account",
                style: TextStyle(fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Standard Login View (matches Top row of mockup: fields + Sign In + Biometrics below)
  Widget _buildStandardLoginView() {
    return Column(
      children: [
        // Username Field
        TextField(
          controller: _usernameController,
          style: const TextStyle(fontSize: 15),
          decoration: auraFieldDecoration("Username"),
        ),

        const SizedBox(height: 12),

        // Password Field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(fontSize: 15),
          decoration: auraFieldDecoration(
            "Password",
            suffixIcon: IconButton(
              key: const ValueKey('passwordVisibilityToggle'),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: brandViolet,
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Sign in Button (Purple if password only, or clean styling if biometrics available)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _onSignIn,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _hasAnyBiometric ? disabledButtonBg : brandViolet,
              foregroundColor: _hasAnyBiometric ? brandViolet : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    "Sign in",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          _hasAnyBiometric ? disabledButtonText : Colors.white,
                    ),
                  ),
          ),
        ),

        // Biometric Icons directly below Sign In button (matches Top Row of mockup)
        if (_hasAnyBiometric) ...[
          const SizedBox(height: 24),
          _buildBiometricIconsRow(),
        ],
      ],
    );
  }

  /// 2. Biometric-First View (matches Bottom row of mockup: big biometric scanner + buttons)
  Widget _buildBiometricFirstView() {
    return Column(
      children: [
        const SizedBox(height: 20),

        // Main Biometric Large Action Icon
        if (_hasFaceId && !_hasFingerprint) ...[
          _buildFaceIdBigCircle(),
        ] else if (_hasFingerprint && !_hasFaceId) ...[
          _buildFingerprintBigCircle(),
        ] else ...[
          // Both active: show Face ID as primary + Use Fingerprints secondary
          _buildFaceIdBigCircle(),
        ],

        const SizedBox(height: 32),

        // If BOTH Face ID and Fingerprint are active: show "Use Fingerprints" button
        if (_hasFaceId && _hasFingerprint) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _authenticateWithFingerprint,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: borderViolet, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'Use Fingerprints',
                style: TextStyle(
                  color: brandViolet,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // "Use password instead" purple button (matches mockup)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              setState(() => _showPasswordFields = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandViolet,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Use password instead',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Biometric icons displayed when in standard login mode
  Widget _buildBiometricIconsRow() {
    if (_hasFingerprint && _hasFaceId) {
      // Both active: render both icons side by side
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFingerprintButton(),
              const SizedBox(width: 32),
              _buildFaceIdButton(),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap Fingerprint or Face ID to sign in',
            style: TextStyle(
                fontSize: 11.5,
                color: AuraColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else if (_hasFingerprint) {
      // Fingerprint only
      return Column(
        children: [
          _buildFingerprintButton(),
          const SizedBox(height: 10),
          const Text(
            'Tap fingerprint sensor to sign in',
            style: TextStyle(
                fontSize: 11.5,
                color: AuraColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else {
      // Face ID only
      return Column(
        children: [
          _buildFaceIdButton(),
          const SizedBox(height: 10),
          const Text(
            'Tap Face ID to glance and sign in',
            style: TextStyle(
                fontSize: 11.5,
                color: AuraColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      );
    }
  }

  Widget _buildFingerprintBigCircle() {
    return GestureDetector(
      onTap: _authenticateWithFingerprint,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.fingerprint_rounded,
            size: 68,
            color: Color(0xFF173039),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceIdBigCircle() {
    return GestureDetector(
      onTap: _authenticateWithFaceId,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 54,
            height: 54,
            child: CustomPaint(
              painter: _FaceIdIconPainter(color: const Color(0xFF173039)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFingerprintButton() {
    return GestureDetector(
      onTap: _authenticateWithFingerprint,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.fingerprint_rounded,
            size: 42,
            color: Color(0xFF173039),
          ),
        ),
      ),
    );
  }

  Widget _buildFaceIdButton() {
    return GestureDetector(
      onTap: _authenticateWithFaceId,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: borderViolet.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CustomPaint(
              painter: _FaceIdIconPainter(color: const Color(0xFF173039)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Face ID Vector Icon Painter
class _FaceIdIconPainter extends CustomPainter {
  final Color color;

  _FaceIdIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final cornerLen = w * 0.26;
    final r = w * 0.14;

    // Top-left bracket
    final pathTL = Path()
      ..moveTo(0, cornerLen)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(cornerLen, 0);
    canvas.drawPath(pathTL, paint);

    // Top-right bracket
    final pathTR = Path()
      ..moveTo(w - cornerLen, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(cornerLen, 0);
    canvas.drawPath(pathTR, paint);

    // Bottom-left bracket
    final pathBL = Path()
      ..moveTo(0, h - cornerLen)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
      ..lineTo(cornerLen, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-right bracket
    final pathBR = Path()
      ..moveTo(w - cornerLen, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
      ..lineTo(w, h - cornerLen);
    canvas.drawPath(pathBR, paint);

    // Eyes
    final eyePaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.35, h * 0.38),
      Offset(w * 0.35, h * 0.46),
      eyePaint,
    );
    canvas.drawLine(
      Offset(w * 0.65, h * 0.38),
      Offset(w * 0.65, h * 0.46),
      eyePaint,
    );

    // Nose
    final nosePath = Path()
      ..moveTo(w * 0.50, h * 0.40)
      ..lineTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.44, h * 0.56);
    canvas.drawPath(nosePath, eyePaint);

    // Smile Arc
    final smileRect = Rect.fromCircle(
      center: Offset(w * 0.5, h * 0.54),
      radius: w * 0.18,
    );
    canvas.drawArc(smileRect, 0.45, 2.24, false, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _FaceIdIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Interactive Biometric Verification Modal connected to real device hardware
class _BiometricAuthModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final String authType;
  final VoidCallback onSuccess;

  const _BiometricAuthModal({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.authType,
    required this.onSuccess,
  });

  @override
  State<_BiometricAuthModal> createState() => _BiometricAuthModalState();
}

class _BiometricAuthModalState extends State<_BiometricAuthModal> {
  final BiometricService _biometricService = BiometricService();
  bool _verified = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNativeAuth();
    });
  }

  Future<void> _startNativeAuth() async {
    if (!mounted) return;
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });

    final bool isSupported = await _biometricService.canAuthenticate();
    if (!isSupported) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage =
              '${widget.authType} is not supported or not enrolled in your device Settings.';
        });
      }
      return;
    }

    try {
      final bool authenticated = await _biometricService.authenticate(
        reason:
            'Please scan your ${widget.authType} to verify and sign in to Aura Bank',
        biometricOnly: false,
      );

      if (!mounted) return;

      if (authenticated) {
        setState(() {
          _verified = true;
          _hasError = false;
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          widget.onSuccess();
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = '${widget.authType} was cancelled or not recognized.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Biometric sensor error. Tap Try Again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFEAECEE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _verified
                  ? const Color(0xFFE4F5EE)
                  : (_hasError
                      ? const Color(0xFFFBE9E7)
                      : const Color(0xFFE6F6EF)),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: _verified
                  ? const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF17805F), size: 54)
                  : (_hasError
                      ? const Icon(Icons.error_outline_rounded,
                          color: Color(0xFFC8423B), size: 50)
                      : widget.icon),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _verified
                ? '${widget.authType} Verified!'
                : (_hasError ? 'Verification Unsuccessful' : widget.title),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10171C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _verified
                ? 'Logging into Aura Bank...'
                : (_hasError
                    ? (_errorMessage ??
                        'Biometrics not recognized. Please try again.')
                    : widget.subtitle),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:
                  _hasError ? const Color(0xFFC8423B) : const Color(0xFF7D8892),
            ),
          ),
          const SizedBox(height: 24),
          if (_hasError) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _startNativeAuth,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10171C),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Try ${widget.authType} Again'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel & Use Password',
                style: TextStyle(
                    color: Color(0xFF7D8892), fontWeight: FontWeight.w600),
              ),
            ),
          ] else if (!_verified) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                    color: Color(0xFF7D8892), fontWeight: FontWeight.w600),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// White over the sky on phones, ink on the paper card on wide screens. The
/// remembered account's first name takes the brand accent.
class _LoginGreeting extends StatelessWidget {
  const _LoginGreeting({required this.firstName, required this.onDark});

  final String? firstName;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final name = firstName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Reveal(
          child: Text.rich(
            TextSpan(
              text: name == null ? 'Welcome back' : 'Welcome back,\n',
              children: [
                if (name != null)
                  TextSpan(
                    text: name,
                    style: TextStyle(
                        color: onDark ? AuraColors.mint : AuraColors.accent),
                  ),
              ],
            ),
            style: TextStyle(
              fontSize: onDark ? 40 : 34,
              height: 1.08,
              fontWeight: FontWeight.w600,
              letterSpacing: onDark ? -1.2 : -1,
              color: onDark ? Colors.white : AuraColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Reveal(
          delay: const Duration(milliseconds: 90),
          child: Text(
            'Please enter your email and password',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: onDark
                  ? Colors.white.withValues(alpha: 0.78)
                  : AuraColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
