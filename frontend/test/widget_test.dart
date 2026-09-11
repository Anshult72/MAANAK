import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maanak_app/main.dart';

void main() {
  testWidgets('LM-TRACE App boot smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaanakApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MaanakApp), findsOneWidget);
  });
}
