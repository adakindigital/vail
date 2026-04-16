import 'package:flutter_test/flutter_test.dart';
import 'package:vail_app/app.dart';

void main() {
  testWidgets('VailApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VailApp());
  });
}
