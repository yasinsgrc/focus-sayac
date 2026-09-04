import 'dart:ui' show Color;

/// Ana ekran widget'larının tek veri sözleşmesi. Saf model — IO yok, platform
/// yok; `HomeWidgetService` bunu paylaşılan `SharedPreferences`e yazar,
/// Kotlin tarafı (`FocusWidgetSnapshot.kt`) aynı anahtarlarla okur.
///
/// **Kalan gün burada yok, bilinçli olarak.** Yazılan şey hedef zaman
/// damgasıdır; gün/saat/oran her çizimde Kotlin tarafında yeniden hesaplanır.
/// Aksi hâlde uygulama birkaç gün açılmadığında widget bayat bir sayı
/// gösterirdi.
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.examName,
    required this.examSubtitle,
    required this.targetUtc,
    required this.accentColor,
    required this.streak,
    required this.todayMinutes,
    required this.weeklyMinutes,
    required this.sessionActive,
    required this.updatedAtUtc,
  }) : assert(weeklyMinutes.length == weeklyLength, 'weeklyMinutes 7 elemanlı olmalı');

  /// Aktif sınav yokken yazılan anlık görüntü. Widget'lar bu durumda
  /// "sınav seç" gövdesini çizer — boş bir kutu değil.
  factory HomeWidgetSnapshot.noExam({
    required int streak,
    required int todayMinutes,
    required List<int> weeklyMinutes,
    required bool sessionActive,
    required DateTime updatedAtUtc,
  }) {
    return HomeWidgetSnapshot(
      examName: null,
      examSubtitle: null,
      targetUtc: null,
      accentColor: null,
      streak: streak,
      todayMinutes: todayMinutes,
      weeklyMinutes: weeklyMinutes,
      sessionActive: sessionActive,
      updatedAtUtc: updatedAtUtc,
    );
  }

  /// `FocusStats.lastWeek` ile aynı uzunluk (`kStatsWeekLength`). Sabit burada
  /// tekrar tanımlanıyor çünkü bu model `domain/stats`e bağımlı değil —
  /// bağımlılık tek yönlü kalsın diye (çağıran listeyi hazır verir).
  static const int weeklyLength = 7;

  /// Aktif sınavın adı; sınav yoksa `null`.
  final String? examName;
  final String? examSubtitle;

  /// Sınav anı (UTC); sınav yoksa `null`. Widget'ın tek zaman kaynağı.
  final DateTime? targetUtc;

  /// `Exam.accentRole`'ün çözülmüş rengi; sınav yoksa `null`.
  final Color? accentColor;

  final int streak;

  /// Bugün (04:00 TSİ sınırlı uygulama günü) tamamlanan odak dakikası.
  final int todayMinutes;

  /// Eskiden yeniye 7 gün; son eleman bugün. `FocusStats.lastWeek` ile aynı sıra.
  final List<int> weeklyMinutes;

  /// Odak veya mola seansı şu an çalışıyor mu — Hızlı Odak widget'ının
  /// butonu buna göre "başlat" ya da "devam et" olur.
  final bool sessionActive;

  final DateTime updatedAtUtc;

  bool get hasActiveExam => targetUtc != null;

  /// `HomeWidget.saveWidgetData` yalnızca `String`/`int`/`double`/`bool`
  /// kabul ediyor; haftalık liste virgülle birleştirilir.
  Map<String, Object> toPayload() {
    return <String, Object>{
      keyHasActiveExam: hasActiveExam,
      keyExamName: examName ?? '',
      keyExamSubtitle: examSubtitle ?? '',
      keyTargetUtcMillis: targetUtc?.millisecondsSinceEpoch ?? 0,
      keyAccentHex: accentColor == null ? '' : toHex(accentColor!),
      keyStreak: streak,
      keyTodayMinutes: todayMinutes,
      keyWeeklyMinutes: weeklyMinutes.join(','),
      keySessionActive: sessionActive,
      keyUpdatedAtMillis: updatedAtUtc.millisecondsSinceEpoch,
    };
  }

  /// `#AARRGGBB` — Kotlin `Color.parseColor` bu biçimi doğrudan okur.
  /// Palet senkron testi de aynı biçimi üretip `focus_colors.xml` ile
  /// karşılaştırdığı için `public`.
  static String toHex(Color color) {
    final int argb = (_channel(color.a) << 24) |
        (_channel(color.r) << 16) |
        (_channel(color.g) << 8) |
        _channel(color.b);
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static int _channel(double value) => (value * 255).round().clamp(0, 255);

  static const String keyHasActiveExam = 'hasActiveExam';
  static const String keyExamName = 'examName';
  static const String keyExamSubtitle = 'examSubtitle';
  static const String keyTargetUtcMillis = 'targetUtcMillis';
  static const String keyAccentHex = 'accentHex';
  static const String keyStreak = 'streak';
  static const String keyTodayMinutes = 'todayMinutes';
  static const String keyWeeklyMinutes = 'weeklyMinutes';
  static const String keySessionActive = 'sessionActive';
  static const String keyUpdatedAtMillis = 'updatedAtMillis';

  /// Payload'ın tüm anahtarları — servis testinin eksik anahtar yakalaması için.
  static const List<String> payloadKeys = <String>[
    keyHasActiveExam,
    keyExamName,
    keyExamSubtitle,
    keyTargetUtcMillis,
    keyAccentHex,
    keyStreak,
    keyTodayMinutes,
    keyWeeklyMinutes,
    keySessionActive,
    keyUpdatedAtMillis,
  ];
}
