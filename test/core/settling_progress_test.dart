import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/core/widgets/settling_progress.dart';

/// Halkanın oranı **bir kez** akıyor. Bu testin asıl değeri ikinci iddiada:
/// yerleşme bittikten sonra her saniye tikinin yeni bir 420ms'lik animasyon
/// başlatmadığı — yoksa süren bir odak seansı boyunca kesintisiz kare
/// üretilirdi (SPEC.md §6.4).
void main() {
  late double lastValue;

  Widget host(double progress, {bool disableAnimations = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: MaterialApp(
        home: SettlingProgress(
          progress: progress,
          builder: (BuildContext context, double value, Widget? child) {
            lastValue = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('ilk değerine akıyor, sonraki değerler aynı karede geçiyor', (WidgetTester tester) async {
    await tester.pumpWidget(host(0.4));
    expect(lastValue, 0, reason: 'yerleşme 0dan başlıyor');

    await tester.pump(const Duration(milliseconds: 200));
    expect(lastValue, greaterThan(0.0));
    expect(lastValue, lessThan(0.4));

    await tester.pumpAndSettle();
    expect(lastValue, closeTo(0.4, 0.0001));

    // Saniye tikinin getirdiği yeni oran: ara kare yok.
    await tester.pumpWidget(host(0.5));
    expect(lastValue, 0.5);
  });

  testWidgets('hareketi azalt açıkken ilk kare son değeri gösteriyor', (WidgetTester tester) async {
    await tester.pumpWidget(host(0.4, disableAnimations: true));
    expect(lastValue, 0.4);
  });
}
