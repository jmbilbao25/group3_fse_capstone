import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurabank_app/screens/auth/login_screen.dart';
import 'package:aurabank_app/widgets/aurora_background.dart';

Future<void> _pumpLogin(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  // The sky loops forever, so settle the one-shot entrances by time.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

final _sheet = find.byKey(const ValueKey('loginSheet'));

void main() {
  for (final size in const [Size(390, 844), Size(375, 667), Size(460, 1000)]) {
    testWidgets('phone ${size.width.toInt()}x${size.height.toInt()}: sky fills the screen, sheet docks to the bottom',
        (tester) async {
      await _pumpLogin(tester, size);
      final sky = tester.getRect(find.byType(AuroraBackground));
      final sheet = tester.getRect(_sheet);
      final greeting = tester.getRect(find.textContaining('Welcome back'));

      expect(sky.topLeft, Offset.zero);
      expect(sky.width, size.width);
      expect(sky.bottom, greaterThan(sheet.top), reason: 'sky runs under the sheet corners');
      expect(sheet.bottom, size.height, reason: 'no empty band below the sheet');
      expect(sheet.width, size.width);
      expect(greeting.bottom, lessThan(sheet.top));
      // The test font (63 px here) runs taller than Onest (about 54 px on web).
      expect(tester.getSize(find.byType(TextField).first).height, inInclusiveRange(56, 64));
      expect(find.textContaining('Elijah'), findsOneWidget, reason: 'remembered account greets by first name');
    });
  }

  testWidgets('phone with keyboard open: sheet rides the keyboard and Sign in stays reachable', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await _pumpLogin(tester, const Size(375, 667));

    await tester.ensureVisible(find.text('Sign in'));
    await tester.pump();
    expect(tester.getRect(find.text('Sign in')).bottom, lessThanOrEqualTo(667 - 300));

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
    await tester.pump();
    expect(tester.getRect(_sheet).bottom, 667 - 300, reason: 'sheet sits on the keyboard, no gap');
  });

  testWidgets('desktop: sky fills the viewport, paper card floats centred with the greeting inside', (tester) async {
    await _pumpLogin(tester, const Size(1440, 900));
    final sky = tester.getRect(find.byType(AuroraBackground));
    final card = tester.getRect(_sheet);
    final email = tester.getRect(find.byType(TextField).first);
    final greeting = tester.getRect(find.textContaining('Welcome back'));

    expect(sky, const Rect.fromLTWH(0, 0, 1440, 900));
    expect(card.width, 440);
    expect(card.center.dx, closeTo(720, 1));
    expect(card.center.dy, closeTo(450, 1));
    expect(card.contains(greeting.center), isTrue);
    expect(greeting.left, closeTo(email.left, 1));
  });
}
