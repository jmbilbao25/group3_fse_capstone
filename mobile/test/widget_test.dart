import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bank_mobile_security_test/main.dart';
import 'package:bank_mobile_security_test/services/auth_api_service.dart';
import 'package:bank_mobile_security_test/services/notification_stream_service.dart';
import 'package:bank_mobile_security_test/services/otp_service.dart';

void main() {
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient((request) async {
      final path = request.url.path;

      // 1. Backend Login Endpoint
      if (path.endsWith('/api/v1/auth/login')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final email = body['email'] as String? ?? '';

        if (email.contains('juan.dc')) {
          // First-time user requiring MFA OTP
          return http.Response(
            jsonEncode({
              'status': 'MFA_REQUIRED',
              'user_id': 'USR-100001',
              'masked_email': 'j***c@email.com',
              'role': 'Customer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (email.contains('diana.admin')) {
          // Returning user authenticated directly
          return http.Response(
            jsonEncode({
              'status': 'AUTHENTICATED',
              'access_token': 'mock-jwt-diana-admin',
              'role': 'Teller',
              'user_id': 'USR-880099',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else {
          return http.Response(
            jsonEncode({'detail': 'Invalid email or password credentials.'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
      }

      // 2. Backend OTP Verification Endpoint
      if (path.endsWith('/api/v1/auth/verify-login-otp')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final otp = body['otp'] as String? ?? '';

        if (otp == '123456') {
          return http.Response(
            jsonEncode({
              'status': 'AUTHENTICATED',
              'access_token': 'mock-jwt-verified',
              'role': 'Customer',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else {
          return http.Response(
            jsonEncode({'detail': 'Invalid or expired verification code.'}),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
      }

      // 3. MailHog Messages API
      if (path.endsWith('/api/v2/messages')) {
        return http.Response(
          jsonEncode({
            'total': 1,
            'count': 1,
            'items': [
              {
                'ID': 'msg-001',
                'From': {'Mailbox': 'noreply', 'Domain': 'corebank.ph'},
                'To': [
                  {'Mailbox': 'juan.dc', 'Domain': 'email.com'}
                ],
                'Content': {
                  'Headers': {
                    'Subject': ['AuraBank Security: Your First-Time Login OTP']
                  },
                  'Body': 'Your one-time password code is 123456. Valid for 5 minutes.'
                },
                'Created': '2026-10-06T06:00:00.000Z'
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response('Not Found', 404);
    });

    AuthApiService().httpClient = mockClient;
    OtpService().httpClient = mockClient;
    NotificationStreamService().httpClient = mockClient;
    NotificationStreamService().enableAutoReconnect = false;
    NotificationStreamService().enablePollingFallback = false;
  });

  tearDown(() {
    AuthApiService().httpClient = null;
    OtpService().httpClient = null;
    NotificationStreamService().disconnect();
  });

  testWidgets('Strict backend: First-time login triggers MFA OTP and auto-fills MailHog code',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    // 1. Submit login as Juan Dela Cruz
    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');

    await tester.enterText(emailField, 'juan.dc@email.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle();

    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    // 2. Expect First-Time Login Verification screen
    expect(find.text('First-Time Login Verification'), findsOneWidget);

    // 3. Open MailHog email modal
    final viewEmailButton = find.textContaining('View Received OTP Email');
    expect(viewEmailButton, findsOneWidget);
    await tester.tap(viewEmailButton);
    await tester.pumpAndSettle();

    // 4. Verify MailHog email contents
    expect(find.text('MailHog Live Inbox (:8025)'), findsOneWidget);
    expect(find.text('From: noreply@corebank.ph'), findsOneWidget);

    // 5. Auto-Fill & Verify via backend endpoint
    final autoFillBtn = find.byKey(const Key('btn_autofill_verify'));
    await tester.tap(autoFillBtn);
    await tester.pumpAndSettle();

    // 6. Verify Dashboard is displayed
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Primary Savings Account'), findsOneWidget);
  });

  testWidgets('Strict backend: Returning user authenticates directly via backend',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    final dianaChip = find.text('Diana Vance (Admin / Teller)');
    await tester.tap(dianaChip);
    await tester.pumpAndSettle();

    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    // Direct dashboard navigation without OTP
    expect(find.text('Diana Vance'), findsOneWidget);
  });

  testWidgets('Strict backend: Incorrect OTP code returns 400 error from backend',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');

    await tester.enterText(emailField, 'juan.dc@email.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle();

    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('First-Time Login Verification'), findsOneWidget);

    // Enter wrong 6-digit OTP '000000'
    for (int i = 0; i < 6; i++) {
      await tester.enterText(find.byKey(Key('otp_digit_$i')), '0');
    }
    await tester.pumpAndSettle();

    // Expect backend error detail message
    expect(find.text('Invalid or expired verification code.'), findsOneWidget);
  });

  test('OtpService extracts true code ignoring CSS hex colors like #475569', () async {
    final mockClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'total': 1,
          'count': 1,
          'items': [
            {
              'ID': 'msg-002',
              'From': {'Mailbox': 'noreply', 'Domain': 'corebank.ph'},
              'To': [
                {'Mailbox': 'juan.dc', 'Domain': 'email.com'}
              ],
              'Content': {
                'Headers': {
                  'Subject': ['Aura Bank: 908151 is your login verification code']
                },
                'Body': '<style>p { color: #475569; }</style><div class="otp-code">908151</div>'
              },
              'Created': '2026-10-06T06:00:00.000Z'
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = OtpService();
    service.httpClient = mockClient;
    final email = await service.fetchLatestEmail(recipientEmail: 'juan.dc@email.com');
    expect(email, isNotNull);
    expect(email!.otpCode, equals('908151'));
    service.httpClient = null;
  });

  testWidgets('Multi-device: User can select secondary device preset on login screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    final settingsBtn = find.byTooltip('Device & Network Settings');
    expect(settingsBtn, findsOneWidget);
    await tester.tap(settingsBtn);
    await tester.pumpAndSettle();

    final secondaryChip = find.widgetWithText(ChoiceChip, 'Device 2 (Secondary - iPad)');
    expect(secondaryChip, findsOneWidget);

    await tester.tap(secondaryChip);
    await tester.pumpAndSettle();

    expect(AuthApiService().currentDeviceId, equals('dev-ipad-secondary'));
    expect(AuthApiService().currentDeviceName, equals('iPad Air'));
  });

  testWidgets('Multi-device: Primary device receives real-time security push alert modal',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AuraBankApp());
    await tester.pumpAndSettle();

    // Authenticate returning user directly
    final emailField = find.widgetWithText(TextFormField, 'Email Address');
    final passwordField = find.widgetWithText(TextFormField, 'Password');

    await tester.enterText(emailField, 'diana.admin@bank.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle();

    final signInButton = find.widgetWithText(FilledButton, 'Sign In');
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    // Check that we are on the dashboard with device badge
    expect(find.text('Primary Device Protected'), findsOneWidget);

    // Simulate real-time SSE push alert coming in from backend
    NotificationStreamService().injectAlert(
      SecurityAlertEvent(
        title: 'Security Push Alert',
        message: 'A new device (iPad Air) just logged in from 192.168.1.88',
        deviceName: 'iPad Air (Secondary)',
        clientIp: '192.168.1.88',
        timestamp: DateTime.now().toIso8601String(),
        targetDeviceId: 'dev-iphone-primary',
        notificationId: 'NOTIF-TEST-1001',
      ),
    );
    await tester.pumpAndSettle();

    // Verify modal appeared with security details
    expect(find.text('Security Push Alert'), findsOneWidget);
    expect(find.text('iPad Air (Secondary)'), findsOneWidget);
    expect(find.text('192.168.1.88'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve Access'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Revoke Access'), findsOneWidget);

    // Tap Approve Access
    await tester.tap(find.widgetWithText(FilledButton, 'Approve Access'));
    await tester.pumpAndSettle();

    // Modal is dismissed
    expect(find.text('Security Push Alert'), findsNothing);
  });
}

