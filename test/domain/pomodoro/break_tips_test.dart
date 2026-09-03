import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/pomodoro/break_tips.dart';

import '../../support/localized_test_app.dart';

void main() {
  group('selectBreakTips', () {
    test('SPEC Ekran 09: her molada katalogdan 2 ipucu', () {
      final List<BreakTip> tips = selectBreakTips(
        breakStartedAtUtc: DateTime.utc(2027, 3, 1, 9, 25),
      );

      expect(tips, hasLength(kBreakTipsPerBreak));
      expect(tips.toSet(), hasLength(kBreakTipsPerBreak), reason: 'aynı ipucu iki kez gösterilmemeli');
    });

    test('aynı mola boyunca seçim değişmiyor', () {
      // Ekran 09 saniyede bir yeniden çiziliyor; `build` her koştuğunda yeni
      // zar atılsaydı ipuçları gözün önünde değişirdi.
      final DateTime startedAt = DateTime.utc(2027, 3, 1, 9, 25);

      expect(
        selectBreakTips(breakStartedAtUtc: startedAt),
        selectBreakTips(breakStartedAtUtc: startedAt),
      );
    });

    test('farklı molalar aynı iki ipucuna saplanmıyor', () {
      final Set<BreakTip> seen = <BreakTip>{};
      for (int i = 0; i < 40; i++) {
        seen.addAll(
          selectBreakTips(breakStartedAtUtc: DateTime.utc(2027, 3, 1, 9, 25).add(Duration(minutes: i))),
        );
      }

      // Katalogdaki her ipucu er ya da geç çıkmalı — sabit bir çift değil.
      expect(seen, hasLength(BreakTip.values.length));
    });

    test('istenen sayı katalogdan büyükse katalog kadar döner', () {
      final List<BreakTip> tips = selectBreakTips(
        breakStartedAtUtc: DateTime.utc(2027, 3, 1),
        count: BreakTip.values.length + 5,
      );

      expect(tips, hasLength(BreakTip.values.length));
    });
  });

  test('her ipucunun ARB metni var (SPEC §0 kural 7)', () {
    for (final BreakTip tip in BreakTip.values) {
      expect(tip.text(testL10n), isNotEmpty, reason: '${tip.name} ARB metni boş');
    }
  });
}
