import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
import 'focus_stats.dart';

/// Haftalık kapanışın gönderildiği gün (İstanbul duvar saati). Hafta biterken
/// bakılan bir özet olduğu için pazar: pazartesi sabahı gelen bir rapor geçmiş
/// haftayı kapatmıyor, yeni haftanın üstüne biniyor.
const int kWeeklySummaryWeekday = DateTime.sunday;

/// Gönderim saati (İstanbul duvar saati). "Seri riski" hatırlatması 21:00'de
/// gönderiliyor (`NotificationService.rescheduleStreakRiskReminder`); kapanış
/// özeti bir saat önce geliyor ki iki bildirim aynı dakikaya düşmesin ve özeti
/// gördükten sonra o akşam hâlâ bir pomodoro vakti kalsın.
const int kWeeklySummaryHour = 20;

/// Haftalık kapanışın iki sayısı: biten pencere ve ondan hemen önceki pencere.
/// Yüzde değil **fark** tutuluyor — "geçen haftadan +40 dk" cümlesi "%18
/// arttın"dan hem daha okunur hem de küçük tabanlarda yanıltmıyor (2 saatten
/// 3 saate çıkmayı "%50 artış" diye anlatmak ölçen bir ton kuruyor).
class WeeklySummary {
  const WeeklySummary({required this.seconds, required this.previousSeconds});

  static const WeeklySummary empty = WeeklySummary(seconds: 0, previousSeconds: 0);

  /// Pencerenin tamamlanmış odak süresi (saniye).
  final int seconds;

  /// Ondan önceki aynı uzunlukta pencerenin tamamlanmış odak süresi.
  final int previousSeconds;

  /// Artıysa pozitif, azaldıysa negatif.
  int get deltaSeconds => seconds - previousSeconds;

  /// Önceki pencerede hiç odak yoksa karşılaştırma cümlesi kurulmuyor: ilk
  /// haftasındaki kullanıcıya kendi sıfırıyla kıyas sunmak "eşlik eden" tonu
  /// "ölçen" tona çevirirdi. O durumda yalnızca bu haftanın toplamı gösterilir.
  bool get hasComparison => previousSeconds > 0;

  /// İki pencere de boşsa bildirim gönderilmez, kart da çizilmez — söyleyecek
  /// bir şey yokken hatırlatma yapmak uygulamayı "bir görev daha" hâline
  /// getirirdi.
  bool get isEmpty => seconds == 0 && previousSeconds == 0;

  /// Riverpod bu değeri `==` ile karşılaştırıp gereksiz yeniden çizimi eliyor
  /// (`StreakStatus` ile aynı gerekçe).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeeklySummary && other.seconds == seconds && other.previousSeconds == previousSeconds;

  @override
  int get hashCode => Object.hash(seconds, previousSeconds);

  @override
  String toString() => 'WeeklySummary(seconds: $seconds, previousSeconds: $previousSeconds)';
}

/// Saf hesaplayıcı — IO yok. Pencere, [weekEndDayKey] ile **biten**
/// [kStatsWeekLength] uygulama günü; karşılaştırma penceresi ondan hemen
/// önceki aynı uzunlukta blok. [weekEndDayKey] bir [appDayKey] çıktısı olmak
/// zorunda.
///
/// Neden takvim haftası (Pzt–Paz) değil: aynı sayı hem pazar bildiriminde hem
/// de Ekran 06'nın her gün duran kartında kullanılıyor. Yarım kalmış bir
/// takvim haftasını tam bir haftayla kıyaslamak her pazartesi "geçen haftadan
/// −5 saat" yazardı. Kayan yedi gün iki yüzeyde de aynı cümleyi kuruyor ve
/// `FocusStats.lastWeek` ile aynı pencereyi paylaşıyor — pazar akşamı zaten
/// takvim haftasına denk geliyor.
WeeklySummary calculateWeeklySummary({
  required List<PomodoroSession> sessions,
  required DateTime weekEndDayKey,
}) {
  final DateTime windowStart = weekEndDayKey.subtract(const Duration(days: kStatsWeekLength - 1));
  final DateTime previousStart = windowStart.subtract(const Duration(days: kStatsWeekLength));

  int seconds = 0;
  int previousSeconds = 0;
  for (final PomodoroSession session in sessions) {
    if (!session.completed || session.type != SessionType.focus) continue;
    final DateTime day = appDayKey(session.startedAt);
    // Pencerenin **sonrasındaki** günler dışarıda: özet ileri bir pazar için
    // önceden kurulurken (bkz. [nextWeeklySummaryUtc]) o günlerde henüz seans
    // yok, ama sayının tanımı yine de pencereye bağlı kalmalı.
    if (day.isAfter(weekEndDayKey)) continue;
    if (!day.isBefore(windowStart)) {
      seconds += session.plannedDurationSec;
    } else if (!day.isBefore(previousStart)) {
      previousSeconds += session.plannedDurationSec;
    }
  }
  return WeeklySummary(seconds: seconds, previousSeconds: previousSeconds);
}

/// [nowUtc]'den **sonraki** ilk pazar [kWeeklySummaryHour]:00 (İstanbul) anı,
/// UTC olarak. Saf fonksiyon: `app_day.dart`'ın sabit UTC+3 varsayımını
/// paylaşıyor (Türkiye 2016'dan beri yaz saati uygulamıyor).
///
/// `timezone` paketi yerine bu hesap kullanılıyor çünkü çağıranın aynı andan
/// **hem** zamanlama anını **hem** de o ana ait pencere gününü
/// ([weeklySummaryWindowEnd]) türetmesi gerekiyor; ikisini iki ayrı zaman
/// altyapısından okumak 04:00 gün sınırının etrafında birbirinden sapardı.
DateTime nextWeeklySummaryUtc(DateTime nowUtc) {
  final DateTime wall = toIstanbulWallClock(nowUtc);
  // `DateTime.sunday` 7, `weekday` 1..7 → pazartesi 6 gün, pazar 0 gün sonra.
  final int daysUntil = (kWeeklySummaryWeekday - wall.weekday) % 7;
  DateTime sendWall =
      DateTime.utc(wall.year, wall.month, wall.day, kWeeklySummaryHour).add(Duration(days: daysUntil));
  // Pazar 20:00 geçtiyse bu hafta kapandı, hedef gelecek pazar.
  if (!sendWall.isAfter(wall)) {
    sendWall = sendWall.add(const Duration(days: 7));
  }
  return sendWall.subtract(const Duration(hours: 3));
}

/// [sendAtUtc] anında gönderilecek özetin pencere sonu (uygulama günü).
/// 20:00 TSİ gün sınırının (04:00) üstünde olduğu için bu, o pazarın kendisi.
DateTime weeklySummaryWindowEnd(DateTime sendAtUtc) => appDayKey(sendAtUtc);
