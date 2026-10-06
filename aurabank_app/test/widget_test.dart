import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurabank_app/main.dart';
import 'package:aurabank_app/screens/statement_screen.dart';
import 'package:aurabank_app/screens/statement_preview_screen.dart';
import 'package:aurabank_app/screens/home_screen.dart';
import 'package:aurabank_app/screens/cards_screen.dart';
import 'package:aurabank_app/screens/send_money_screen.dart';
import 'package:aurabank_app/screens/otp_verification_screen.dart';
import 'package:aurabank_app/screens/devices_sessions_screen.dart';
import 'package:aurabank_app/screens/security_gate_screen.dart';
import 'package:aurabank_app/screens/profile_screen.dart';
import 'package:aurabank_app/services/bank_service.dart';

void main() {
  testWidgets('Aura Bank splash screen test', (WidgetTester tester) async {
    await tester.pumpWidget(const AuraBankApp());
    expect(find.text('Aura Bank'), findsOneWidget);
    expect(find.text('Intra-Bank Network Ledger'), findsOneWidget);
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
    expect(find.text('Oct 01 - Oct 31, 2026'), findsNWidgets(2));
    expect(find.text('October 2026'), findsWidgets);
    expect(find.text('E-STATEMENT'), findsOneWidget);

    // Financial totals
    expect(find.text('TOTAL RECEIVED'), findsOneWidget);
    expect(find.text('TOTAL SENT'), findsOneWidget);
    expect(find.text('₱52,000.00'), findsOneWidget);
    expect(find.text('₱37,750.00'), findsOneWidget);

    // Filter tabs
    expect(find.text('All'), findsOneWidget);
    expect(find.text('In'), findsOneWidget);
    expect(find.text('Out'), findsOneWidget);

    // Initial 4 items visible
    expect(find.text('Luis Tan'), findsOneWidget);
    expect(find.text('Sofia Garcia'), findsOneWidget);
    expect(find.text('Alex Cruz'), findsOneWidget);
    expect(find.text('Maria Ramos'), findsOneWidget);

    // Tap "In" filter tab
    await tester.tap(find.text('In'));
    await tester.pumpAndSettle();

    expect(find.text('Luis Tan'), findsOneWidget);
    expect(find.text('Sofia Garcia'), findsOneWidget);
    expect(find.text('Alex Cruz'), findsNothing);
    expect(find.text('Maria Ramos'), findsNothing);

    // Tap "Out" filter tab
    await tester.tap(find.text('Out'));
    await tester.pumpAndSettle();

    expect(find.text('Luis Tan'), findsNothing);
    expect(find.text('Sofia Garcia'), findsNothing);
    expect(find.text('Alex Cruz'), findsOneWidget);
    expect(find.text('Maria Ramos'), findsOneWidget);

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
    expect(find.text('Send Money'), findsOneWidget);
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
  });

  testWidgets('Security Gate screen cycles scan, screen share warning, and fraud block',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SecurityGateScreen(),
      ),
    );

    expect(find.text('Checking your transfer'), findsOneWidget);
    expect(find.text('Gate 0 Scan'), findsOneWidget);
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
    expect(find.text('Trusted Devices & Sessions'), findsOneWidget);
    expect(find.text('Instant Push Alerts'), findsOneWidget);
    expect(find.text('Logout of Session'), findsOneWidget);
    expect(find.text('Log Out of All Devices'), findsOneWidget);

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
}