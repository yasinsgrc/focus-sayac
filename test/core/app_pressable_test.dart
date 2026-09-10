import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_motion.dart';
import 'package:focussayac/core/widgets/app_pressable.dart';

/// Sarmalayıcının iki sözü var ve testin tamamı o ikisini kovalıyor: basıldığı
/// **hissediliyor** (ölçek 1'in altına iniyor, bırakınca tam 1'e dönüyor) ve
/// sardığı butonun dokunuşunu **yutmuyor** (`onTap` yine tetikleniyor).
void main() {
  Widget host({
    required VoidCallback onTap,
    bool enabled = true,
    bool disableAnimations = false,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          child: Center(
            child: AppPressable(
              enabled: enabled,
              child: SizedBox(
                width: 200,
                height: 60,
                child: InkWell(onTap: onTap, child: const Center(child: Text('ODAKLAN'))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// `Transform` ölçek 1'ken de ağaçta (basış anında araya girseydi `InkWell`in
  /// alt ağacı yeniden kurulur ve jest ortasında iptal olurdu), o yüzden ölçüm
  /// varlığına değil **değerine** bakıyor.
  double currentScale(WidgetTester tester) {
    final Finder finder = find.descendant(
      of: find.byType(AppPressable),
      matching: find.byType(Transform),
    );
    return tester.widget<Transform>(finder.first).transform.entry(0, 0);
  }

  testWidgets('basılıyken ölçek 1in altında, bırakınca tam 1e dönüyor', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++));
    expect(currentScale(tester), closeTo(1, 1e-9), reason: 'parmak değmeden ölçek tam 1');

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('ODAKLAN')));
    await tester.pump();
    await tester.pump(AppMotion.instant);
    expect(currentScale(tester), lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(currentScale(tester), closeTo(1, 1e-9), reason: 'bırakınca ölçek tam 1e dönüyor');
    // Asıl regresyon: ölçek jest arenasına girseydi `InkWell`in tanıyıcısıyla
    // yarışır ve dokunuş kaybolabilirdi.
    expect(taps, 1, reason: 'sardığı butonun onTapi hâlâ tetikleniyor');
  });

  testWidgets('kapalı butonda basılı hâl yok', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++, enabled: false));

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('ODAKLAN')));
    await tester.pump();
    await tester.pump(AppMotion.instant);
    expect(currentScale(tester), closeTo(1, 1e-9));

    await gesture.up();
    await tester.pumpAndSettle();
    // `enabled: false` yalnızca ölçeği kapatıyor. Gerçek çağıranlar aynı
    // koşulu `InkWell.onTap`e de veriyor (`onPressed != null`); sarmalayıcının
    // kendisi dokunuşu engellemiyor ve bu bilinçli — jest arenasına hiç
    // girmemesinin karşılığı bu.
    expect(taps, 1, reason: 'AppPressable dokunuşu kendisi engellemiyor');
  });

  testWidgets('hareketi azalt açıkken basılı hâl hiç kurulmuyor', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(host(onTap: () => taps++, disableAnimations: true));

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('ODAKLAN')));
    await tester.pump();
    await tester.pump(AppMotion.instant);
    expect(currentScale(tester), closeTo(1, 1e-9));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  // Ölçek `Transform`la uygulanıyor, düzenle değil: madde 12'nin 48px kuralı
  // basılı hâlde de geçerli — `SizedBox` küçülseydi dokunma hedefi de küçülürdü.
  testWidgets('basılı hâl düzen boyutunu değiştirmiyor', (WidgetTester tester) async {
    await tester.pumpWidget(host(onTap: () {}));
    final Size released = tester.getSize(find.byType(AppPressable));

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('ODAKLAN')));
    await tester.pump();
    await tester.pump(AppMotion.instant);
    expect(tester.getSize(find.byType(AppPressable)), released);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
