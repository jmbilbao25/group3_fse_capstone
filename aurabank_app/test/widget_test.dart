import 'package:flutter_test/flutter_test.dart';
import 'package:aurabank_app/main.dart';

void main() {
  testWidgets('Aura Bank splash screen test',
          (WidgetTester tester) async {

        await tester.pumpWidget(const AuraBankApp());

        expect(find.text('Aura Bank'), findsOneWidget);
      });
}