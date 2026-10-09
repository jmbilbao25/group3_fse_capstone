import 'package:flutter_test/flutter_test.dart';
import 'package:aurabank_web/main.dart';

void main() {
  testWidgets('web app builds', (tester) async {
    await tester.pumpWidget(const AuraBankWeb());
    expect(find.byType(AuraBankWeb), findsOneWidget);
  });
}
