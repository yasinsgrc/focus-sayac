/// "Uygulama günü" sınırı — SPEC.md §5.3: gün 04:00 TSİ'de kapanır.
/// Türkiye 2016'dan beri yaz saati uygulamıyor (sabit UTC+3), bu yüzden
/// `timezone` paketinin tam TZDateTime altyapısı yerine sabit ofsetli bu
/// yardımcı yeterli ve daha ucuz; `timezone` paketi Faz 6'da bildirim
/// zamanlamasında kullanılacak.
library;

/// 04:00 TSİ = 01:00 UTC. Bir UTC zaman damgasının ait olduğu uygulama
/// gününü, o günün 01:00 UTC başlangıcını temsil eden UTC tarihiyle
/// (saat/dakika/saniye sıfırlanmış) döndürür.
DateTime appDayKey(DateTime timestampUtc) {
  final DateTime utc = timestampUtc.toUtc();
  final DateTime shifted = utc.subtract(const Duration(hours: 1));
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}

/// Bugünün (çağrı anındaki `nowUtc`'ye göre) uygulama günü anahtarı.
DateTime currentAppDayKey(DateTime nowUtc) => appDayKey(nowUtc);

/// Bir UTC zaman damgasını TSİ duvar saatine çevirir (sabit UTC+3).
/// Yalnızca tarih/saat **gösterimi** için — hesaplamalar UTC üzerinde kalır
/// (SPEC.md §5.1 "Tüm hesap UTC, gösterim Europe/Istanbul").
DateTime toIstanbulWallClock(DateTime utc) => utc.toUtc().add(const Duration(hours: 3));
