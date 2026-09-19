import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/stats/monthly_heatmap.dart';
import '../../../domain/stats/rolling_year_heatmap.dart';
import '../../../domain/time/duration_formatter.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'weekly_focus_bar_painter.dart';

/// Izgaranın [dayOfMonth]. gün hücresi — testler bir günün tonuna bununla
/// bakıyor.
Key heatmapDayCellKey(int dayOfMonth) => ValueKey<String>('heatmap-day-$dayOfMonth');

/// Ay gezinme okları (ROADMAP madde 35). Testler dokunuşu bunlarla yapıyor;
/// ekran okuyucu etiketi ayrı (`statsHeatmapPreviousMonth` / `…NextMonth`).
const Key heatmapPrevMonthKey = ValueKey<String>('heatmap-prev-month');
const Key heatmapNextMonthKey = ValueKey<String>('heatmap-next-month');

/// Yuvarlanan yıl şeridinin kabı (ROADMAP madde 37). Testler çizilen hücreleri
/// bunun altında sayıyor — aylık ızgaranın hücreleriyle karışmasın diye.
const Key heatmapYearStripKey = ValueKey<String>('heatmap-year-strip');

/// Şeridin [index]. günü (`RollingYearHeatmap.days` sırası: eskiden yeniye).
Key heatmapYearCellKey(int index) => ValueKey<String>('heatmap-year-$index');

/// Yoğunluk rampası. `sky` tanımı gereği "veri, istatistik"
/// (`app_colors.dart`) ve bar chart da bu rengi kullanıyor: iki grafik aynı
/// dili konuşuyor, yeni tema alanı açılmıyor.
///
/// [level] 0 iken çağrılmıyor; boş günün rengi geçmiş/gelecek ayrımına bağlı.
Color heatmapLevelColor(AppColors colors, int level) =>
    Color.lerp(colors.skyDeep, colors.sky, level / kHeatmapLevels)!;

/// Ekran 06'nın aylık ısı haritası kartı (ROADMAP madde 29).
///
/// Bar chart son yedi günün dakikalarını veriyor ama kullanıcının **ritmini**
/// gösteren bir yüzey yoktu: hangi günler çalışıyor, boşluk nerede açılıyor.
/// Takvim düzeni bu soruyu doğrudan cevaplıyor — sütunlar haftanın günleri,
/// satırlar haftalar.
///
/// Madde 37'den beri kart **iki pencere** taşıyor: üstte gezilebilir aylık
/// takvim, altında yuvarlanan 52 haftalık şerit. Izgara "bu ay hangi günler"i,
/// şerit ölçeği söylüyor. İkisi tek efsaneyi ve tek eşik takımını paylaşıyor
/// (`heatmap_scale.dart`) — aynı ton iki pencerede aynı şeyi anlatıyor.
///
/// `CustomPainter` değil widget ağacı: hücreler statik ve bir `RepaintBoundary`
/// içinde, karşılığında her hücre testten görünüyor. Madde 31 zaten bir
/// painter'ın doğrulanamamasından açık; ikincisi eklenmedi.
class MonthlyHeatmapCard extends StatelessWidget {
  const MonthlyHeatmapCard({
    required this.heatmap,
    required this.year,
    super.key,
    this.selectedDay,
    this.onDayTap,
    this.onMonthStep,
  });

  final MonthlyHeatmap heatmap;

  /// Aylık ızgaranın altındaki yuvarlanan 52 haftalık şerit (ROADMAP madde 37).
  ///
  /// Zorunlu, opsiyonel değil: üretimde her zaman verilecek bir alanın null
  /// hâli yalnızca testlerin yaşadığı bir kod yolu olurdu. Kart yine **saf** —
  /// bu da dışarıdan geliyor, madde 29'un "Riverpod kurmadan çizilebilen kart"
  /// kalıbı bozulmuyor.
  ///
  /// Ay gezinirken **değişmiyor**: pencere sabit, `_HeatmapSection`ın offset'i
  /// yalnızca [heatmap]i etkiliyor.
  final RollingYearHeatmap year;

  /// Seçili günün anahtarı (`HeatmapDay.dayKey`) ya da seçim yokken null.
  ///
  /// Seçim kartın içinde tutulmuyor: ay değişince sıfırlanması gerekiyor ve
  /// ayı tutan da kartın dışı (`_HeatmapSection`). İki durumu iki yerde
  /// tutmak, birinin diğerinden bayat kalması demekti.
  final DateTime? selectedDay;

  /// Yaşanmış bir hücreye dokunulunca çağrılıyor. Null iken hücreler
  /// dokunmayı hiç karşılamıyor — kartı salt okunur kuran çağıranlar
  /// (testler) jest ağacı da kurmuyor.
  final ValueChanged<HeatmapDay>? onDayTap;

  /// Ay adımı: −1 geri, +1 ileri. Okun etkin olup olmadığına kart karar
  /// veriyor (`hasEarlier` / `hasLater`), adımı uygulayan çağıran.
  final ValueChanged<int>? onMonthStep;

  /// Hücreler arası boşluk ve hücre köşesi.
  static const double _gap = 5;
  static const double _cellRadius = 6;

  /// Haftada yedi gün — ızgaranın sütun sayısı.
  static const int _columns = 7;

  /// Şeridin ölçüleri. 52 sütun 268dp'ye (360dp ekranda 2×26 ekran payı ve
  /// 2×20 kart payı düşülünce kalan) sığmak zorunda: 1dp boşlukla hücre
  /// ~4.2dp kalıyor. Köşe o boyutta 1dp'den fazlasını kaldırmıyor.
  static const double _yearGap = 1;
  static const double _yearCellRadius = 1;

  /// Şeridin satır sayısı — haftanın günleri, pazartesiden pazara.
  static const int _yearRows = 7;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MaterialLocalizations dates = MaterialLocalizations.of(context);
    final HeatmapDay? selected = _selected;

    // `excludeSemantics` kabın tamamına değil, **ızgaraya** uygulanıyor: ay
    // gezinme okları kendi durakları olmak zorunda, yoksa dokunulabilir tek
    // öğeler ekran okuyucuya hiç görünmezdi. Izgara yine tek durak.
    return Semantics(
      container: true,
      label: _semanticsLabel(l10n, dates, selected),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        decoration: BoxDecoration(
          color: colors.surfaceCardSoft,
          borderRadius: BorderRadius.circular(26),
          border: Border.fromBorderSide(BorderSide(color: colors.hairline)),
        ),
        child: RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _header(colors, l10n, dates),
              const SizedBox(height: 14),
              ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _weekdayHeader(colors, l10n),
                    const SizedBox(height: _gap),
                    ..._rows(colors),
                    // Şerit kartın içinde, ızgarayla **hizalı**: tam genişliğe
                    // taşırmak hücreyi 4.9dp'ye çıkarırdı ama iki ızgaranın
                    // aynı kenardan başladığı görsel bağı koparırdı — o bağ,
                    // ikisinin tek efsaneyi paylaşmasının görünür hâli.
                    const SizedBox(height: 14),
                    _divider(colors),
                    const SizedBox(height: 12),
                    _yearHeader(colors, l10n),
                    const SizedBox(height: 8),
                    _yearStrip(colors),
                    const SizedBox(height: 12),
                    _footer(colors, l10n, dates, selected),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bu ayın başlığı ayın adı değil `BU AY`: `DateFormat` ya 12 yeni ARB
  /// anahtarı ya da karta `intl` bağımlılığı demek, oysa kart
  /// `initializeDateFormatting` çağrılmadan da çizilmek zorunda
  /// (`shortDayNames` ile aynı kısıt). Gezilen geçmiş ay adını söylemek
  /// zorunda ve onu `MaterialLocalizations` veriyor — uygulamada zaten bağlı
  /// olan `GlobalMaterialLocalizations`tan, yeni anahtar açmadan.
  ///
  /// Ay adı **büyük harfe çevrilmiyor**: Dart'ın `toUpperCase()`i Unicode
  /// varsayılanını uygular, `"Ekim"` → `"EKIM"` olur ve Türkçe noktalı İ
  /// kaybolur. Kicker'ların büyük harfi ARB metinlerinden geliyordu; bu metin
  /// yerelleştirme kütüphanesinden geliyor.
  ///
  /// Toplam **boş ayda hiç yazılmıyor**: haftalık kapanış kartının gerekçesinin
  /// aynısı — "0 dakika" eşlik eden bir tondan ölçen bir tona geçiş.
  Widget _header(AppColors colors, AppLocalizations l10n, MaterialLocalizations dates) {
    return Row(
      children: <Widget>[
        _monthArrow(
          colors,
          key: heatmapPrevMonthKey,
          icon: PhosphorIconsRegular.caretLeft,
          label: l10n.statsHeatmapPreviousMonth,
          enabled: heatmap.hasEarlier,
          step: -1,
        ),
        // Başlık ve toplam özet cümlesinde zaten söyleniyor; ayrı durak
        // olsalardı ekran okuyucu aynı sayıyı iki kez okurdu.
        ExcludeSemantics(
          child: Text(
            heatmap.isCurrentMonth ? l10n.statsHeatmapLabel : dates.formatMonthYear(heatmap.month),
            style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
          ),
        ),
        _monthArrow(
          colors,
          key: heatmapNextMonthKey,
          icon: PhosphorIconsRegular.caretRight,
          label: l10n.statsHeatmapNextMonth,
          enabled: heatmap.hasLater,
          step: 1,
        ),
        // Toplam esnek: ay adı + iki ok + "12 saat 30 dakika" dar ekranda
        // satırı taşırabilir, taşma yerine kırpılıyor.
        Expanded(
          child: heatmap.isEmpty
              ? const SizedBox.shrink()
              : ExcludeSemantics(
                  child: Text(
                    spellFocusDuration(l10n, heatmap.totalMinutes * 60),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.sky),
                  ),
                ),
        ),
      ],
    );
  }

  /// Gezinme oku. Simge 16px ama dokunma hedefi 44: madde 12'nin kuralı
  /// (48px yuva) kart içinde başlığı iki kat büyütürdü, 44 ise Material'ın
  /// alt sınırında duruyor ve ızgaranın kendi hücreleri (≈46px) ile aynı boy.
  ///
  /// Pasif ok `onTap`i hiç almıyor — dokunulabilir görünen ama hiçbir şey
  /// yapmayan bir hedef, kullanıcıya verinin bittiğini söylemez.
  Widget _monthArrow(
    AppColors colors, {
    required Key key,
    required IconData icon,
    required String label,
    required bool enabled,
    required int step,
  }) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onMonthStep?.call(step) : null,
        child: SizedBox(
          width: 32,
          height: 44,
          child: Icon(icon, size: 16, color: enabled ? colors.neutral500 : colors.neutral700),
        ),
      ),
    );
  }

  /// Seçili günün ızgaradaki karşılığı. Seçim başka bir aya aitse (ay değişip
  /// seçim sıfırlanmadıysa) null dönüyor: kart kendi ayının dışındaki bir gün
  /// için sayı yazmıyor.
  HeatmapDay? get _selected {
    final DateTime? key = selectedDay;
    if (key == null) return null;
    for (final HeatmapDay day in heatmap.days) {
      if (day.dayKey == key) return day;
    }
    return null;
  }

  /// Kap **tek** durak kalıyor (madde 29: hücre hücre gezinme 30 durak
  /// demekti; madde 37'nin 364 hücresiyle 394 olurdu). Üç cümle görsel sırayla
  /// birleşiyor: aylık ızgaranın özeti, şeridin özeti, seçili gün.
  ///
  /// Süreler burada uzun hâlde — "45dk" ve "182sa" harf harf okunurdu.
  ///
  /// Izgaranın cümlesi başlıkla aynı ayrımı yapıyor (madde 40): bu ayda
  /// "Bu ay", gezinilen geçmiş ayda ayın adı. Gören kullanıcı hangi aya
  /// baktığını başlıktan biliyor, ekran okuyucu kullanıcısı yalnızca bu
  /// cümleden — üstelik gezinme okları onun da durakları.
  String _semanticsLabel(
    AppLocalizations l10n,
    MaterialLocalizations dates,
    HeatmapDay? selected,
  ) {
    final String month = dates.formatMonthYear(heatmap.month);
    final String summary;
    if (heatmap.isEmpty) {
      summary = heatmap.isCurrentMonth
          ? l10n.statsHeatmapEmptySemantics
          : l10n.statsHeatmapPastMonthEmptySemantics(month);
    } else {
      final String total = spellFocusDuration(l10n, heatmap.totalMinutes * 60);
      summary = heatmap.isCurrentMonth
          ? l10n.statsHeatmapSemantics(heatmap.days.length, heatmap.activeDays, total)
          : l10n.statsHeatmapPastMonthSemantics(
              month,
              heatmap.days.length,
              heatmap.activeDays,
              total,
            );
    }
    final String yearSummary = year.isEmpty
        ? l10n.statsHeatmapYearEmptySemantics
        : l10n.statsHeatmapYearSemantics(
            year.activeDays,
            spellFocusDuration(l10n, year.totalMinutes * 60),
          );
    final String base = '$summary $yearSummary';
    if (selected == null) return base;
    return '$base '
        '${l10n.statsHeatmapDaySelectedSemantics(
          dates.formatShortMonthDay(selected.dayKey),
          selected.minutes > 0
              ? spellFocusDuration(l10n, selected.minutes * 60)
              : l10n.statsHeatmapNoFocus,
        )}';
  }

  Widget _weekdayHeader(AppColors colors, AppLocalizations l10n) {
    final List<String> names = shortDayNames(l10n);
    return Row(
      children: <Widget>[
        for (int column = 0; column < _columns; column++) ...<Widget>[
          if (column > 0) const SizedBox(width: _gap),
          Expanded(
            child: Text(
              names[column],
              textAlign: TextAlign.center,
              style: AppTypography.kicker(
                fontSize: AppTextSize.kickerSm,
                color: colors.neutral600,
                letterSpacingEm: 0.06,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Takvim satırları. İlk satır [MonthlyHeatmap.leadingBlanks] kadar boş
  /// hücreyle başlıyor, son satırın artanı da boş kalıyor: günler
  /// sütunlarıyla hizalı duruyor.
  ///
  /// Izgara **bugünün satırında** bitiyor, ayın sonunda değil: gelecek günler
  /// çizilmediği için kalan satırlar ölü alan olurdu (emülatörde ayın
  /// ortasında iki boş satır yüksekliği). Kart ay ilerledikçe büyüyor.
  List<Widget> _rows(AppColors colors) {
    // "Bugünün satırında bitir" yalnızca içinde bulunulan ayın kuralı: geçmiş
    // ayda yaşanmamış gün yok, ızgara ayın son satırına kadar gidiyor.
    final int lastIndex = heatmap.isCurrentMonth ? _todayIndex : heatmap.days.length - 1;
    final int cellCount = heatmap.leadingBlanks + lastIndex + 1;
    final int rowCount = (cellCount / _columns).ceil();

    return <Widget>[
      for (int row = 0; row < rowCount; row++) ...<Widget>[
        if (row > 0) const SizedBox(height: _gap),
        Row(
          children: <Widget>[
            for (int column = 0; column < _columns; column++) ...<Widget>[
              if (column > 0) const SizedBox(width: _gap),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _cell(colors, row * _columns + column),
                ),
              ),
            ],
          ],
        ),
      ],
    ];
  }

  /// [index] ızgaradaki düz konum. Üç konum hiç çizilmiyor, yalnızca yer
  /// tutuyor: ayın 1'inden önceki hücreler, son gününden sonraki hücreler ve
  /// **ayın henüz gelmemiş günleri**.
  ///
  /// Gelecek günlerin boş bırakılması bir ton kararı: ayın 2'sinde 28 kutu
  /// çizmek, yaşanmamış günleri kaçırılmış gün gibi okuturdu. Soluk bir dolgu
  /// da denendi ama emülatörde boş geçmiş günden ayırt edilemedi (%9 ↔ %5
  /// beyaz); baştaki boşlukların kalıbı hem kesin hem zaten tanıdık.
  Widget _cell(AppColors colors, int index) {
    final int dayIndex = index - heatmap.leadingBlanks;
    if (dayIndex < 0 || dayIndex >= heatmap.days.length) return const SizedBox.shrink();

    final HeatmapDay day = heatmap.days[dayIndex];
    if (day.isFuture) return const SizedBox.shrink();

    final DecoratedBox box = DecoratedBox(
      key: heatmapDayCellKey(day.dayKey.day),
      decoration: BoxDecoration(
        color: _cellColor(colors, day),
        borderRadius: BorderRadius.circular(_cellRadius),
        border: _cellBorder(colors, day, dayIndex),
      ),
    );
    // Çizilmeyen hücrede (gelecek gün, ay dışı) dokunulacak bir şey yok; jest
    // ağacı yalnızca yaşanmış hücrelerde kuruluyor.
    if (onDayTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDayTap!(day),
      child: box,
    );
  }

  /// İki işaret aynı hücreye düşebiliyor: bugünün ember çerçevesi
  /// (seviyesinden bağımsız — bar chart'ın bugünü ember yapmasıyla aynı) ve
  /// seçimin çerçevesi. Çakışmada **seçim kazanıyor**: kullanıcının az önceki
  /// dokunuşu, hep orada duran işaretten daha taze.
  ///
  /// Bugün çerçevesi yalnızca içinde bulunulan ayda: geçmiş ayda hiçbir gün
  /// gelecek olmadığı için `_todayIndex` ayın son gününü gösterirdi.
  BoxBorder? _cellBorder(AppColors colors, HeatmapDay day, int dayIndex) {
    if (day.dayKey == selectedDay) return Border.all(color: colors.text, width: 1.5);
    if (heatmap.isCurrentMonth && dayIndex == _todayIndex) {
      return Border.all(color: colors.ember, width: 1.5);
    }
    return null;
  }

  /// Bugün, ızgaradaki gelecek olmayan **son** gün. Ay sonunda tüm günler
  /// geçmişte kaldığında da doğru hücre işaretleniyor.
  int get _todayIndex {
    for (int i = heatmap.days.length - 1; i >= 0; i--) {
      if (!heatmap.days[i].isFuture) return i;
    }
    return -1;
  }

  /// Yalnızca yaşanmış günler için çağrılıyor: doldurulmamış gün nötr bir
  /// dolgu, dolu gün yoğunluk rampası. Aylık hücre de yıllık hücre de aynı
  /// fonksiyondan geçiyor — tek efsanenin gerektirdiği şey.
  Color _cellColor(AppColors colors, HeatmapDay day) =>
      day.level > 0 ? heatmapLevelColor(colors, day.level) : colors.fillSubtle;

  /// İki pencereyi ayıran saç teli. Kartın kendi kenarlığıyla aynı renk:
  /// "aynı kartın içinde başka bir bölüm" demenin en sessiz yolu.
  Widget _divider(AppColors colors) => SizedBox(
        height: 1,
        child: ColoredBox(color: colors.hairline),
      );

  /// Şeridin başlığı. Ay başlığının dilbilgisinin aynısı — solda kicker, sağda
  /// pencerenin toplamı `sky` tonunda. Aynı konum aynı anlam: "bu pencerenin
  /// toplamı".
  ///
  /// Başlık bir yıl sayısı yazmıyor (`SON 52 HAFTA`) çünkü pencere takvim yılı
  /// değil; sağ ucu her zaman bu hafta.
  ///
  /// Toplam boş pencerede hiç yazılmıyor — ay toplamının gerekçesinin aynısı.
  Widget _yearHeader(AppColors colors, AppLocalizations l10n) {
    return Row(
      children: <Widget>[
        Text(
          l10n.statsHeatmapYearLabel,
          style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
        ),
        Expanded(
          child: year.isEmpty
              ? const SizedBox.shrink()
              : Text(
                  spellFocusDuration(l10n, year.totalMinutes * 60),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.sky),
                ),
        ),
      ],
    );
  }

  /// Yuvarlanan 52 haftalık şerit: sütunlar haftalar (eskiden yeniye), satırlar
  /// haftanın günleri (pazartesiden pazara). `days[sütun * 7 + satır]`.
  ///
  /// Hücre ~4.2dp, yani dokunma hedefi olarak imkânsız — şerit jest ağacı hiç
  /// kurmuyor. Kayıp değil: "bu kutu kaç dakika" sorusunu madde 35 zaten
  /// üstteki aylık ızgarada cevapladı. Şeridin işi tek bir şey, yılın şekli.
  ///
  /// Ay adı etiketi yok: `MaterialLocalizations` kısa ay adı vermiyor ve
  /// `DateFormat` madde 29/35'in bilerek reddettiği şey (12 yeni ARB anahtarı
  /// ya da karta `intl` + `initializeDateFormatting` bağımlılığı). Zaman
  /// çapası şeridin kendi geometrisi.
  Widget _yearStrip(AppColors colors) {
    return Row(
      key: heatmapYearStripKey,
      children: <Widget>[
        for (int week = 0; week < kRollingYearWeeks; week++) ...<Widget>[
          if (week > 0) const SizedBox(width: _yearGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int row = 0; row < _yearRows; row++) ...<Widget>[
                  if (row > 0) const SizedBox(height: _yearGap),
                  // `AspectRatio` kendi boyunu kısıtlardan alıyor, çocuğundan
                  // değil: gelecek gün çizilmese de yuva duruyor, yoksa son
                  // sütun diğerlerinden kısa kalır ve `Row` onu ortalardı.
                  AspectRatio(
                    aspectRatio: 1,
                    child: _yearCell(colors, week * _yearRows + row),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Şeridin tek hücresi. Gelecek gün — bu haftanın kalanı — çizilmiyor:
  /// madde 29'un kuralı aynen, yaşanmamış günü boş kutu olarak göstermek onu
  /// kaçırılmış gün gibi okuturdu.
  ///
  /// Bugünün ember çerçevesi **yok**: gelecek günler çizilmediği için son
  /// çizilen hücre zaten bugün, işaret gereksiz olurdu. Ayrıca 4.2dp hücrede
  /// 1.5px çerçeve hücrenin üçte biri demek.
  Widget _yearCell(AppColors colors, int index) {
    final HeatmapDay day = year.days[index];
    if (day.isFuture) return const SizedBox.shrink();
    return DecoratedBox(
      key: heatmapYearCellKey(index),
      decoration: BoxDecoration(
        color: _cellColor(colors, day),
        borderRadius: BorderRadius.circular(_yearCellRadius),
      ),
    );
  }

  /// Rampanın okuma anahtarı (`az ▢▣▤▥ çok`) ve solunda seçili günün
  /// karşılığı: `18 Eyl • 45dk`.
  ///
  /// Detay burada duruyor, tooltip'te değil: dokunmatikte tooltip uzun basış
  /// istiyor, kenar sütunlarda taşıyor ve ekran görüntüsüyle doğrulanamıyor.
  /// Süre kısa hâlde çünkü satırı efsaneyle paylaşıyor (kartın sağ üstündeki
  /// ay toplamı uzun hâlde).
  Widget _footer(
    AppColors colors,
    AppLocalizations l10n,
    MaterialLocalizations dates,
    HeatmapDay? selected,
  ) {
    final TextStyle style =
        AppTypography.kicker(fontSize: AppTextSize.kickerSm, color: colors.neutral600);
    return Row(
      children: <Widget>[
        Expanded(
          child: selected == null
              ? const SizedBox.shrink()
              : Text(
                  l10n.statsHeatmapDayDetail(
                    dates.formatShortMonthDay(selected.dayKey),
                    selected.minutes > 0
                        ? compactFocusDuration(l10n, selected.minutes * 60)
                        : l10n.statsHeatmapNoFocus,
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(fontSize: AppTextSize.xs, color: colors.text),
                ),
        ),
        Text(l10n.statsHeatmapLegendLow, style: style),
        const SizedBox(width: 6),
        for (int level = 1; level <= kHeatmapLevels; level++) ...<Widget>[
          if (level > 1) const SizedBox(width: 3),
          _legendSwatch(heatmapLevelColor(colors, level)),
        ],
        const SizedBox(width: 6),
        Text(l10n.statsHeatmapLegendHigh, style: style),
      ],
    );
  }

  Widget _legendSwatch(Color color) {
    return SizedBox(
      width: 9,
      height: 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
