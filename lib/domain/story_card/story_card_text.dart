import '../../core/app_links.dart';
import '../../l10n/gen/app_localizations.dart';
import '../text/turkish_suffix.dart';
import '../time/duration_formatter.dart';

/// Ekran 05'in üç şablonu (prototip v2 satır 506-512). Üçü de v1'de
/// **ücretsiz** (SPEC.md Ekran 05); sıra `AppSettings.selectedTemplateIndex`
/// kolonuna yazılan indeksle aynı olmak zorunda.
enum StoryCardTemplate {
  nightTorch,
  minimal,
  streak;

  /// Şablon seçici düğmesinin metni (ARB'den — SPEC.md §0 kural 7).
  String label(AppLocalizations l10n) => switch (this) {
        StoryCardTemplate.nightTorch => l10n.storyCardTemplateNightTorch,
        StoryCardTemplate.minimal => l10n.storyCardTemplateMinimal,
        StoryCardTemplate.streak => l10n.storyCardTemplateStreak,
      };

  /// Kayıtlı indeksi şablona çevirir; aralık dışındaki değer ilk şablona
  /// düşer (kolon varsayılanı `0`).
  static StoryCardTemplate fromIndex(int index) {
    return index >= 0 && index < StoryCardTemplate.values.length
        ? StoryCardTemplate.values[index]
        : StoryCardTemplate.nightTorch;
  }
}

/// Kartın dört metin alanı (SPEC.md Ekran 05 binding haritası:
/// `cardTag` / `cardBig` / `cardLine1` / `cardLine2`) ve paylaşım metninin
/// başlığı.
class StoryCardText {
  const StoryCardText({
    required this.tag,
    required this.big,
    required this.line1,
    required this.line2,
    required this.shareHeadline,
  });

  final String tag;
  final String big;
  final String line1;

  /// Boş olabilir (aktif sınav yokken) — kart bu satırı hiç çizmez.
  final String line2;

  /// Paylaşım metninin ilk cümlesi — karttaki satırlardan **ayrı** tutuluyor.
  /// `line1` her şablonda tam cümle değil (`MİNİMAL`'de "gün kaldı.",
  /// `SERİ`'de "gün üst üste odaklandım." — sayı `big` alanında duruyor), o
  /// yüzden paylaşımda `big` ile `line1`'i birleştirmek yerine cümle burada,
  /// girdilerin hepsinin elde olduğu yerde bir kez kuruluyor.
  final String shareHeadline;
}

/// Kart metinlerini üretir. Saf fonksiyon: tarih biçimlendirmesi (`intl`)
/// çağıranda kalıyor, buraya hazır metin olarak geliyor — Ekran 02 de aynı
/// kalıbı kullanıyor. Metin kalıpları [l10n] üzerinden ARB'den okunuyor;
/// fonksiyon yine saf, çünkü [l10n] de bir girdi.
StoryCardText buildStoryCardText({
  required AppLocalizations l10n,
  required StoryCardTemplate template,
  required int todayFocusSeconds,
  required int streak,
  required String? examName,
  required String? examDateText,
  required int? daysRemaining,
}) {
  switch (template) {
    case StoryCardTemplate.nightTorch:
      final FocusDurationParts parts = formatFocusDuration(todayFocusSeconds);
      final String todayLine = l10n.storyCardTodayLine(_spelledDuration(l10n, parts));
      return StoryCardText(
        tag: l10n.storyCardTodayTag,
        big: '${parts.hours}:${parts.minutes.toString().padLeft(2, '0')}',
        line1: todayLine,
        // Aktif sınav yoksa geri sayım cümlesi kurulamaz; uydurma bir hedef
        // yazmak yerine satır boş kalıyor.
        line2: examName == null || daysRemaining == null
            ? ''
            : l10n.storyCardExamLine(examName, dativeSuffix(examName), daysRemaining),
        // Bu şablonda `line1` zaten tam cümle.
        shareHeadline: todayLine,
      );

    case StoryCardTemplate.minimal:
      return StoryCardText(
        tag: examName?.toUpperCase() ?? l10n.storyCardTargetTag,
        big: daysRemaining?.toString() ?? l10n.commonEmptyValue,
        line1: daysRemaining == null ? l10n.storyCardNoTargetLine : l10n.storyCardDaysLeftLine,
        line2: examDateText ?? '',
        // Kartta sayı ve "gün kaldı." ayrı duruyor; paylaşımda Ekran 02'nin
        // geri sayım cümlesi kullanılıyor. Hedef yoksa sayı da yok — o zaman
        // sınavdan hiç söz etmeyen nötr bir cümle kalıyor.
        shareHeadline: examName == null || daysRemaining == null
            ? l10n.storyCardShareNoTargetHeadline
            : l10n.storyCardExamLine(examName, dativeSuffix(examName), daysRemaining),
      );

    case StoryCardTemplate.streak:
      return StoryCardText(
        tag: l10n.storyCardStreakTag,
        big: '$streak',
        line1: l10n.storyCardStreakLine,
        line2: streak == 0
            ? l10n.storyCardStreakZeroLine
            : l10n.storyCardStreakNextLine(streak + 1, dativeSuffix('${streak + 1}')),
        shareHeadline: streak == 0
            ? l10n.storyCardShareNoTargetHeadline
            : l10n.storyCardShareStreakHeadline(streak),
      );
  }
}

/// Sistem paylaşım sayfasına giden metin (SPEC.md Ekran 05). Görselin yanına
/// mağaza adresini de koyuyor: Instagram gibi metni yok sayan uygulamalarda
/// link kaybolur, o durumda kartın kendi alt imzası devreye giriyor.
String buildStoryCardShareText(AppLocalizations l10n, StoryCardText text) {
  return l10n.storyCardShareMessage(text.shareHeadline, kPlayStoreUrl);
}

/// `2 saat 15 dakika` / `45 dakika` / `3 saat`.
String _spelledDuration(AppLocalizations l10n, FocusDurationParts parts) {
  if (parts.hours == 0) return l10n.durationMinutes(parts.minutes);
  if (parts.hours > 0 && parts.minutes == 0) return l10n.durationHours(parts.hours);
  return l10n.durationHoursMinutes(parts.hours, parts.minutes);
}
