import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/core/theme/app_motion.dart';
import 'package:focussayac/core/widgets/rolling_number.dart';

/// `RollingNumber` odometre kuralını taşıyor: değer değişince yalnızca değişen
/// karakter kayar. Testler ara **değerleri** değil (eğriye bağlı, kırılgan)
/// yapının kendisini doğruluyor — ara karede ağaçta kim var, kim kımıldamıyor.
Widget _host(int value, {bool disableAnimations = false, String? text}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      home: Center(
        child: RollingNumber(value: value, text: text, style: const TextStyle(fontSize: 20)),
      ),
    ),
  );
}

/// Animasyonun ortası: `AppMotion.base`in yarısı.
const Duration _midway = Duration(milliseconds: 130);

void main() {
  testWidgets('değişen basamak ara karede eski hâliyle birlikte duruyor', (WidgetTester tester) async {
    await tester.pumpWidget(_host(132));
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(_host(131));
    await tester.pump(_midway);

    // Eski birler basamağı hâlâ ağaçta, yenisi de: yuva ikisini birden çiziyor.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2), reason: 'yüzler basamağı + yeni birler basamağı');

    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('değişmeyen basamaklar hiç kımıldamıyor', (WidgetTester tester) async {
    await tester.pumpWidget(_host(132));
    // `3` "132" ve "131"de tek: konumu doğrudan ölçülebiliyor.
    final Offset before = tester.getTopLeft(find.text('3'));

    await tester.pumpWidget(_host(131));
    await tester.pump(_midway);
    expect(tester.getTopLeft(find.text('3')), before);

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('3')), before);
  });

  testWidgets('artan sayı aşağıdan yukarı, azalan sayı yukarıdan aşağı akıyor', (WidgetTester tester) async {
    await tester.pumpWidget(_host(5));
    await tester.pumpWidget(_host(6));
    await tester.pump(_midway);
    // Artışta eski hane yukarı çıkıyor, yenisi aşağıdan geliyor.
    expect(tester.getTopLeft(find.text('5')).dy, lessThan(tester.getTopLeft(find.text('6')).dy));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_host(5));
    await tester.pump(_midway);
    expect(tester.getTopLeft(find.text('6')).dy, greaterThan(tester.getTopLeft(find.text('5')).dy));
    await tester.pumpAndSettle();
  });

  testWidgets('hareketi azalt açıkken ara kare yok', (WidgetTester tester) async {
    await tester.pumpWidget(_host(132, disableAnimations: true));
    await tester.pumpWidget(_host(131, disableAnimations: true));

    // İlk karede son değer: eski basamak ağaca hiç girmiyor.
    expect(find.text('2'), findsNothing);
    expect(find.text('1'), findsNWidgets(2));
  });

  testWidgets('sabit ekler kımıldamadan sayı dönüyor', (WidgetTester tester) async {
    await tester.pumpWidget(_host(5, text: '5 gün seri'));
    final Offset unitBefore = tester.getTopLeft(find.text('g'));

    await tester.pumpWidget(_host(6, text: '6 gün seri'));
    await tester.pump(_midway);

    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(tester.getTopLeft(find.text('g')), unitBefore);
  });

  test('süre token’ları tek kaynakta', () {
    // `RiseIn` bu ikisini kendi içinde tutuyordu; artık buradan okuyor.
    expect(AppMotion.entrance, const Duration(milliseconds: 600));
    expect(AppMotion.step, const Duration(milliseconds: 60));
  });

  testWidgets('respectingMotion kapısı iki yönde de çalışıyor', (WidgetTester tester) async {
    late Duration enabled;
    late Duration reduced;

    Widget probe({required bool disableAnimations, required void Function(Duration) sink}) {
      return MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (BuildContext context) {
            sink(AppMotion.respectingMotion(context, AppMotion.base));
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(probe(disableAnimations: false, sink: (Duration d) => enabled = d));
    await tester.pumpWidget(probe(disableAnimations: true, sink: (Duration d) => reduced = d));

    expect(enabled, AppMotion.base);
    expect(reduced, Duration.zero);
  });
}
