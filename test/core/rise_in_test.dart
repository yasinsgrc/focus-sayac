import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/core/widgets/rise_in.dart';

/// `RiseIn` prototipin `@keyframes rise` girişini taşıyor: içerik görünmez ve
/// 14px aşağıdan başlayıp yerine oturuyor. Testler animasyonun **ara**
/// değerlerini değil, ilk karedeki gizliliği ve sonundaki tam görünürlüğü
/// doğruluyor — aradaki değerler eğriye bağlı ve kırılgan olurdu.
void main() {
  Finder opacityFinder() => find.ancestor(of: find.text('içerik'), matching: find.byType(Opacity));

  testWidgets('ilk karede görünmez, süre dolunca tam görünür', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: RiseIn(child: Text('içerik'))));

    expect(tester.widget<Opacity>(opacityFinder()).opacity, 0);

    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<Opacity>(opacityFinder()).opacity, 1);
  });

  testWidgets('gecikme dolana kadar görünmez kalıyor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RiseIn(delay: Duration(milliseconds: 300), child: Text('içerik'))),
    );

    // Gecikme sürerken hiç ilerlemiyor: prototipteki `both` doldurma kipi.
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<Opacity>(opacityFinder()).opacity, 0);

    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.widget<Opacity>(opacityFinder()).opacity, 1);
  });

  testWidgets('hareketi azalt açıkken animasyon hiç kurulmuyor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: RiseIn(delay: Duration(seconds: 5), child: Text('içerik'))),
      ),
    );

    // Uzun gecikmeye rağmen içerik ilk karede son hâlinde: araya `Opacity`
    // katmanı hiç girmiyor.
    expect(find.text('içerik'), findsOneWidget);
    expect(opacityFinder(), findsNothing);
  });

  testWidgets('gecikme dolmadan ağaçtan kalkarsa hata atmıyor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RiseIn(delay: Duration(milliseconds: 300), child: Text('içerik'))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
  });
}
