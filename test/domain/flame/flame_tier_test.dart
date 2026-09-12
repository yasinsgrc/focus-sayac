import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/flame/flame_tier.dart';

/// Saat -> saniye. Merdivenin tamamı saat cinsinden tanımlı, girdi ise saniye.
int _h(num hours) => (hours * 3600).round();

void main() {
  group('merdiven biçimi', () {
    test('10 kademe var, indeksler 1..10', () {
      expect(kFlameTierLadder.length, 10);
      expect(
        kFlameTierLadder.map((FlameTier t) => t.index),
        <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
    });

    test('eşikler kesin artan ve K1 sıfırdan başlıyor', () {
      expect(kFlameTierLadder.first.thresholdHours, 0);
      for (int i = 1; i < kFlameTierLadder.length; i++) {
        expect(
          kFlameTierLadder[i].thresholdHours,
          greaterThan(kFlameTierLadder[i - 1].thresholdHours),
          reason: 'K${i + 1} eşiği K$i ile aynı ya da altında',
        );
      }
    });

    test('ölçek 0.35ten 1.0a kesin artıyor', () {
      expect(kFlameTierLadder.first.scale, 0.35);
      expect(kFlameTierLadder.last.scale, 1.0);
      for (int i = 1; i < kFlameTierLadder.length; i++) {
        expect(kFlameTierLadder[i].scale, greaterThan(kFlameTierLadder[i - 1].scale));
      }
    });

    test('görsel yükseliş asla geri gitmiyor', () {
      // emberBase bir kez açıldıktan sonra kapanmıyor; sparkCount ve
      // haloOpacity hiç azalmıyor. Doc yorumlarının verdiği söz bu — burada
      // çivileniyor ki ilerideki bir eşik düzenlemesi süsü sessizce geri almasın.
      for (int i = 1; i < kFlameTierLadder.length; i++) {
        final FlameTier prev = kFlameTierLadder[i - 1];
        final FlameTier curr = kFlameTierLadder[i];
        if (prev.emberBase) {
          expect(curr.emberBase, isTrue, reason: 'K${curr.index} emberBase geri gitti');
        }
        expect(
          curr.sparkCount,
          greaterThanOrEqualTo(prev.sparkCount),
          reason: 'K${curr.index} sparkCount K${prev.index}den az',
        );
        expect(
          curr.haloOpacity,
          greaterThanOrEqualTo(prev.haloOpacity),
          reason: 'K${curr.index} haloOpacity K${prev.index}den az',
        );
      }
    });
  });

  group('flameTierFor', () {
    test('geçmiş boşken K1', () {
      final FlameTierStatus status = flameTierFor(0);
      expect(status.tier.index, 1);
      expect(status.cumulativeHours, 0);
      expect(status.nextTier!.index, 2);
      expect(status.hoursRemaining, 1);
      expect(status.ratioInTier, 0);
    });

    test('tam eşikte kademe atlıyor, bir saniye altı hâlâ önceki — tüm on kademe', () {
      // Yalnızca rozetle çakışan eşikleri (K4/K6/K7/K9) değil, merdivenin
      // tamamını çiviliyor: Task 9 bu tabloyu Kotlin'e birebir aktarıyor,
      // o yüzden aradaki kademelerin (K2/K3/K5/K8/K10) hizası da yük taşıyor.
      for (int i = 0; i < kFlameTierLadder.length; i++) {
        final FlameTier expectedTier = kFlameTierLadder[i];
        expect(
          flameTierFor(_h(expectedTier.thresholdHours)).tier.index,
          expectedTier.index,
          reason: 'K${expectedTier.index} eşiğinde (${expectedTier.thresholdHours}sa) beklenen kademeye ulaşmadı',
        );

        if (i > 0) {
          final FlameTier previousTier = kFlameTierLadder[i - 1];
          expect(
            flameTierFor(_h(expectedTier.thresholdHours) - 1).tier.index,
            previousTier.index,
            reason: 'K${expectedTier.index} eşiğinin bir saniye altı hâlâ K${previousTier.index} olmalı',
          );
        }
      }
    });

    test('saat aşağı yuvarlanıyor — 99sa 59dk hâlâ K6', () {
      final FlameTierStatus status = flameTierFor(_h(99) + 59 * 60);
      expect(status.tier.index, 6);
      expect(status.cumulativeHours, 99);
      expect(status.hoursRemaining, 1);
    });

    test('kademe içi oran iki uçta doğru', () {
      // K6 50sa, K7 100sa -> 75sa tam orta.
      expect(flameTierFor(_h(75)).ratioInTier, closeTo(0.5, 1e-9));
      expect(flameTierFor(_h(50)).ratioInTier, 0);
      expect(flameTierFor(_h(99)).ratioInTier, closeTo(0.98, 1e-9));
    });

    test('kalan saat sonraki eşiğe olan fark', () {
      final FlameTierStatus status = flameTierFor(_h(62));
      expect(status.tier.index, 6);
      expect(status.nextTier!.thresholdHours, 100);
      expect(status.hoursRemaining, 38);
    });

    test('en üst kademede sonraki yok', () {
      final FlameTierStatus status = flameTierFor(_h(400));
      expect(status.tier.index, 10);
      expect(status.nextTier, isNull);
      expect(status.hoursRemaining, isNull);
      expect(status.ratioInTier, 1);
      expect(status.isTopTier, isTrue);
    });

    test('en üst kademenin çok üstünde de K10, taşma yok', () {
      final FlameTierStatus status = flameTierFor(_h(5000));
      expect(status.tier.index, 10);
      expect(status.ratioInTier, 1);
      expect(status.cumulativeHours, 5000);
    });

    test('negatif girdi K1e düşüyor, patlamıyor', () {
      // Savunma amaçlı: veri bozulsa bile ekran çizilmeli.
      expect(flameTierFor(-1).tier.index, 1);
      expect(flameTierFor(-1).cumulativeHours, 0);
    });
  });
}
