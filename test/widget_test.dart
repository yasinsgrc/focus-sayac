import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/main.dart';

void main() {
  testWidgets('App boots and renders the root shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FocusSayacApp()));
    await tester.pumpAndSettle();

    expect(find.text('FocusSayaç'), findsOneWidget);
  });
}
