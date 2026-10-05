import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bank_mobile_security_test/main.dart';

void main() {
  testWidgets('AuraBank login flow test with email and password',
      (WidgetTester tester) async {
    // Set standard mobile screen dimensions (e.g. 540x1170 logical)
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Pump the app
    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    // 2. Verify login screen elements are present
    expect(find.text('AuraBank'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);

    // 3. Test empty submission validation
    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email address.'), findsOneWidget);

    // 4. Enter valid email and password
    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');

    await tester.ensureVisible(emailField);
    await tester.enterText(emailField, 'juan.dc@email.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle();

    // 5. Tap Sign In
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);

    // Pump past the 700ms async login latency simulation
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // 6. Verify Dashboard is displayed
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Primary Savings Account'), findsOneWidget);
    expect(find.text('1000-2000-3001'), findsOneWidget);

    // 7. Test Logout / Back to Login
    final backButton = find.text('Back to Login Screen');
    await tester.ensureVisible(backButton);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // 8. Verify back on Login Screen
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Quick fill persona shortcut populates email and password',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    // Tap the Diana Vance demo persona chip
    final dianaChip = find.text('Diana Vance (Admin / Teller)');
    expect(dianaChip, findsOneWidget);
    await tester.tap(dianaChip);
    await tester.pumpAndSettle();

    // Verify fields populated
    expect(find.text('diana.admin@bank.com'), findsOneWidget);

    // Tap Sign In
    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);

    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Verify Diana's dashboard
    expect(find.text('Diana Vance'), findsOneWidget);
    expect(find.text('1000-8800-9902'), findsOneWidget);
  });
}
