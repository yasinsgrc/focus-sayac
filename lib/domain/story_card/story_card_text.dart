import '../text/turkish_suffix.dart';
import '../time/duration_formatter.dart';

/// Ekran 05'in üç şablonu (prototip v2 satır 506-512). Üçü de v1'de
/// **ücretsiz** (SPEC.md Ekran 05); sıra `AppSettings.selectedTemplateIndex`
/// kolonuna yazılan indeksle aynı olmak zorunda.
enum StoryCardTemplate {
  nightTorch('GECE MEŞALESİ'),
  minimal('MİNİMAL'),
  streak('SERİ');

  const StoryCardTemplate(this.label);

  /// Şablon seçici düğmesinin metni.
  final String label;

  /// Kayıtlı indeksi şablona çevirir; aralık dışındaki değer ilk şablona
  /// düşer (kolon varsayılanı `0`).
  static StoryCardTemplate fromIndex(int index) {
    return index >= 0 && index < StoryCardTemplate.values.length
        ? StoryCardTemplate.values[index]
        : StoryCardTemplate.nightTorch;
  }
}

/// Kartın dört metin alanı (SPEC.md Ekran 05 binding haritası:
/// `cardTag` / `cardBig` / `cardLine1` / `cardLine2`).
class StoryCardText {
  const StoryCardText({
    required this.tag,
    required this.big,
    required this.line1,
    required this.line2,
  });

  final String tag;
  final String big;
  final String line1;

  /// Boş olabilir (aktif sınav yokken) — kart bu satırı hiç çizmez.
  final String line2;
}

/// Kart metinlerini üretir. Saf fonksiyon: tarih biçimlendirmesi (`intl`)
/// çağıranda kalıyor, buraya hazır metin olarak geliyor — Ekran 02 de aynı
/// kalıbı kullanıyor.
StoryCardText buildStoryCardText({
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
      return StoryCardText(
        tag: 'BUGÜNÜN ODAĞI',
        big: '${parts.hours}:${parts.minutes.toString().padLeft(2, '0')}',
        line1: 'Bugün ${_spelledDuration(parts)} odaklandım.',
        // Aktif sınav yoksa geri sayım cümlesi kurulamaz; uydurma bir hedef
        // yazmak yerine satır boş kalıyor.
        line2: examName == null || daysRemaining == null
            ? ''
            : '$examName${dativeSuffix(examName)} $daysRemaining gün kaldı',
      );

    case StoryCardTemplate.minimal:
      return StoryCardText(
        tag: examName?.toUpperCase() ?? 'HEDEF',
        big: daysRemaining?.toString() ?? '—',
        line1: daysRemaining == null ? 'hedef seçilmedi.' : 'gün kaldı.',
        line2: examDateText ?? '',
      );

    case StoryCardTemplate.streak:
      return StoryCardText(
        tag: 'SERİ',
        big: '$streak',
        line1: 'gün üst üste odaklandım.',
        line2: streak == 0
            ? 'Bugün bir pomodoro seriyi başlatır.'
            : 'Yarın ${streak + 1}${dativeSuffix('${streak + 1}')} çıkıyor',
      );
  }
}

/// `2 saat 15 dakika` / `45 dakika` / `3 saat`.
String _spelledDuration(FocusDurationParts parts) {
  if (parts.hours == 0) return '${parts.minutes} dakika';
  if (parts.minutes == 0) return '${parts.hours} saat';
  return '${parts.hours} saat ${parts.minutes} dakika';
}
