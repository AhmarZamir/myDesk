import 'package:flutter_test/flutter_test.dart';
import 'package:mydesk/main.dart';

void main() {
  testWidgets('myDesk boots without runtime credentials', (tester) async {
    await tester.pumpWidget(const MyDeskApp());
    expect(find.text('myDesk setup required'), findsOneWidget);
  });
}
