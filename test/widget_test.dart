import 'package:flutter_test/flutter_test.dart';
import 'package:piletile/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PileTileApp());
    expect(find.text('PILETILE'), findsOneWidget);
  });
}
