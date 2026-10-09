import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurabank_app/main.dart';
import 'package:aurabank_app/screens/analytics/statement_screen.dart';
import 'package:aurabank_app/screens/analytics/statement_preview_screen.dart';
import 'package:aurabank_app/screens/home/home_screen.dart';
import 'package:aurabank_app/screens/cards/cards_screen.dart';
import 'package:aurabank_app/screens/transfer/send_money_screen.dart';
import 'package:aurabank_app/screens/auth/otp_verification_screen.dart';
import 'package:aurabank_app/screens/profile/devices_sessions_screen.dart';
import 'package:aurabank_app/screens/auth/security_gate_screen.dart';
import 'package:aurabank_app/screens/profile/profile_screen.dart';
import 'package:aurabank_app/screens/analytics/analytics_screen.dart';
import 'package:aurabank_app/screens/app_shell.dart';
import 'package:aurabank_app/screens/auth/login_screen.dart';
import 'package:aurabank_app/screens/auth/login_page_face_id.dart';
import 'package:aurabank_app/screens/auth/login_page_fingerprint.dart';
import 'package:aurabank_app/services/auth_api_service.dart';
import 'package:aurabank_app/services/bank_service.dart';
import 'package:aurabank_app/services/biometric_service.dart';
import 'package:aurabank_app/services/notification_stream_service.dart';
import 'package:aurabank_app/widgets/require_device_approval.dart';

void main() {
  testWidgets('Aura Bank splash screen test', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraBankApp());
    expect(find.text('Aura Bank'), findsOneWidget);
    expect(find.text('Interbank Network Ledger'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Login screen renders credentials and toggles password visibility', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('elijahriley.montefalco@gmail.com'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // Verify password field is obscured initially
    final passwordFieldFinder = find.byType(TextField).last;
    TextField passwordField = tester.widget(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);

    // Tap eye toggle to reveal password
    await tester.tap(find.byKey(const ValueKey('passwordVisibilityToggle')));
    await tester.pumpAndSettle();

    passwordField = tester.widget(passwordFieldFinder);
    expect(passwordField.obscureText, isFalse);

    // Tap eye toggle again to hide password
    await tester.tap(find.byKey(const ValueKey('passwordVisibilityToggle')));
    await tester.pumpAndSettle();

    passwordField = tester.widget(passwordFieldFinder);
    expect(passwordField.obscureText, isTrue);
  });

  testWidgets('Statement of Account screen renders components and filters properly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StatementScreen(),
      ),
    );

    // Title and Header
    expect(find.text('Statement of Account'), findsOneWidget);
    expect(find.text('October 2026'), findsWidgets);
    expect(find.text('E-Statement'), findsOneWidget);

    // Financial totals
    expect(find.text('Total Received'), findsOneWidget);
    expect(find.text('Total Sent'), findsOneWidget);
    expect(find.text('PHP 52,000.00'), findsOneWidget);
    expect(find.text('PHP 22,000.00'), findsOneWidget);

    // Filter tabs
    expect(find.text('All'), findsOneWidget);
    expect(find.text('In'), findsOneWidget);
    expect(find.text('Out'), findsOneWidget);

    // Initial 4 items visible
    expect(find.text('Drake Montero'), findsOneWidget);
    expect(find.text('Klare Riego'), findsOneWidget);
    expect(find.text('Jessi Mey'), findsOneWidget);
    expect(find.text('Angel Lou'), findsOneWidget);

    // Tap "In" filter tab
    await tester.tap(find.text('In'));
    await tester.pumpAndSettle();

    expect(find.text('Drake Montero'), findsOneWidget);
    expect(find.text('Klare Riego'), findsOneWidget);
    expect(find.text('Jessi Mey'), findsNothing);
    expect(find.text('Angel Lou'), findsNothing);

    // Tap "Out" filter tab
    await tester.tap(find.text('Out'));
    await tester.pumpAndSettle();

    expect(find.text('Drake Montero'), findsNothing);
    expect(find.text('Klare Riego'), findsNothing);
    expect(find.text('Jessi Mey'), findsOneWidget);
    expect(find.text('Angel Lou'), findsOneWidget);

    // Export as PDF button
    expect(find.text('Export as PDF'), findsOneWidget);
  });

  testWidgets('Statement Preview screen renders digital certificate and QR code',
      (WidgetTester tester) async {
    final statement = BankService().statements['2026-10']!;

    await tester.pumpWidget(
      MaterialApp(
        home: StatementPreviewScreen(statement: statement),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Aura Statement October 2026'), findsOneWidget);
    expect(find.text('Aura Bank (PH)'), findsOneWidget);
    expect(find.text('BSP Regulated • Member: PDIC'), findsOneWidget);
    expect(find.text('RECONCILED'), findsOneWidget);
    expect(find.text('TRANSACTIONAL JOURNAL'), findsOneWidget);
    expect(find.text('DIGITALLY VERIFIED'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
  });

  testWidgets('Home screen renders balance, quick actions, and recent transactions',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('Available Balance'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('Angel Lou F. Yabut'), findsOneWidget);
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('- 150,000'), findsOneWidget);
    expect(find.text('Mae G. Mercado'), findsOneWidget);
    expect(find.text('Interbank Inward'), findsOneWidget);
    expect(find.text('+ 25,000'), findsNWidgets(2));
    expect(find.text('Jessie Mae Dela Paz'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  testWidgets('AppShell renders luxury floating navbar with elevated scan action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Cards'), findsWidgets);
    expect(find.text('Scan'), findsWidgets);
    expect(find.text('Analytics'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });

  testWidgets('Cards screen displays cards and toggles card lock state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CardsScreen(),
      ),
    );

    expect(find.text('Card Control'), findsOneWidget);
    expect(find.text('Lock Card'), findsOneWidget);
    expect(find.text('Transaction History'), findsOneWidget);
    expect(find.text('Angel Lou F. Yabut'), findsOneWidget);
    expect(find.text('Same Bank Transfer • Settled'), findsOneWidget);
    expect(find.text('Mae G. Mercado'), findsOneWidget);
    expect(find.text('Other Bank Transfer • Settled'), findsOneWidget);
    expect(find.text('Jessie Mae Dela Paz'), findsOneWidget);
    expect(find.text('Same Bank Transfer • Failed'), findsOneWidget);

    // Tap Lock Card
    await tester.tap(find.text('Lock Card'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Card'), findsOneWidget);
  });

  testWidgets('Send Money screen renders form inputs and navigates to review',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SendMoneyScreen(),
      ),
    );

    expect(find.text('Aura to Aura'), findsOneWidget);
    expect(find.text('Other Bank'), findsOneWidget);
    expect(find.text('From:'), findsOneWidget);
    expect(find.textContaining('Savings Account'), findsOneWidget);
    expect(find.text('Purpose'), findsOneWidget);
    expect(find.text('Select transfer purpose'), findsOneWidget);
    expect(find.text('Remarks (Optional)'), findsOneWidget);
    expect(find.text('Send Money'), findsOneWidget);
    expect(find.text('Bills & Utilities'), findsNothing);
  });

  testWidgets('OTP Verification screen renders PIN boxes, countdown, and incomplete alert',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OtpVerificationScreen(email: 'test@aurabank.ph'),
      ),
    );

    expect(find.text('Check your email'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('test@aurabank.ph'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Never share your verification code'), findsOneWidget);

    // Tap Verify with empty inputs -> triggers "This page says" incomplete alert dialog
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    expect(find.text('This page says'), findsOneWidget);
    expect(find.text('Please enter the complete 6-digit code.'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    // Dismiss alert
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('This page says'), findsNothing);
  });

  testWidgets('Devices & Sessions screen renders hardware list and web sessions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: DevicesSessionsScreen(),
      ),
    );

    expect(find.text('Devices & Sessions'), findsOneWidget);
    expect(find.textContaining('TRUSTED DEVICES'), findsOneWidget);
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);
    expect(find.text('ACTIVE WEB SESSIONS'), findsOneWidget);
    expect(find.text('Chrome • macOS'), findsOneWidget);
    expect(find.text('Log Out All Sessions'), findsOneWidget);
    expect(find.text('Log Out of All Devices'), findsOneWidget);

    // Verify both primary and secondary devices have a Revoke button
    expect(find.text('Revoke'), findsNWidgets(2));

    // Tap first Revoke button for primary device
    await tester.tap(find.text('Revoke').first);
    await tester.pumpAndSettle();

    expect(find.text('Revoke Primary Device?'), findsOneWidget);
    expect(find.text('Revoke Primary'), findsOneWidget);

    // Confirm revocation of primary device
    await tester.tap(find.text('Revoke Primary'));
    await tester.pumpAndSettle();

    // Primary device is removed, iPad Air promoted to PRIMARY
    expect(find.text('iPhone 15 Pro'), findsNothing);
    expect(find.text('iPad Air'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);

    // Test Log Out All Sessions functionality
    await tester.ensureVisible(find.text('Log Out All Sessions'));
    await tester.tap(find.text('Log Out All Sessions'));
    await tester.pumpAndSettle();

    expect(find.text('Log out of all sessions?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log Out All Sessions'));
    await tester.pumpAndSettle();

    // Verify web sessions are terminated and empty state is rendered
    expect(find.text('Chrome • macOS'), findsNothing);
    expect(find.text('No active web sessions.'), findsOneWidget);
  });

  testWidgets('Security Gate screen cycles scan, screen share warning, and fraud block',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SecurityGateScreen(),
      ),
    );

    expect(find.text('Checking your transfer'), findsOneWidget);
    expect(find.text('Security Scan'), findsOneWidget);
    expect(find.text('Screen Share'), findsOneWidget);
    expect(find.text('Blocked Anomaly'), findsOneWidget);

    // Tap Screen Share tab
    await tester.tap(find.text('Screen Share'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Screen sharing or remote app detected'), findsOneWidget);
    expect(find.text('Cancel transfer'), findsOneWidget);
    expect(find.text('Pause for 10 minutes'), findsOneWidget);

    // Tap Blocked Anomaly tab
    await tester.tap(find.text('Blocked Anomaly'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Transfer blocked'), findsOneWidget);
    expect(find.text('Back to start'), findsOneWidget);
    expect(find.text('Contact Aura Support'), findsOneWidget);
  });

  testWidgets('Settings and Profile screens render profile, edit modal, and session logout',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileScreen(),
      ),
    );

    expect(find.text('Aura Bank'), findsOneWidget);
    expect(find.text('Elijah Riley Montefalco'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Date of Birth'), findsOneWidget);
    expect(find.text('July 10, 1999'), findsOneWidget);
    expect(find.text('Biometric Login (Face ID)'), findsOneWidget);
    expect(find.text('Devices & Active Sessions'), findsOneWidget);
    expect(find.text('Instant Push Alerts'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.text('Log Out of All Devices'), findsNothing);

    // Tap Edit button to open Edit Profile bottom sheet
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Tap Save Changes to close modal
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Profile'), findsNothing);
  });

  testWidgets('Interactive Analytics Transfer Flow renders pointed flow, week/month clicks, and KPI updates',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AnalyticsScreen(),
      ),
    );

    // Initial render in Monthly mode
    expect(find.text('Transfer Flow'), findsOneWidget);
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('Total Sent'), findsOneWidget);
    expect(find.text('Total Received'), findsOneWidget);
    expect(find.text('Monthly History'), findsOneWidget);

    // Switch to Yearly mode
    await tester.tap(find.text('Yearly'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly Summaries'), findsOneWidget);

    // Switch back to Monthly mode
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();

    expect(find.text('Monthly History'), findsOneWidget);
  });

  testWidgets('RequireDeviceApproval blocks transactions when device is unapproved',
      (WidgetTester tester) async {
    // Simulate secondary unapproved device state
    AuthApiService().currentIsApproved = false;
    AuthApiService().currentIsPrimaryDevice = false;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RequireDeviceApproval(
            actionLabel: 'Money transfers',
            child: ElevatedButton(
              onPressed: null,
              child: Text('Transfer Button'),
            ),
          ),
        ),
      ),
    );

    // Should display notice banner indicating action is locked
    expect(find.textContaining('disabled until authorized by your primary device'), findsOneWidget);
    expect(find.text('Transfer Button'), findsOneWidget);

    // Reset approval state back to true
    AuthApiService().currentIsApproved = true;
    AuthApiService().currentIsPrimaryDevice = true;
  });

  testWidgets('Unauthenticated login screen ignores DEVICE_REVOKED events',
      (WidgetTester tester) async {
    // Ensure client is unauthenticated
    AuthApiService().currentAccessToken = null;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const LoginScreen(),
      ),
    );

    expect(find.text('Welcome Back!'), findsOneWidget);

    // Inject a DEVICE_REVOKED event
    NotificationStreamService().injectDeviceApprovalEvent({
      'type': 'DEVICE_REVOKED',
      'user_id': 'USR-100001',
      'device_id': AuthApiService().currentDeviceId,
    });
    await tester.pump(const Duration(milliseconds: 100));

    // Verify unauthenticated client does NOT display revoked banner
    expect(find.text('Access revoked. You have been logged out of this session.'), findsNothing);
    expect(find.text('Welcome Back!'), findsOneWidget);
  });

  testWidgets('Authenticated session suppresses duplicate DEVICE_REVOKED events',
      (WidgetTester tester) async {
    AuthApiService().currentAccessToken = 'mock-valid-token-12345';
    NotificationStreamService().connect('USR-100001');

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(
          body: Text('Active Session Screen'),
        ),
      ),
    );

    expect(find.text('Active Session Screen'), findsOneWidget);

    // Fire first DEVICE_REVOKED event
    NotificationStreamService().injectDeviceApprovalEvent({
      'type': 'DEVICE_REVOKED',
      'user_id': 'USR-100001',
      'device_id': AuthApiService().currentDeviceId,
    });
    await tester.pump(const Duration(milliseconds: 100));

    // Fire duplicate DEVICE_REVOKED event immediately
    NotificationStreamService().injectDeviceApprovalEvent({
      'type': 'DEVICE_REVOKED',
      'user_id': 'USR-100001',
      'device_id': AuthApiService().currentDeviceId,
    });
    await tester.pump(const Duration(milliseconds: 100));

    // Exactly one snackbar is rendered (not multiple stacked)
    expect(find.text('Access revoked. You have been logged out of this session.'), findsOneWidget);

    NotificationStreamService().disconnect();
  });

  testWidgets('LoginPageFaceId renders Face ID biometric trigger and auth layout',
      (WidgetTester tester) async {
    bool loginSuccessCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPageFaceId(
          onLoginSuccess: () {
            loginSuccessCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.byType(FaceIdIcon), findsOneWidget);
    expect(find.text('Forgot Passcode?'), findsOneWidget);
    expect(find.text('Switch Account'), findsOneWidget);
    expect(loginSuccessCalled, isFalse);
  });

  testWidgets('LoginPageFingerprint renders fingerprint trigger and auth layout',
      (WidgetTester tester) async {
    bool fingerprintTapCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPageFingerprint(
          onFingerprintTap: () {
            fingerprintTapCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
    expect(find.text('Forgot Passcode?'), findsOneWidget);
    expect(find.text('Switch Account'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.fingerprint_rounded));
    await tester.pumpAndSettle();
    expect(fingerprintTapCalled, isTrue);
  });

  test('BiometricService gracefully returns false in headless test runner', () async {
    final service = BiometricService();
    final canAuth = await service.canAuthenticate();
    expect(canAuth, isFalse);
    final biometrics = await service.getAvailableBiometrics();
    expect(biometrics, isEmpty);
  });
}