import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
import 'focus_stats.dart';

/// Dağılımın tek satırı. [key] `null` ise dersi belirtilmemiş seansların
/// toplamı — göçten gelen kullanıcının geçmişi ve ders seçmeden başlatılan
/// seanslar burada.
class SubjectSlice {
  const SubjectSlice({
    required this.key,
    required this.seconds,
    required this.previousSeconds,
    required this.ratio,
  });

  final String? key;

  /// Pencerenin tamamlanmış odak süresi (saniye).
  final int seconds;

  /// Bir önceki aynı uzunlukta pencerenin süresi — denge satırının kaynağı.
  final int previousSeconds;

  /// [seconds] / pencere toplamı; çubuğun dolgu oranı (0..1).
  final double ratio;
}

/// Denge satırının bir ucu: bir dersin haftadan haftaya kayması.
class SubjectShift {
  const SubjectShift({required this.key, required this.deltaSeconds});

  final String key;

  /// Artıysa pozitif, azaldıysa negatif.
  final int deltaSeconds;
}

/// "En çok ihmal ettiğin ders" satırı.
class SubjectNeglect {
  const SubjectNeglect({required this.key, required this.daysSince});

  final String key;

  /// Dersin en son çalışıldığı uygulama gününden bugüne geçen gün sayısı.
  /// Pencere içinde çalışılmış bir ders aday olmadığı için her zaman
  /// [kStatsWeekLength] ya da daha büyük.
  final int daysSince;
}

/// Ekran 06'nın ders dağılımı (ROADMAP madde 30).
class SubjectBreakdown {
  const SubjectBreakdown({
    required this.slices,
    required this.totalSeconds,
    required this.previousTotalSeconds,
    required this.biggestRise,
    required this.biggestFall,
    required this.neglect,
  });

  static const SubjectBreakdown empty = SubjectBreakdown(
    slices: <SubjectSlice>[],
    totalSeconds: 0,
    previousTotalSeconds: 0,
    biggestRise: null,
    biggestFall: null,
    neglect: null,
  );

  /// Süreye göre azalan; yalnızca pencerede süresi olan dersler. Belirtilmemiş
  /// dilim eşitlikte en sona düşer — bir ders değil.
  final List<SubjectSlice> slices;

  final int totalSeconds;
  final int previousTotalSeconds;

  /// Geçen haftaya göre en çok artan / azalan ders. Önceki pencere tamamen
  /// boşken ikisi de `null`: ilk haftasındaki kullanıcıya kendi sıfırıyla
  /// kıyas sunmak `WeeklySummary.hasComparison`ın reddettiği şey.
  final SubjectShift? biggestRise;
  final SubjectShift? biggestFall;

  final SubjectNeglect? neglect;

  /// Pencere boşken kart hiç çizilmiyor — `WeeklySummary.isEmpty` ile aynı
  /// gerekçe: söyleyecek bir şey yokken "0 dakika" yazmak eşlik eden tondan
  /// ölçen tona geçiş olurdu.
  bool get isEmpty => totalSeconds == 0;
}

/// Saf hesaplayıcı — IO yok, `nowUtc` dışarıdan verilir.
///
/// Pencere, bugünle **biten** [kStatsWeekLength] uygulama günü;
/// `calculateWeeklySummary` ile birebir aynı tanım, karşılaştırma penceresi de
/// ondan hemen önceki blok. Ekran 06 zaten bu pencereyi konuşuyor ("BU HAFTA"
/// kartı, bar chart); dağılıma ayrı bir aylık pencere açmak tek ekranda iki
/// farklı "şimdi" tanımı demekti.
///
/// [catalog] aktif sınavın ders listesi (`subjectsForExam`) — yalnızca ihmal
/// adaylarını belirler. Dağılım katalogla sınırlı değil: sınav değiştiren
/// kullanıcının bu haftaki Kimya seansı, Kimya artık katalogda olmasa bile
/// toplamda durmak zorunda.
SubjectBreakdown calculateSubjectBreakdown({
  required List<PomodoroSession> sessions,
  required List<String> catalog,
  required DateTime nowUtc,
}) {
  final DateTime today = currentAppDayKey(nowUtc);
  final DateTime windowStart = today.subtract(const Duration(days: kStatsWeekLength - 1));
  final DateTime previousStart = windowStart.subtract(const Duration(days: kStatsWeekLength));

  final Map<String?, int> seconds = <String?, int>{};
  final Map<String?, int> previousSeconds = <String?, int>{};
  // Dersin **en son** çalışıldığı uygulama günü — ihmal satırının kaynağı.
  // Pencereyle sınırlı değil: "12 gündür dokunmadın" cümlesi ancak tüm geçmişe
  // bakılarak kurulabiliyor.
  final Map<String, DateTime> lastDay = <String, DateTime>{};

  for (final PomodoroSession session in sessions) {
    if (!session.completed || session.type != SessionType.focus) continue;
    final DateTime day = appDayKey(session.startedAt);
    if (day.isAfter(today)) continue;
    final String? key = session.subjectKey;

    if (key != null) {
      final DateTime? previous = lastDay[key];
      if (previous == null || day.isAfter(previous)) lastDay[key] = day;
    }

    if (!day.isBefore(windowStart)) {
      seconds[key] = (seconds[key] ?? 0) + session.plannedDurationSec;
    } else if (!day.isBefore(previousStart)) {
      previousSeconds[key] = (previousSeconds[key] ?? 0) + session.plannedDurationSec;
    }
  }

  final int totalSeconds = seconds.values.fold<int>(0, (int sum, int s) => sum + s);
  final int previousTotalSeconds =
      previousSeconds.values.fold<int>(0, (int sum, int s) => sum + s);

  final List<SubjectSlice> slices = <SubjectSlice>[
    for (final MapEntry<String?, int> entry in seconds.entries)
      SubjectSlice(
        key: entry.key,
        seconds: entry.value,
        previousSeconds: previousSeconds[entry.key] ?? 0,
        ratio: totalSeconds == 0 ? 0 : entry.value / totalSeconds,
      ),
  ]..sort((SubjectSlice a, SubjectSlice b) {
      final int bySeconds = b.seconds.compareTo(a.seconds);
      if (bySeconds != 0) return bySeconds;
      // Eşitlikte belirtilmemiş dilim sona, gerisi katalog sırasına. Sıra
      // deterministik olmak zorunda: aynı veriyle iki kez çizilen kart aynı
      // görünmeli.
      if (a.key == null) return 1;
      if (b.key == null) return -1;
      return _catalogIndex(catalog, a.key!).compareTo(_catalogIndex(catalog, b.key!));
    });

  return SubjectBreakdown(
    slices: List<SubjectSlice>.unmodifiable(slices),
    totalSeconds: totalSeconds,
    previousTotalSeconds: previousTotalSeconds,
    biggestRise: previousTotalSeconds == 0
        ? null
        : _extremeShift(seconds, previousSeconds, rising: true),
    biggestFall: previousTotalSeconds == 0
        ? null
        : _extremeShift(seconds, previousSeconds, rising: false),
    neglect: _neglect(catalog: catalog, seconds: seconds, lastDay: lastDay, today: today),
  );
}

/// Katalogda olmayan ders (sınav değişmiş) eşitlikte sona düşsün diye katalog
/// uzunluğunu döner.
int _catalogIndex(List<String> catalog, String key) {
  final int index = catalog.indexOf(key);
  return index < 0 ? catalog.length : index;
}

/// İki pencere arasındaki en büyük artış ya da azalış.
///
/// Belirtilmemiş dilim (`null`) **aday değil**: "Belirtilmemiş +40 dk" cümlesi
/// kullanıcıya bir şey söylemiyor. Sıfır fark da aday değil — denge satırı
/// yalnızca gerçekten kaymış bir ders için kuruluyor.
SubjectShift? _extremeShift(
  Map<String?, int> seconds,
  Map<String?, int> previousSeconds, {
  required bool rising,
}) {
  SubjectShift? best;
  for (final String key in <String?>{...seconds.keys, ...previousSeconds.keys}.whereType<String>()) {
    final int delta = (seconds[key] ?? 0) - (previousSeconds[key] ?? 0);
    if (rising ? delta <= 0 : delta >= 0) continue;
    if (best == null || (rising ? delta > best.deltaSeconds : delta < best.deltaSeconds)) {
      best = SubjectShift(key: key, deltaSeconds: delta);
    }
  }
  return best;
}

/// Katalogdaki dersler içinde, **daha önce çalışılmış** ama pencerede hiç
/// çalışılmamış olanlardan en uzun süredir dokunulmayanı.
///
/// Hiç çalışılmamış ders aday değil: YKS katalogunda 11 ders var ve kullanıcı
/// haftada 3-4'üne dokunuyor; "hiç çalışmadıkların" listesi her hafta aynı yedi
/// dersi sayan bir suçlama olurdu. Geçmişi olan bir ders sustuğunda ise
/// söylenen şey hem gerçek hem eyleme çevrilebilir.
SubjectNeglect? _neglect({
  required List<String> catalog,
  required Map<String?, int> seconds,
  required Map<String, DateTime> lastDay,
  required DateTime today,
}) {
  SubjectNeglect? worst;
  for (final String key in catalog) {
    if ((seconds[key] ?? 0) > 0) continue;
    final DateTime? last = lastDay[key];
    if (last == null) continue;
    final int daysSince = today.difference(last).inDays;
    if (worst == null || daysSince > worst.daysSince) {
      worst = SubjectNeglect(key: key, daysSince: daysSince);
    }
  }
  return worst;
}
