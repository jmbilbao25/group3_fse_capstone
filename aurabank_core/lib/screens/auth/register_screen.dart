import 'package:flutter/material.dart';

import '../../services/auth_api_service.dart';
import '../../theme/aura_theme.dart';
import '../../widgets/aura_logo.dart';
import '../../widgets/aurora_background.dart';
import '../../widgets/motion.dart';
import 'login_screen.dart' show auraFieldDecoration;
import 'otp_verification_screen.dart';

/// Account opening. Same sky and paper sheet as sign-in. The backend emails a
/// 6-digit code, which [OtpVerificationScreen] verifies as the first sign-in.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Codes match the KYC wizard and the staff console.
const _idTypes = {
  'PHILID': 'PhilSys National ID',
  'PASSPORT': 'Philippine passport',
  'DRIVERS_LICENSE': "Driver's license",
  'UMID': 'UMID',
  'POSTAL_ID': 'Postal ID',
};

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _phonePattern = RegExp(r'^\+?\d{10,15}$');
final _phoneSeparators = RegExp(r'[\s-]');

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _address = TextEditingController();
  final _idNumber = TextEditingController();
  final _password = TextEditingController();
  String? _idType;
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone, _dob, _address, _idNumber, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? Function(String?) _required(String message) =>
      (v) => v == null || v.trim().isEmpty ? message : null;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dob.text) ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) _dob.text = picked.toIso8601String().substring(0, 10);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;

    setState(() => _submitting = true);
    final email = _email.text.trim();
    final result = await AuthApiService().register({
      'first_name': _first.text.trim(),
      'last_name': _last.text.trim(),
      'email': email,
      'phone_number': _phone.text.replaceAll(_phoneSeparators, ''),
      'date_of_birth': _dob.text,
      'address_line': _address.text.trim(),
      'government_id_type': _idType!,
      'government_id_number': _idNumber.text.trim(),
      'password': _password.text,
    });
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.status != AuthStatus.mfaRequired) {
      setState(() => _error = result.errorMessage);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => OtpVerificationScreen(
        email: result.maskedEmail ?? email,
        rawEmail: email,
        userId: result.userId,
        onVerified: () => Navigator.of(ctx).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RegistrationCompleteScreen()),
          (_) => false,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return Scaffold(
      backgroundColor: AuraColors.ink,
      body: wide ? _wideLayout() : _phoneLayout(),
    );
  }

  /// Phone: the sky carries the heading and the paper sheet docks below it,
  /// reaching the bottom edge however short the form is.
  Widget _phoneLayout() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Both layers run under the sheet so its corners sit on sky.
              const Positioned(left: 0, right: 0, top: 0, bottom: -40, child: AuroraBackground(intensity: 0.9)),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: -40,
                // Night settles under the heading so white text holds AA contrast.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AuraColors.ink.withValues(alpha: 0.25), AuraColors.ink.withValues(alpha: 0.85)],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AuraWordmark(size: 30, onDark: true),
                      const SizedBox(height: 56),
                      _heading(onDark: true),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Container(
            key: const ValueKey('registerSheet'),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
            decoration: const BoxDecoration(
              color: AuraColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(top: false, child: _formBody()),
          ),
        ),
      ],
    );
  }

  /// Tablet and desktop: the paper card floats in the sky, as on sign-in.
  Widget _wideLayout() {
    return AuroraBackground(
      intensity: 0.9,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              key: const ValueKey('registerSheet'),
              width: 440,
              padding: const EdgeInsets.fromLTRB(36, 36, 36, 16),
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
                  const Align(alignment: Alignment.centerLeft, child: AuraWordmark(size: 30)),
                  const SizedBox(height: 32),
                  _heading(onDark: false),
                  const SizedBox(height: 28),
                  _formBody(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading({required bool onDark}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Reveal(
            child: Text(
              'Open an account',
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
              "Tell us who you are. We'll email you a code to confirm it's you.",
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: onDark ? Colors.white.withValues(alpha: 0.78) : AuraColors.textSecondary,
              ),
            ),
          ),
        ],
      );

  Widget _formBody() {
    const gap = SizedBox(height: 12);
    const style = TextStyle(fontSize: 15);
    return Reveal(
      delay: Reveal.stagger(0, base: 160),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _first,
                      style: style,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.givenName],
                      decoration: auraFieldDecoration('First name'),
                      validator: _required('Enter your first name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _last,
                      style: style,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.familyName],
                      decoration: auraFieldDecoration('Last name'),
                      validator: _required('Enter your last name'),
                    ),
                  ),
                ],
              ),
              gap,
              TextFormField(
                controller: _email,
                style: style,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: auraFieldDecoration('Email'),
                validator: (v) => _emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address',
              ),
              gap,
              TextFormField(
                controller: _phone,
                style: style,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: auraFieldDecoration('Mobile number', hintText: '+63 917 123 4567'),
                validator: (v) => _phonePattern.hasMatch((v ?? '').replaceAll(_phoneSeparators, ''))
                    ? null
                    : 'Enter a mobile number, like +63 917 123 4567',
              ),
              gap,
              TextFormField(
                controller: _dob,
                style: style,
                readOnly: true,
                onTap: _pickDob,
                decoration: auraFieldDecoration(
                  'Date of birth',
                  suffixIcon: IconButton(
                    tooltip: 'Pick date of birth',
                    icon: const Icon(Icons.calendar_today_outlined, size: 20, color: AuraColors.ink),
                    onPressed: _pickDob,
                  ),
                ),
                validator: _required('Choose your date of birth'),
              ),
              gap,
              TextFormField(
                controller: _address,
                style: style,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: auraFieldDecoration('Home address'),
                validator: _required('Enter your home address'),
              ),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _idType,
                isExpanded: true,
                style: style.copyWith(color: AuraColors.ink),
                decoration: auraFieldDecoration('Government ID'),
                items: [
                  for (final e in _idTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _idType = v),
                validator: (v) => v == null ? 'Choose an ID type' : null,
              ),
              gap,
              TextFormField(
                controller: _idNumber,
                style: style,
                textInputAction: TextInputAction.next,
                decoration: auraFieldDecoration('ID number'),
                validator: _required('Enter your ID number'),
              ),
              gap,
              TextFormField(
                controller: _password,
                style: style,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submitting ? null : _submit(),
                decoration: auraFieldDecoration(
                  'Password',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AuraColors.ink,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v ?? '').length < 8 ? 'Use at least 8 characters' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const ValueKey('registerError'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AuraColors.debitRedBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 18, color: AuraColors.debitRed),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(fontSize: 13.5, height: 1.4, color: AuraColors.ink)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AuraColors.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(fontWeight: FontWeight.w500, color: AuraColors.textSecondary),
                      children: [
                        TextSpan(text: 'Sign in', style: TextStyle(fontWeight: FontWeight.w700, color: AuraColors.ink)),
                      ],
                    ),
                    style: TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown once the email code is verified. That verification is the account's
/// first sign-in (tokens are already issued), so Continue goes into the app.
class RegistrationCompleteScreen extends StatelessWidget {
  const RegistrationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraColors.ink,
      body: AuroraBackground(
        intensity: 0.9,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                key: const ValueKey('registerDoneSheet'),
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
                decoration: BoxDecoration(color: AuraColors.surface, borderRadius: BorderRadius.circular(28)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedCheck(size: 88),
                    const SizedBox(height: 24),
                    const Text(
                      'Your email is verified',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, height: 1.15, fontWeight: FontWeight.w600, letterSpacing: -0.6),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Your Aura account is open and you're signed in on this device.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.5, height: 1.45, color: AuraColors.textSecondary),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (_) => false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuraColors.ink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
