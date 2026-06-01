import 'package:flutter_test/flutter_test.dart';
import 'package:x_aesthetic_app/app/app.dart';

void main() {
  testWidgets('XAestheticApp renders initial home screen', (tester) async {
    await tester.pumpWidget(const XAestheticApp());
    await tester.pumpAndSettle();

    expect(find.text('Trang chủ'), findsAtLeast(1));
    expect(find.text('Thư viện'), findsOneWidget);
    expect(find.text('Tiến bộ'), findsOneWidget);
  });
}

