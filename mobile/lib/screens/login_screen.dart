import 'package:flutter/material.dart';
import '../models/user_persona.dart';
import '../services/auth_api_service.dart';
import '../widgets/brand_logo.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  final ValueChanged<UserPersona> onLoginSuccess;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Hardware device identity is automatically detected based on platform
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _showServerConfigDialog() {
    final hostController = TextEditingController(text: BackendConfig().host);
    bool? testPassed;
    bool isTesting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded, color: Color(0xFF3A4CD6)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Backend Server Network Host',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When testing from a physical phone on your local Wi-Fi, enter your laptop\'s IP address so the phone can reach the backend services.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host / IP Address',
                      hintText: 'e.g. 192.168.254.159 or localhost',
                      prefixIcon: Icon(Icons.lan_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.phone_android_rounded, size: 14),
                        label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setSheetState(() {
                            hostController.text = '10.0.2.2';
                            testPassed = null;
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.laptop_mac_rounded, size: 14),
                        label: const Text('Laptop IP (192.168.254.159)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setSheetState(() {
                            hostController.text = BackendConfig.defaultLanIp;
                            testPassed = null;
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.computer_rounded, size: 14),
                        label: const Text('Localhost (127.0.0.1)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          setSheetState(() {
                            hostController.text = 'localhost';
                            testPassed = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (testPassed != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: testPassed!
                            ? Colors.green.withAlpha(24)
                            : Colors.red.withAlpha(24),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            testPassed! ? Icons.check_circle_outline : Icons.error_outline,
                            size: 16,
                            color: testPassed! ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              testPassed!
                                  ? 'Connected successfully to Account Service (:8081)!'
                                  : 'Could not connect. Ensure backend is running and phone is on the same Wi-Fi.',
                              style: TextStyle(
                                fontSize: 12,
                                color: testPassed! ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.devices_rounded, size: 16, color: Color(0xFF3A4CD6)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Device Profile (Simulation / Override)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'In real life, your device is auto-detected. In simulation tests on a single machine, you can override identity here:',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: DevicePreset.presets.map((preset) {
                      final isSelected = DeviceIdentity().id == preset.id;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(preset.label, style: const TextStyle(fontSize: 11)),
                        onSelected: (selected) {
                          if (selected) {
                            setSheetState(() {
                              AuthApiService().switchDevice(preset);
                            });
                            setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isTesting
                              ? null
                              : () async {
                                  setSheetState(() => isTesting = true);
                                  BackendConfig().host = hostController.text.trim();
                                  final ok = await BackendConfig().testConnection();
                                  setSheetState(() {
                                    isTesting = false;
                                    testPassed = ok;
                                  });
                                },
                          child: isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Test Connection'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            BackendConfig().host = hostController.text.trim();
                            Navigator.of(ctx).pop();
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Backend host configured: ${BackendConfig().host}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _fillPersona(UserPersona persona) {
    setState(() {
      _emailController.text = persona.email;
      _passwordController.text = persona.password;
      _errorMessage = null;
    });
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final matchedPersona = UserPersona.demoPersonas.firstWhere(
      (p) => p.email.toLowerCase() == email.toLowerCase(),
      orElse: () => UserPersona(
        name: email.split('@').first.replaceAll('.', ' ').toUpperCase(),
        role: 'Customer',
        email: email,
        password: password,
        accountId: '1000-4491-0023',
        balance: 250000.00,
      ),
    );

    // Call AuthApiService to authenticate against backend account-service
    final authResult = await AuthApiService().login(
      email: email,
      password: password,
      deviceId: DeviceIdentity().id,
      deviceName: DeviceIdentity().name,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (authResult.status == AuthStatus.mfaRequired) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => OtpVerificationScreen(
            user: authResult.persona ?? matchedPersona,
            userId: authResult.userId ?? 'USR-0001',
            maskedEmail: authResult.maskedEmail ?? email,
            onVerified: (user) {
              Navigator.of(ctx).pop();
              widget.onLoginSuccess(user);
            },
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    } else if (authResult.status == AuthStatus.authenticated) {
      widget.onLoginSuccess(authResult.persona ?? matchedPersona);
    } else {
      setState(() {
        _errorMessage = authResult.errorMessage ?? 'Authentication failed. Please check your credentials.';
      });
    }
  }

  void _showForgotPasswordDialog() {
    final resetController = TextEditingController(text: _emailController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email address and we will send you a secure verification link.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = resetController.text.trim();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    email.isNotEmpty
                        ? 'Password reset instructions sent to $email'
                        : 'Please enter a valid email address.',
                  ),
                ),
              );
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _handleBiometricLogin() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.fingerprint_rounded,
                size: 64,
                color: Color(0xFF3A4CD6),
              ),
              const SizedBox(height: 16),
              const Text(
                'Biometric Authentication',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Scan your fingerprint or verify Face ID to access your AuraBank accounts.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Use Password'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _fillPersona(UserPersona.demoPersonas.first);
                        _handleLogin();
                      },
                      child: const Text('Simulate Match'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Server Connection Settings',
            icon: const Icon(Icons.wifi_tethering_rounded),
            onPressed: _showServerConfigDialog,
          ),
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
                  // Brand Lockup Header
                  const BrandLockup(markSize: 52),
                  const SizedBox(height: 28),

                  // Quick fill persona shortcuts
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C323D) : const Color(0xFFE4E6EA),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF3A4CD6)),
                            const SizedBox(width: 6),
                            Text(
                              'Demo Quick-Fill',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[300] : const Color(0xFF1A1D21),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: UserPersona.demoPersonas.map((persona) {
                            return ActionChip(
                              avatar: CircleAvatar(
                                backgroundColor: const Color(0xFF3A4CD6),
                                radius: 10,
                                child: Text(
                                  persona.name[0],
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                              label: Text('${persona.name} (${persona.role})'),
                              labelStyle: const TextStyle(fontSize: 12),
                              onPressed: () => _fillPersona(persona),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Automatic Hardware Device Identity Banner (Realistic Real-World)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF1F3F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C323D) : const Color(0xFFE4E6EA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          DeviceIdentity().id.contains('laptop') || DeviceIdentity().id.contains('desktop')
                              ? Icons.laptop_mac_rounded
                              : Icons.smartphone_rounded,
                          size: 20,
                          color: const Color(0xFF3A4CD6),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'This Device: ${DeviceIdentity().name}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[200] : const Color(0xFF1A1D21),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Configuration: 1 Web session + 2 Mobiles allowed. 1st mobile login is permanently Primary. Desktop logins dispatch push alerts to your primary phone.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          tooltip: 'Device & Network Settings',
                          color: Colors.grey[500],
                          onPressed: _showServerConfigDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Optional Error Banner
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

                  // Form Container
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                          decoration: InputDecoration(
                            labelText: 'Email Address',
                            hintText: 'name@example.com',
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                            suffixIcon: _emailController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _emailController.clear();
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email address.';
                            }
                            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email format.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password.';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // Remember Me and Forgot Password row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (val) {
                                      setState(() {
                                        _rememberMe = val ?? false;
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _rememberMe = !_rememberMe;
                                    });
                                  },
                                  child: const Text(
                                    'Remember me',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: _showForgotPasswordDialog,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3A4CD6),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Primary Sign In Button
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF3A4CD6),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF3A4CD6).withAlpha(120),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Biometrics option
                        SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleBiometricLogin,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? const Color(0xFF2C323D) : const Color(0xFFD0D5DD),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.fingerprint_rounded,
                              size: 22,
                              color: Color(0xFF3A4CD6),
                            ),
                            label: const Text(
                              'Sign in with Biometrics',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Security Footer
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: isDark ? Colors.grey[500] : const Color(0xFF6E7787),
                        ),
                        Text(
                          '256-Bit SSL Encryption • BSP Regulated',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[500] : const Color(0xFF6E7787),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
