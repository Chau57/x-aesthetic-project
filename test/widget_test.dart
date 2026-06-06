import 'package:flutter_test/flutter_test.dart';
import 'package:x_aesthetic_app/app/app.dart';

void main() {
  testWidgets('XAestheticApp renders simplified camera UI', (tester) async {
    await tester.pumpWidget(const XAestheticApp());

    // Không dùng pumpAndSettle vì màn Camera có CircularProgressIndicator/animation
    // trong lúc plugin camera khởi tạo hoặc fallback trên môi trường test.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Chụp'),
        findsNothing); // Bottom navigation ẩn trên màn camera.
    expect(find.text('Phân tích'), findsNothing);
    expect(find.text('X-Aesthetic'), findsOneWidget);
  });
}
