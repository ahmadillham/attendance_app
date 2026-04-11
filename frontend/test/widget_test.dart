import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_kuliah/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const AbsensiApp());
    expect(find.text('Absensi Kuliah'), findsOneWidget);
  });
}
