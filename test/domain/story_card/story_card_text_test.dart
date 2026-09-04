import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/app_links.dart';
import 'package:focussayac/domain/story_card/story_card_text.dart';

import '../../support/localized_test_app.dart';

StoryCardText _text(
  StoryCardTemplate template, {
  int todayFocusSeconds = 2 * 3600 + 15 * 60,
  int streak = 6,
  String? examName = 'YKS 2027',
  String? examDateText = '20 Haziran 2027',
  int? daysRemaining = 132,
}) {
  return buildStoryCardText(
    l10n: testL10n,
    template: template,
    todayFocusSeconds: todayFocusSeconds,
    streak: streak,
    examName: examName,
    examDateText: examDateText,
    daysRemaining: daysRemaining,
  );
}

void main() {
  group('GECE MEŞALESİ', () {
    test('bugünkü odak süresi hem sayaç hem cümle olarak', () {
      final StoryCardText text = _text(StoryCardTemplate.nightTorch);

      expect(text.tag, 'BUGÜNÜN ODAĞI');
      expect(text.big, '2:15');
      expect(text.line1, 'Bugün 2 saat 15 dakika odaklandım.');
      // Sınav adı rakamla bittiği için ek okunuştan türüyor (`…yedi` → `'ye`).
      expect(text.line2, "YKS 2027'ye 132 gün kaldı");
    });

    test('bir saatin altı ve tam saat farklı yazılıyor', () {
      expect(_text(StoryCardTemplate.nightTorch, todayFocusSeconds: 45 * 60).line1,
          'Bugün 45 dakika odaklandım.');
      expect(_text(StoryCardTemplate.nightTorch, todayFocusSeconds: 3 * 3600).line1,
          'Bugün 3 saat odaklandım.');
      expect(_text(StoryCardTemplate.nightTorch, todayFocusSeconds: 45 * 60).big, '0:45');
    });

    test('aktif sınav yokken ikinci satır boş kalıyor', () {
      final StoryCardText text = _text(
        StoryCardTemplate.nightTorch,
        examName: null,
        examDateText: null,
        daysRemaining: null,
      );

      expect(text.line2, isEmpty);
      // Bugünkü odak yine gerçek veriden geliyor.
      expect(text.big, '2:15');
    });
  });

  group('MİNİMAL', () {
    test('sınav adı etiket, kalan gün büyük sayı', () {
      final StoryCardText text = _text(StoryCardTemplate.minimal);

      expect(text.tag, 'YKS 2027');
      expect(text.big, '132');
      expect(text.line1, 'gün kaldı.');
      expect(text.line2, '20 Haziran 2027');
    });

    test('aktif sınav yokken sayı uydurulmuyor', () {
      final StoryCardText text = _text(
        StoryCardTemplate.minimal,
        examName: null,
        examDateText: null,
        daysRemaining: null,
      );

      expect(text.tag, 'HEDEF');
      expect(text.big, '—');
      expect(text.line1, 'hedef seçilmedi.');
      expect(text.line2, isEmpty);
    });
  });

  group('SERİ', () {
    test('yarınki seri sayısının eki okunuşundan türüyor', () {
      final StoryCardText text = _text(StoryCardTemplate.streak);

      expect(text.tag, 'SERİ');
      expect(text.big, '6');
      expect(text.line1, 'gün üst üste odaklandım.');
      expect(text.line2, "Yarın 7'ye çıkıyor"); // yedi
      expect(_text(StoryCardTemplate.streak, streak: 8).line2, "Yarın 9'a çıkıyor"); // dokuz
    });

    test('seri yokken davet cümlesi', () {
      final StoryCardText text = _text(StoryCardTemplate.streak, streak: 0);

      expect(text.big, '0');
      expect(text.line2, 'Bugün bir pomodoro seriyi başlatır.');
    });
  });

  group('paylaşım metni', () {
    test('her şablonda tam cümle + mağaza adresi', () {
      // Kartta sayı (`big`) ve satır (`line1`) ayrı duruyor; paylaşımda
      // "gün kaldı. focussayaç ile:" gibi yarım bir cümle çıkmamalı.
      expect(
        buildStoryCardShareText(testL10n, _text(StoryCardTemplate.nightTorch)),
        'Bugün 2 saat 15 dakika odaklandım. — focussayaç ile: $kPlayStoreUrl',
      );
      expect(
        buildStoryCardShareText(testL10n, _text(StoryCardTemplate.minimal)),
        "YKS 2027'ye 132 gün kaldı — focussayaç ile: $kPlayStoreUrl",
      );
      expect(
        buildStoryCardShareText(testL10n, _text(StoryCardTemplate.streak)),
        '6 gün üst üste odaklandım. — focussayaç ile: $kPlayStoreUrl',
      );
    });

    test('veri yokken uydurma sayı paylaşılmıyor', () {
      final String noExam = buildStoryCardShareText(
        testL10n,
        _text(
          StoryCardTemplate.minimal,
          examName: null,
          examDateText: null,
          daysRemaining: null,
        ),
      );
      // Kartın "—" ve "hedef seçilmedi." parçaları metne sızmamalı.
      expect(noExam, 'Odaklanmaya devam ediyorum. — focussayaç ile: $kPlayStoreUrl');

      final String noStreak =
          buildStoryCardShareText(testL10n, _text(StoryCardTemplate.streak, streak: 0));
      expect(noStreak, isNot(contains('0 gün')));
      expect(noStreak, contains(kPlayStoreUrl));
    });

    test('mağaza adresindeki paket adı applicationId ile aynı', () {
      // `android/app/build.gradle.kts` içindeki `applicationId`.
      expect(kPlayStoreUrl, endsWith('?id=com.focussayac.focussayac'));
    });
  });

  group('şablon indeksi', () {
    test('kayıtlı indeks şablona eşleniyor, aralık dışı ilkine düşüyor', () {
      expect(StoryCardTemplate.fromIndex(0), StoryCardTemplate.nightTorch);
      expect(StoryCardTemplate.fromIndex(1), StoryCardTemplate.minimal);
      expect(StoryCardTemplate.fromIndex(2), StoryCardTemplate.streak);
      expect(StoryCardTemplate.fromIndex(3), StoryCardTemplate.nightTorch);
      expect(StoryCardTemplate.fromIndex(-1), StoryCardTemplate.nightTorch);
    });
  });
}
