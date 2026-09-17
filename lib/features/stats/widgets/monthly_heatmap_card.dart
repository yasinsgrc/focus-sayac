import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/stats/monthly_heatmap.dart';
import '../../../domain/time/duration_formatter.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'weekly_focus_bar_painter.dart';

/// Izgaranın [dayOfMonth]. gün hücresi — testler bir günün tonuna bununla
/// bakıyor.
Key heatmapDayCellKey(int dayOfMonth) => ValueKey<String>('heatmap-day-$dayOfMonth');

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
/// `CustomPainter` değil widget ağacı: 42 hücre statik ve bir `RepaintBoundary`
/// içinde, karşılığında her hücre testten görünüyor. Madde 31 zaten bir
/// painter'ın doğrulanamamasından açık; ikincisi eklenmedi.
class MonthlyHeatmapCard extends StatelessWidget {
  const MonthlyHeatmapCard({required this.heatmap, super.key});

  final MonthlyHeatmap heatmap;

  /// Hücreler arası boşluk ve hücre köşesi.
  static const double _gap = 5;
  static const double _cellRadius = 6;

  /// Haftada yedi gün — ızgaranın sütun sayısı.
  static const int _columns = 7;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: heatmap.isEmpty
          ? l10n.statsHeatmapEmptySemantics
          : l10n.statsHeatmapSemantics(
              heatmap.days.length,
              heatmap.activeDays,
              spellFocusDuration(l10n, heatmap.totalMinutes * 60),
            ),
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
              _header(colors, l10n),
              const SizedBox(height: 14),
              _weekdayHeader(colors, l10n),
              const SizedBox(height: _gap),
              ..._rows(colors),
              const SizedBox(height: 12),
              _legend(colors, l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// Başlık ayın adı değil `BU AY`: `DateFormat` ya 12 yeni ARB anahtarı ya da
  /// karta `intl` bağımlılığı demek, oysa kart `initializeDateFormatting`
  /// çağrılmadan da çizilmek zorunda (`shortDayNames` ile aynı kısıt).
  ///
  /// Toplam **boş ayda hiç yazılmıyor**: haftalık kapanış kartının gerekçesinin
  /// aynısı — "0 dakika" eşlik eden bir tondan ölçen bir tona geçiş.
  Widget _header(AppColors colors, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          l10n.statsHeatmapLabel,
          style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
        ),
        if (!heatmap.isEmpty)
          Text(
            spellFocusDuration(l10n, heatmap.totalMinutes * 60),
            style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.sky),
          ),
      ],
    );
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
    final int cellCount = heatmap.leadingBlanks + _todayIndex + 1;
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
    return DecoratedBox(
      key: heatmapDayCellKey(day.dayKey.day),
      decoration: BoxDecoration(
        color: _cellColor(colors, day),
        borderRadius: BorderRadius.circular(_cellRadius),
        // Bugünün çerçevesi seviyesinden bağımsız — bar chart'ın bugünü ember
        // yapmasıyla aynı.
        border: dayIndex == _todayIndex ? Border.all(color: colors.ember, width: 1.5) : null,
      ),
    );
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
  /// dolgu, dolu gün yoğunluk rampası.
  Color _cellColor(AppColors colors, HeatmapDay day) =>
      day.level > 0 ? heatmapLevelColor(colors, day.level) : colors.fillSubtle;

  /// Rampanın okuma anahtarı: `az ▢▣▤▥ çok`.
  Widget _legend(AppColors colors, AppLocalizations l10n) {
    final TextStyle style =
        AppTypography.kicker(fontSize: AppTextSize.kickerSm, color: colors.neutral600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
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
