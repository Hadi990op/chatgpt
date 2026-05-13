import 'package:flutter_test/flutter_test.dart';
import 'package:rickshaw_pulse/main.dart';

void main() {
  testWidgets('app renders title', (tester) async {
    await tester.pumpWidget(const RickshawPulseApp());
    expect(find.text('Rickshaw Pulse'), findsOneWidget);
  });
}
