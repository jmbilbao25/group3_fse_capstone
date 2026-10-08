import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bank_mobile_security_test/models/user_persona.dart';
import 'package:bank_mobile_security_test/screens/dashboard_screen.dart';
import 'package:bank_mobile_security_test/services/security_service.dart';
import 'package:bank_mobile_security_test/widgets/screen_sharing_warning_sheet.dart';

void main() {
  setUp(() {
    SecurityService.simulateScreenSharing = false;
    SecurityService.simulateCompromised = false;
  });

  tearDown(() {
    SecurityService.simulateScreenSharing = false;
    SecurityService.simulateCompromised = false;
  });

  group('ScreenSharingWarningSheet Widget Tests', () {
    testWidgets('Renders all visual elements from specification with high fidelity',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScreenSharingWarningSheet(),
          ),
        ),
      );

      // Verify Title
      expect(find.text('Screen Sharing is active'), findsOneWidget);

      // Verify Body Text and Aura Bank warning clause
      expect(find.textContaining('An app is currently sharing or viewing your screen.'), findsOneWidget);
      expect(find.textContaining('Aura Bank will never ask you to share your screen'), findsOneWidget);
      expect(find.textContaining('or transfer money to protect your account'), findsOneWidget);

      // Verify Action Buttons
      expect(find.text('Cancel Transaction'), findsOneWidget);
      expect(find.text('Pause for 10 minutes'), findsOneWidget);

      // Verify Footer Link Elements
      expect(find.text('I am not sharing my screen'), findsOneWidget);
      expect(find.text('•'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Tapping "Cancel Transaction" triggers onCancel callback',
        (WidgetTester tester) async {
      bool cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenSharingWarningSheet(
              onCancel: () {
                cancelCalled = true;
              },
            ),
          ),
        ),
      );

      final cancelBtn = find.widgetWithText(FilledButton, 'Cancel Transaction');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pump();

      expect(cancelCalled, isTrue);
    });

    testWidgets('Tapping "Pause for 10 minutes" triggers onPause callback',
        (WidgetTester tester) async {
      bool pauseCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenSharingWarningSheet(
              onPause: () {
                pauseCalled = true;
              },
            ),
          ),
        ),
      );

      final pauseBtn = find.widgetWithText(OutlinedButton, 'Pause for 10 minutes');
      expect(pauseBtn, findsOneWidget);
      await tester.tap(pauseBtn);
      await tester.pump();

      expect(pauseCalled, isTrue);
    });

    testWidgets('Tapping "Continue" link triggers onContinue callback',
        (WidgetTester tester) async {
      bool continueCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScreenSharingWarningSheet(
              onContinue: () {
                continueCalled = true;
              },
            ),
          ),
        ),
      );

      final continueLink = find.byKey(const Key('screen_sharing_continue_link'));
      expect(continueLink, findsOneWidget);
      await tester.tap(continueLink);
      await tester.pump();

      expect(continueCalled, isTrue);
    });

    testWidgets('ScreenSharingWarningSheet.show presents modal bottom sheet and returns user action',
        (WidgetTester tester) async {
      ScreenSharingUserAction? chosenAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  chosenAction = await ScreenSharingWarningSheet.show(ctx);
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Screen Sharing is active'), findsOneWidget);

      // Tap Cancel Transaction
      await tester.tap(find.text('Cancel Transaction'));
      await tester.pumpAndSettle();

      expect(chosenAction, equals(ScreenSharingUserAction.cancelTransaction));
    });
  });

  group('SecurityService Screen Sharing Detection Tests', () {
    test('isScreenSharingActive returns false by default and true when simulated', () async {
      SecurityService.simulateScreenSharing = false;
      expect(await SecurityService.isScreenSharingActive(), isFalse);

      SecurityService.simulateScreenSharing = true;
      expect(await SecurityService.isScreenSharingActive(), isTrue);
    });
  });

  group('DashboardScreen Screen Sharing Integration Tests', () {
    final testUser = UserPersona(
      name: 'Elena Rostova',
      role: 'Premier Banking Client',
      email: 'elena.rostova@aurabank.ph',
      password: 'password123',
      accountId: 'ACC-100001',
      balance: 10000.00,
    );

    testWidgets('Transfer flow detects active screen sharing and pops up warning sheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SecurityService.simulateScreenSharing = true;

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            user: testUser,
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Transfer action
      final transferButton = find.text('Transfer');
      expect(transferButton, findsOneWidget);
      await tester.ensureVisible(transferButton);
      await tester.tap(transferButton);
      await tester.pumpAndSettle();

      // Warning bottom sheet should be presented immediately
      expect(find.text('Screen Sharing is active'), findsOneWidget);
      expect(find.textContaining('Aura Bank will never ask you to share your screen'), findsOneWidget);

      // Tap Cancel Transaction
      await tester.tap(find.text('Cancel Transaction'));
      await tester.pumpAndSettle();

      // Warning bottom sheet is dismissed and safety snackbar appears
      expect(find.text('Screen Sharing is active'), findsNothing);
      expect(find.textContaining('Transfer Cancelled'), findsOneWidget);
    });

    testWidgets('Simulate Screen Sharing button from Devices sheet displays modal',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            user: testUser,
            onLogout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Devices to open Devices bottom sheet
      await tester.tap(find.byTooltip('Devices'));
      await tester.pumpAndSettle();

      // Find simulation button
      final simBtn = find.byKey(const Key('simulate_screen_sharing_btn'));
      expect(simBtn, findsOneWidget);
      await tester.ensureVisible(simBtn);
      await tester.tap(simBtn);
      await tester.pumpAndSettle();

      // Warning bottom sheet is visible
      expect(find.text('Screen Sharing is active'), findsOneWidget);
      expect(find.text('Pause for 10 minutes'), findsOneWidget);

      // Tap Pause for 10 minutes
      await tester.tap(find.text('Pause for 10 minutes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('paused for 10 minutes'), findsOneWidget);
    });
  });
}
