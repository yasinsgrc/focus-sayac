import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_motion.dart';
import 'package:focussayac/domain/badges/badge_definition.dart';
import 'package:focussayac/features/badges/badges_screen.dart';

import '../../support/localized_test_app.dart';

/// Rozet açılışının hareketi (ROADMAP madde 19). Testin en değerli iddiası
/// `pumpAndSettle`in takılmaması: nabız gibi atan bir halo animasyonu hem
/// SPEC.md §6.4'e aykırı olurdu hem de bu testi kilitlerdi.
void main() {
  Future<void> openDialog(WidgetTester tester, {required bool unlocked}) async {
    await tester.pumpWidget(
      localizedTestApp(
        Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => showBadgeUnlockDialog(
                context,
                definition: kBadgeCatalog.first,
                unlocked: unlocked,
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pump();
  }

  /// Kartın giriş ölçeği — dialogun kendi `Transform`u (halo `Transform`
  /// kullanmıyor, opaklıkla sönüyor).
  double dialogScale(WidgetTester tester) {
    return tester.widgetList<Transform>(find.byType(Transform)).first.transform.entry(0, 0);
  }

  testWidgets('açılan rozetin dialogu yerine oturuyor, halo bir kez sönüyor', (WidgetTester tester) async {
    await openDialog(tester, unlocked: true);

    expect(dialogScale(tester), lessThan(1.0), reason: 'kart 0.92ten geliyor');
    expect(find.byKey(kBadgeUnlockHaloKey), findsOneWidget);

    // Takılırsa halo sonsuz demektir — bu testin asıl değeri burada.
    await tester.pumpAndSettle();
    expect(dialogScale(tester), closeTo(1, 0.0001));
    expect(find.byKey(kBadgeUnlockHaloKey), findsOneWidget, reason: 'halo sönüyor ama ağaçtan çıkmıyor');
  });

  testWidgets('kilitli rozetin dialogunda halo yok', (WidgetTester tester) async {
    await openDialog(tester, unlocked: false);

    expect(find.byKey(kBadgeUnlockHaloKey), findsNothing);
    await tester.pumpAndSettle();
    expect(dialogScale(tester), closeTo(1, 0.0001));
  });

  testWidgets('hareketi azalt açıkken ilk kare son hâli çiziyor', (WidgetTester tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await openDialog(tester, unlocked: true);

    expect(dialogScale(tester), closeTo(1, 0.0001));
    expect(find.byKey(kBadgeUnlockHaloKey), findsNothing, reason: 'halo hiç kurulmuyor');
  });

  // `AppMotion.pop` hedefi hafifçe aşan bir eğri: 0.92 → 1.0 geçişinde ölçek
  // yolun bir yerinde 1'i geçmeli, yoksa "yerine oturma" hissi kaybolur.
  testWidgets('giriş eğrisi hedefi hafifçe aşıyor', (WidgetTester tester) async {
    await openDialog(tester, unlocked: true);

    double maxScale = 0;
    for (int i = 0; i < 10; i++) {
      await tester.pump(AppMotion.base ~/ 10);
      maxScale = maxScale > dialogScale(tester) ? maxScale : dialogScale(tester);
    }
    expect(maxScale, greaterThan(1.0));

    await tester.pumpAndSettle();
  });
}
