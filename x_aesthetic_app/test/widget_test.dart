import 'package:flutter_test/flutter_test.dart';
import 'package:x_aesthetic_app/app/app.dart';

void main() {
  testWidgets('XAestheticApp renders initial camera tab', (tester) async {
    await tester.pumpWidget(const XAestheticApp());
    await tester.pumpAndSettle();

    expect(find.text('Camera Guidance'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
  });
}
