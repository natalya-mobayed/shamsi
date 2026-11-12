import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi/main.dart';

void main() {
  testWidgets('Shamsi app opens correctly', (tester) async {
    await tester.pumpWidget(const ShamsiApp());

    expect(find.textContaining('Shamsi'), findsWidgets);
    expect(find.text('Calculate'), findsOneWidget);
  });
}
