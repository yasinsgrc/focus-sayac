/// Isı haritalarının **paylaşılan ölçeği**: bir günün dakikasını renk
/// rampasının indeksine çeviren eşikler ve ızgaraların tek hücresi.
///
/// Aylık ızgara (ROADMAP madde 29) ve yuvarlanan 52 haftalık şerit (madde 37)
/// aynı kartta, **tek bir efsanenin** altında duruyor. Tek efsane tek rampa,
/// tek rampa da tek eşik takımı demek: ikinci bir takım aynı günü iki ızgarada
/// iki farklı tonda gösterirdi ve efsane hangisini anlattığını söyleyemezdi.
///
/// Bu yüzden dört sembol `monthly_heatmap.dart`tan buraya çıktı. Alternatif,
/// yıllık hesaplayıcının aylık olandan import etmesiydi — iki pencere arasında
/// olmayan bir bağımlılık uydururdu.
library;

/// Izgaranın dolu ton sayısı — [kHeatmapLevelThresholds] uzunluğuyla aynı
/// olmak zorunda (`monthly_heatmap_test.dart` bunu çiviliyor). `const`
/// kalabilmesi için ayrı yazıldı.
const int kHeatmapLevels = 4;

/// Seviye sınırları, dakika cinsinden ve **dahil**: 1–24 → 1, 25–49 → 2,
/// 50–89 → 3, ≥90 → 4.
///
/// Eşikler **mutlak**, ne ayın ne de yılın en yoğun gününe ölçekleniyor. Bar
/// chart sütunlarını kendi haftasının en yüksek gününe göre ölçekliyor
/// (`WeeklyFocusBarPainter`) ama ızgarada aynı şey yanlış bir şey söylerdi:
/// ayda tek bir 5 dakikalık günü olan kullanıcı o günü en koyu tonda görürdü.
/// Yıllık ölçekte gerekçe daha da güçlü — yılın tek 8 saatlik gününe göre
/// ölçeklenen bir harita, 90 dakikalık normal günlerin hepsini soluk
/// gösterirdi.
///
/// Sınırlar 25 dakikalık varsayılan pomodoronun 1 / 2 / 3+ katları; dakikada
/// sabit oldukları için iki ay — ve ay ile yıl — birbiriyle
/// karşılaştırılabiliyor.
const List<int> kHeatmapLevelThresholds = <int>[1, 25, 50, 90];

/// Bir günün yoğunluk seviyesi (0 = hiç odak yok).
int heatmapLevel(int minutes) {
  int level = 0;
  for (final int threshold in kHeatmapLevelThresholds) {
    if (minutes >= threshold) level++;
  }
  return level;
}

/// Izgaranın tek bir hücresi. Aylık takvim düzeni de yıllık şerit de aynı
/// hücreyi kullanıyor: ikisinin farkı yerleşim, veri değil.
class HeatmapDay {
  const HeatmapDay({
    required this.dayKey,
    required this.minutes,
    required this.level,
    required this.isFuture,
  });

  /// `appDayKey` çıktısı — 04:00 TSİ sınırlı uygulama günü.
  final DateTime dayKey;

  /// O gün **tamamlanmış** odak dakikası.
  final int minutes;

  /// 0..[kHeatmapLevels]; renk rampasının indeksi.
  final int level;

  /// Pencerenin henüz gelmemiş günü. Gelecek günler dolgusuz çiziliyor: ayın
  /// 2'sinde 28 boş kutu göstermek, yaşanmamış günleri kaçırılmış gün gibi
  /// okuturdu. Şeritte de aynısı — içinde bulunulan haftanın kalanı boş.
  final bool isFuture;
}
