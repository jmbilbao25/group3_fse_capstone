import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bank_mobile_security_test/main.dart';
import 'package:bank_mobile_security_test/services/security_service.dart';

void main() {
  setUp(() {
    SecurityService.enableAutoExit = false;
    SecurityService.simulateCompromised = false;
  });

  tearDown(() {
    SecurityService.enableAutoExit = true;
    SecurityService.simulateCompromised = false;
  });

  testWidgets('SecurityWarningDialog renders detected threat and triggers exit callback after 2-second delay',
      (WidgetTester tester) async {
    bool exitTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityWarningDialog(
            reason: 'Root binary detected: /system/bin/su',
            autoClose: true,
            delaySeconds: 2,
            onExit: () {
              exitTriggered = true;
            },
          ),
        ),
      ),
    );

    // Initial render: dialog title and detected threat are visible
    expect(find.text('Security Warning'), findsOneWidget);
    expect(find.text('Root binary detected: /system/bin/su'), findsOneWidget);
    expect(find.text('DETECTED THREAT'), findsOneWidget);
    expect(find.textContaining('Automatically closing in 2 seconds'), findsOneWidget);
    expect(exitTriggered, isFalse);

    // Advance 1 second: countdown updates to 1 second
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Automatically closing in 1 second'), findsOneWidget);
    expect(exitTriggered, isFalse);

    // Advance another second: 2 seconds elapsed, exit callback triggered!
    await tester.pump(const Duration(seconds: 1));
    expect(exitTriggered, isTrue);
  });

  testWidgets('SecurityWarningDialog "Close App Now" button exits immediately without waiting',
      (WidgetTester tester) async {
    bool exitTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecurityWarningDialog(
            reason: 'Developer Options Enabled, USB Debugging (ADB) Active',
            autoClose: true,
            delaySeconds: 2,
            onExit: () {
              exitTriggered = true;
            },
          ),
        ),
      ),
    );

    expect(exitTriggered, isFalse);
    final closeBtn = find.widgetWithText(FilledButton, 'Close App Now');
    expect(closeBtn, findsOneWidget);

    await tester.tap(closeBtn);
    await tester.pump();

    expect(exitTriggered, isTrue);
  });

  testWidgets('SecurityLockoutScreen renders full-screen warning dialog and auto-terminates in 2 seconds',
      (WidgetTester tester) async {
    bool exitTriggered = false;

    await tester.pumpWidget(
      SecurityLockoutScreen(
        reason: 'Unlocked Bootloader (AVB Compromised)',
        autoClose: true,
        delaySeconds: 2,
        onExit: () {
          exitTriggered = true;
        },
      ),
    );

    expect(find.text('Security Warning'), findsOneWidget);
    expect(find.text('Unlocked Bootloader (AVB Compromised)'), findsOneWidget);
    expect(find.textContaining('Automatically closing in 2 seconds'), findsOneWidget);
    expect(exitTriggered, isFalse);

    await tester.pump(const Duration(seconds: 2));
    expect(exitTriggered, isTrue);
  });

  testWidgets('LoginScreen intercepts compromised posture before network call and pops auto-closing warning dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SecurityService.simulateCompromised = true;

    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');

    await tester.enterText(emailField, 'juan.dc@email.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pump();

    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pump(const Duration(milliseconds: 300));

    // Security warning dialog appears over login screen
    expect(find.text('Security Warning'), findsOneWidget);
    expect(find.text('DETECTED THREAT'), findsOneWidget);
    expect(find.textContaining('Automatically closing in'), findsOneWidget);
  });
}
