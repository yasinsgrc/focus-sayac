import '../../core/time/app_day.dart';

/// Dönüş yolunun eşiği: bu kadar uygulama günü hiç odaklanılmadıysa kullanıcı
/// "dönmüş" sayılır (ROADMAP madde 26).
const int kComebackAbsentDays = 3;

/// Dönüş çağrısının kapsadığı en az seans sayısı.
/// `AppReviewService.minCompletedFocusSessions` ile **aynı sayı ve aynı
/// gerekçe**: uygulamayı bir kez deneyip bırakan kullanıcıya "geri dön" demek,
/// ürünün kaçındığı winback tonuna kayar.
const int kComebackMinCompletedFocusSessions = 3;

/// Bildirimin saati: 21:00 TSİ = 18:00 UTC (Türkiye 2016'dan beri sabit UTC+3
/// — `app_day.dart` ile aynı varsayım). Seri riski hatırlatmasıyla aynı saat;
/// kullanıcı için tek bir "akşam hatırlatma saati" var.
const int kComebackReminderHourUtc = 18;

/// Yokluğun o anki hâli. Şerit ve bildirim **aynı** nesneden besleniyor, yani
/// ekranda görünenle bildirimin vaadi ayrışamaz.
class ComebackStatus {
  const ComebackStatus({
    required this.absentDays,
    required this.welcomeDue,
    required this.reminderAtUtc,
  });

  static const ComebackStatus none =
      ComebackStatus(absentDays: 0, welcomeDue: false, reminderAtUtc: null);

  /// Son tamamlanmış odak seansından bu yana geçen uygulama günü sayısı.
  final int absentDays;

  /// Ekran 02'nin karşılama şeridi görünsün mü.
  final bool welcomeDue;

  /// Dönüş bildiriminin kurulacağı an; `null` "kurma" demektir — ya eşik
  /// dolmamıştır ya da o günün penceresi geçmiştir.
  final DateTime? reminderAtUtc;

  /// Riverpod bu değeri `==` ile karşılaştırıp gereksiz yeniden çizimi eliyor
  /// (`StreakStatus` ile aynı gerekçe).
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComebackStatus &&
          other.absentDays == absentDays &&
          other.welcomeDue == welcomeDue &&
          other.reminderAtUtc == reminderAtUtc;

  @override
  int get hashCode => Object.hash(absentDays, welcomeDue, reminderAtUtc);

  @override
  String toString() => 'ComebackStatus(absentDays: $absentDays, '
      'welcomeDue: $welcomeDue, reminderAtUtc: $reminderAtUtc)';
}

/// Dönüş hesaplayıcı — saf fonksiyon, IO yok; `streak_calculator.dart` ile aynı
/// imza ve aynı felsefe: saklanan bayrak yok, aynı geçmiş her zaman aynı
/// sonucu verir.
///
/// Bildirim penceresi **tek gün**: hedef an son seans gününün üç gün
/// sonrasının akşamıdır, kaçırılırsa ileriye taşınmaz. Yokluk uzadıkça bildirim
/// biriktiren bir winback dizisi bilinçli olarak kapsam dışı (tasarım belgesi,
/// "Kapsam dışı").
ComebackStatus calculateComebackStatus({
  required List<DateTime> completedFocusStartedAtUtc,
  required DateTime nowUtc,
}) {
  if (completedFocusStartedAtUtc.length < kComebackMinCompletedFocusSessions) {
    return ComebackStatus.none;
  }

  // Sonuncusu listenin sırasına güvenilmeden bulunuyor: DAO'nun sıralaması bu
  // hesabın sözleşmesi değil.
  DateTime last = completedFocusStartedAtUtc.first;
  for (final DateTime startedAt in completedFocusStartedAtUtc) {
    if (startedAt.isAfter(last)) last = startedAt;
  }

  final DateTime lastDay = appDayKey(last);
  final int absentDays = currentAppDayKey(nowUtc).difference(lastDay).inDays;
  final DateTime reminderAtUtc = lastDay
      .add(const Duration(days: kComebackAbsentDays))
      .add(const Duration(hours: kComebackReminderHourUtc));

  return ComebackStatus(
    absentDays: absentDays,
    welcomeDue: absentDays >= kComebackAbsentDays,
    reminderAtUtc: reminderAtUtc.isAfter(nowUtc) ? reminderAtUtc : null,
  );
}
