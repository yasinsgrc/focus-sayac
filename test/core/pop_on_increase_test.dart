import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_motion.dart';
import 'package:focussayac/core/widgets/pop_on_increase.dart';

/// Vurgu **yalnızca artışta** çalışıyor. Testin asıl değeri iki karşı
/// kontrolde: ekran her açıldığında (ilk build) ve seri kırıldığında (değer
/// düşünce) alev zıplamamalı.
void main() {
  Widget host(int value, {bool disableAnimations = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PopOnIncrease(value: value, child: const SizedBox(width: 12, height: 12)),
      ),
    );
  }

  /// Ölçek tam 1'ken ağaca `Transform` girmiyor — bu yüzden "vurgu var mı"
  /// sorusunun cevabı `Transform`un varlığı.
  double? currentScale(WidgetTester tester) {
    final Iterable<Transform> transforms = tester.widgetList<Transform>(find.byType(Transform));
    if (transforms.isEmpty) return null;
    return transforms.first.transform.entry(0, 0);
  }

  testWidgets('ilk build vurgu yapmıyor', (WidgetTester tester) async {
    await tester.pumpWidget(host(5));
    expect(currentScale(tester), isNull);

    await tester.pump(const Duration(milliseconds: 120));
    expect(currentScale(tester), isNull);
  });

  testWidgets('değer artınca bir kez büyüyüp 1e dönüyor', (WidgetTester tester) async {
    await tester.pumpWidget(host(5));
    await tester.pumpWidget(host(6));
    await tester.pump();

    await tester.pump(AppMotion.base ~/ 2);
    final double? peak = currentScale(tester);
    expect(peak, isNotNull);
    expect(peak, greaterThan(1.0));

    await tester.pumpAndSettle();
    expect(currentScale(tester), isNull, reason: 'vurgu bitince ölçek tam 1e dönüyor');
  });

  testWidgets('değer düşünce vurgu yok', (WidgetTester tester) async {
    await tester.pumpWidget(host(6));
    await tester.pumpWidget(host(5));
    await tester.pump();

    await tester.pump(AppMotion.base ~/ 2);
    expect(currentScale(tester), isNull);
  });

  testWidgets('hareketi azalt açıkken artışta da vurgu yok', (WidgetTester tester) async {
    await tester.pumpWidget(host(5, disableAnimations: true));
    await tester.pumpWidget(host(6, disableAnimations: true));
    await tester.pump();

    await tester.pump(AppMotion.base ~/ 2);
    expect(currentScale(tester), isNull);
  });
}
