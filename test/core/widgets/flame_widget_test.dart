import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_theme.dart';
import 'package:focussayac/core/widgets/flame_widget.dart';
import 'package:focussayac/domain/flame/flame_tier.dart';

const double _kBox = 98;

Future<void> _pump(
  WidgetTester tester, {
  required FlameTier tier,
  double intensity = 0,
  bool flickering = false,
  bool desaturated = false,
  double boxHeight = _kBox,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: FlameWidget(
            tier: tier,
            intensity: intensity,
            flickering: flickering,
            desaturated: desaturated,
            boxHeight: boxHeight,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Kademe ölçeğini taşıyan **en dıştaki** `Transform` — titreşim dönüşümü
/// içeride, kare kare değişen o.
///
/// `getMaxScaleOnAxis()` kullanılmıyor: `Transform.scale` yalnızca x/y
/// köşegenini `tier.scale` yapar, z köşegeni 1.0'da sabit kalır. Tüm kademe
/// oranları ≤ 1.0 olduğundan z ekseni her zaman kazanır ve
/// `getMaxScaleOnAxis()` kademeden bağımsız sabit 1.0 döner — ölçeği hiç
/// ayırt etmez. Bunun yerine x köşegenini doğrudan okuyoruz.
///
/// `.first` örtük bir sıralama varsayıyor: dıştaki kademe `Transform`u
/// ağaçta içteki titreşim `Transform`undan önce geliyor çünkü doğrudan
/// `FlameWidget`in kökünde, `AnimatedBuilder`ın ürettiği alt ağaçtan daha
/// sığ derinlikte duruyor (bkz. Task 4 doğrulaması — element depth 159 vs
/// 162). Widget ağacı yeniden düzenlenirse bu varsayım sessizce bozulabilir.
double _tierScale(WidgetTester tester) {
  final Transform outer = tester
      .widgetList<Transform>(find.descendant(
        of: find.byType(FlameWidget),
        matching: find.byType(Transform, skipOffstage: false),
      ))
      .first;
  return outer.transform.getColumn(0).length;
}

/// Belirli bir boyuttaki `Container`ın düz rengi (varsa) — çekirdek ve
/// kıvılcımlar `color:` ile boyanıyor, gövde/hâle/kor yatağı gradyanla.
/// Boyut anahtarı olarak kullanılıyor çünkü prod kodda `Key` yok ve
/// eklemeye gerek yok — her parçanın sabit, birbirinden farklı bir boyutu
/// var.
double? _flatColorAlphaOfSize(WidgetTester tester, double width, double height) {
  final Iterable<Container> containers = tester.widgetList<Container>(
    find.descendant(of: find.byType(FlameWidget), matching: find.byType(Container)),
  );
  for (final Container c in containers) {
    if (c.constraints == BoxConstraints.tightFor(width: width, height: height)) {
      return (c.decoration! as BoxDecoration).color?.a;
    }
  }
  return null;
}

void main() {
  final FlameTier k1 = kFlameTierLadder.first;
  final FlameTier k6 = kFlameTierLadder[5];
  final FlameTier k10 = kFlameTierLadder.last;

  testWidgets('kademe ölçeği uygulanıyor', (WidgetTester tester) async {
    await _pump(tester, tier: k1);
    expect(_tierScale(tester), closeTo(k1.scale, 1e-6));

    await _pump(tester, tier: k10);
    expect(_tierScale(tester), closeTo(k10.scale, 1e-6));
  });

  testWidgets('seans yoğunluğu BOYUTU değiştirmiyor', (WidgetTester tester) async {
    // Kalıcılık vaadinin tamamı bu testte: iki eksen ayrı kanallarda.
    await _pump(tester, tier: k6, intensity: 0);
    final double resting = _tierScale(tester);

    await _pump(tester, tier: k6, intensity: 1);
    expect(_tierScale(tester), closeTo(resting, 1e-6));
  });

  testWidgets('yüksek kademe düşük kademeden büyük', (WidgetTester tester) async {
    await _pump(tester, tier: k1);
    final double small = _tierScale(tester);
    await _pump(tester, tier: k10);
    expect(_tierScale(tester), greaterThan(small));
  });

  testWidgets('flickering false iken titreşim tikleyicisi çalışmıyor',
      (WidgetTester tester) async {
    // `pumpAndSettle` sonsuz tekrarlı bir animasyonda zaman aşımına düşer;
    // düşmemesi tikleyicinin gerçekten durduğunu kanıtlıyor.
    await _pump(tester, tier: k6, flickering: false);
    await tester.pumpAndSettle();
    expect(find.byType(FlameWidget), findsOneWidget);
  });

  testWidgets('desaturated alevi ColorFiltered ile soluyor', (WidgetTester tester) async {
    await _pump(tester, tier: k6, desaturated: true);
    expect(
      find.descendant(of: find.byType(FlameWidget), matching: find.byType(ColorFiltered)),
      findsOneWidget,
    );
  });

  testWidgets('iki RepaintBoundary korunuyor', (WidgetTester tester) async {
    // SPEC.md §6 kural 5 / DECISIONS.md:811 — dıştaki 72px sayacı ayırıyor,
    // içteki Transformu bileşikleştiriyor.
    await _pump(tester, tier: k6, flickering: true);
    expect(
      find.descendant(of: find.byType(FlameWidget), matching: find.byType(RepaintBoundary)),
      findsAtLeastNWidgets(2),
    );
  });

  testWidgets('boxHeight kutuyu gerçekten dolduruyor', (WidgetTester tester) async {
    // Sözleşme: tam büyümüş bir alev `boxHeight`i doldurur. 98'de (odak
    // ekranı) regresyon olmamalı; 120'de (rozet kartı) K10 orantılı büyümeli
    // — eskiden `boxHeight` yalnızca bir tavan gibi kırpardı, hiç büyütmezdi.
    await _pump(tester, tier: k10, boxHeight: 98);
    final double at98 = _tierScale(tester);
    expect(at98, closeTo(k10.scale, 1e-6));

    await _pump(tester, tier: k10, boxHeight: 120);
    final double at120 = _tierScale(tester);
    expect(at120, greaterThan(at98));
    expect(at120, closeTo(at98 * 120 / 98, 1e-6));

    // `_FlameShape` hâlâ kendi doğal (98) yüksekliğinde layout kuruyor —
    // `Transform` yalnızca paint'i etkiliyor — bu yüzden 120'lik kutuya
    // taşma olmamalı.
    expect(tester.takeException(), isNull);
  });

  testWidgets('seans yoğunluğu çekirdek ve kıvılcım kanallarını gerçekten değiştiriyor',
      (WidgetTester tester) async {
    // Test 2 yalnızca boyutun DEĞİŞMEDİĞİNİ kanıtlıyor; bu test yoğunluğun
    // başka bir şeyi gerçekten değiştirdiğini kanıtlıyor — aksi halde
    // `intensity` sessizce yok sayılsa bile tüm paket yeşil kalırdı.
    await _pump(tester, tier: k6, intensity: 0);
    final double coreAt0 = _flatColorAlphaOfSize(tester, 18, 46)!;
    final double sparkAt0 = _flatColorAlphaOfSize(tester, 3.5, 3.5)!;

    await _pump(tester, tier: k6, intensity: 1);
    final double coreAt1 = _flatColorAlphaOfSize(tester, 18, 46)!;
    final double sparkAt1 = _flatColorAlphaOfSize(tester, 3.5, 3.5)!;

    expect(coreAt1, greaterThan(coreAt0));
    expect(sparkAt1, greaterThan(sparkAt0));
  });
}
