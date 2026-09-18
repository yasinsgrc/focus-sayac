import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/rolling_number.dart';
import '../../domain/stats/focus_stats.dart';
import '../../domain/stats/monthly_heatmap.dart';
import '../../domain/stats/stats_providers.dart';
import '../../domain/stats/subject_breakdown.dart';
import '../../domain/stats/weekly_summary.dart';
import '../../domain/time/duration_formatter.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/ads/banner_ad_slot.dart';
import 'widgets/monthly_heatmap_card.dart';
import 'widgets/subject_breakdown_card.dart';
import 'widgets/weekly_focus_bar_painter.dart';

/// Ekran 06 — istatistik. Prototip v2 satır 248-285 birebir. Prototipin
/// `42 SAAT` / `1 sa 48 dk` / `11 GÜN` / `%86` / `%94` değerlerinin hiçbiri
/// kodda yok; hepsi `PomodoroSession` kayıtlarından türetilir (SPEC.md DoD).
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -110,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 520,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[colors.sky.withValues(alpha: 0.26), Colors.transparent],
                    stops: const <double>[0, 0.62],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            // Gövde **yalnızca sığmadığında** kayıyor (madde 24'te Ekran 02'ye
            // uygulanan kalıbın aynısı): `minHeight` ekranın tamamı olduğu için
            // uzun ekranlarda içerik eskisi gibi yerleşiyor. Banner kaydırma
            // alanının dışında — reklam kaydırılıp gözden kaybolmuyor.
            //
            // Aylık ısı haritası (madde 29) eklenince gerekti: kart en sıkı
            // hâliyle ~250px istiyor, oysa ekran 390x844'te `Spacer`ı sıfıra
            // inmiş hâlde zaten sınırdaydı.
            child: Column(
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: const _StatsBody(),
                        ),
                      );
                    },
                  ),
                ),
                // SPEC.md §7.1: banner yalnızca Ekran 02 ve Ekran 06.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 26),
                  child: BannerAdSlot(),
                ),
                // Alt gezinme çubuğunun yeri, `BannerAdSlot`ın `bottomMargin`i
                // yerine burada ayrılıyor: yuva kapandığında (reklam onayı yok
                // ya da premium) o pay da kalkıyor ve kaydırılan içeriğin sonu
                // çubuğun arkasına giriyordu — emülatörde ısı haritasının alt
                // iki satırı görünmüyordu. Ölçü madde 36'da ekranın kendi
                // 88'inden Ekran 04/07'nin de kullandığı ortak sabite geçti.
                const SizedBox(height: kBottomNavReservedSpace),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: BottomNavBar(
              active: AppNavTab.stats,
              onSelect: (AppNavTab tab) => navigateToNavTab(context, tab, current: AppNavTab.stats),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ekran 06'nın kaydırılabilir gövdesi — prototip v2 satır 248-285 birebir.
/// Prototipin `42 SAAT` / `1 sa 48 dk` / `11 GÜN` / `%86` / `%94` değerlerinin
/// hiçbiri kodda yok; hepsi `PomodoroSession` kayıtlarından türer (SPEC.md DoD).
class _StatsBody extends ConsumerWidget {
  const _StatsBody();

  /// Prototipin bar chart kartı yüksekliği (satır 259).
  static const double _chartHeight = 162;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FocusStats stats = ref.watch(focusStatsProvider);
    final SubjectBreakdown breakdown = ref.watch(subjectBreakdownProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 8),
          RiseIn(
            child: Text(
              l10n.statsTotalFocus,
              style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
            ),
          ),
          const SizedBox(height: 8),
          RiseIn(
            delay: RiseIn.step,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ShaderMask(
                shaderCallback: (Rect bounds) => LinearGradient(
                  colors: colors.chromeGradient,
                  stops: AppColors.chromeGradientStops,
                ).createShader(bounds),
                child: RollingNumber(
                  // Yön kaynağı ham saniye: metin `3 SAAT` ↔ `180
                  // DAKİKA` arasında birim değiştirse de toplam odak
                  // hep artıyor.
                  value: stats.cumulativeSeconds,
                  text: _cumulativeText(l10n, stats.cumulativeSeconds),
                  style: AppTypography.counter(
                    fontSize: AppTextSize.counterLg,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          RiseIn(
            delay: RiseIn.step * 2,
            child: Text(
              l10n.statsWeeklyAverage(_averageText(l10n, stats.dailyAverageSeconds)),
              style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral500),
            ),
          ),
          const SizedBox(height: 14),
          // Haftalık kapanış: pazar akşamı gönderilen bildirimin
          // uygulamadaki karşılığı. Bildirim bir "dönüş sebebi"
          // olabilsin diye dönülecek bir yer gerekiyordu — aynı iki sayı
          // burada her gün duruyor (`weeklySummaryProvider`).
          RiseIn(delay: RiseIn.step * 3, child: const _WeeklyClosingCard()),
          const SizedBox(height: 12),
          RiseIn(
            delay: RiseIn.step * 4,
            child: _Card(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(double.infinity, _chartHeight),
                  painter: WeeklyFocusBarPainter(week: stats.lastWeek, colors: colors, l10n: l10n),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          RiseIn(
            delay: RiseIn.step * 5,
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    label: l10n.statsLongestStreak,
                    value: stats.longestStreak,
                    valueText: '${stats.longestStreak}',
                    unit: l10n.statsDaysUnit,
                    valueColor: colors.ember,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: l10n.statsCompletion,
                    value: stats.completionPercent ?? 0,
                    valueText: stats.completionPercent == null
                        ? l10n.commonEmptyValue
                        : l10n.statsCompletionPercent(stats.completionPercent!),
                    valueColor: colors.mint,
                  ),
                ),
              ],
            ),
          ),
          // Ders dağılımı (ROADMAP madde 30): haftalık pencereyi konuşan
          // kartların yanında, aylık ısı haritasının üstünde.
          //
          // Tek dilim belirtilmemişse kart hiç çizilmiyor: henüz ders seçmemiş
          // (ya da göçten yeni gelmiş) kullanıcıya "Belirtilmemiş %100" tek
          // satırı bir dağılım değil, boş bir kutu gösterirdi.
          if (breakdown.slices.any((SubjectSlice s) => s.key != null)) ...<Widget>[
            const SizedBox(height: 12),
            RiseIn(
              delay: RiseIn.step * 6,
              child: SubjectBreakdownCard(breakdown: breakdown),
            ),
          ],
          if (stats.productiveWindow != null) ...<Widget>[
            const SizedBox(height: 12),
            RiseIn(
              delay: RiseIn.step * 7,
              child: _ProductiveWindowCard(window: stats.productiveWindow!),
            ),
          ],
          const SizedBox(height: 12),
          // Aylık ısı haritası (ROADMAP madde 29): bar chart son yedi günün
          // dakikalarını veriyor, ızgara ise ritmi — hangi günler çalışıldığını
          // ve boşluğun nerede açıldığını.
          RiseIn(
            delay: RiseIn.step * 8,
            child: const _HeatmapSection(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// Prototipin `42 SAAT` başlığı. Bir saatin altındaki toplamlar `0 SAAT`
  /// olarak yuvarlanmasın diye dakikaya düşer — ilk günün kullanıcısı da
  /// gerçek emeğini görür.
  String _cumulativeText(AppLocalizations l10n, int seconds) {
    final FocusDurationParts parts = formatFocusDuration(seconds);
    return parts.hours > 0 ? l10n.statsCumulativeHours(parts.hours) : l10n.statsCumulativeMinutes(parts.minutes);
  }

  String _averageText(AppLocalizations l10n, int seconds) {
    final FocusDurationParts parts = formatFocusDuration(seconds);
    return parts.hours > 0
        ? l10n.statsAverageHoursMinutes(parts.hours, parts.minutes)
        : l10n.statsAverageMinutes(parts.minutes);
  }
}

/// Isı haritasının gezinme durumu (ROADMAP madde 35): hangi ay açık ve hangi
/// gün seçili.
///
/// Durum kartın kendisinde değil burada: kart saf kalınca testte Riverpod
/// kurmadan çizilebiliyor (madde 29'un kalıbı) ve iki durum tek yerde
/// tutuluyor. Sağlayıcıya da yazılmıyor — ikisi de bir bakışın süresi kadar
/// yaşıyor, ekrandan çıkan kullanıcı geri geldiğinde bugünü görmeli.
class _HeatmapSection extends ConsumerStatefulWidget {
  const _HeatmapSection();

  @override
  ConsumerState<_HeatmapSection> createState() => _HeatmapSectionState();
}

class _HeatmapSectionState extends ConsumerState<_HeatmapSection> {
  /// 0 bu ay, −1 geçen ay. İleri yönde 0'ı aşmıyor: gezinmeyi açan okun
  /// kapısı `hasLater` ve o da bu aydan öteye izin vermiyor.
  int _monthOffset = 0;

  /// Seçili günün anahtarı (`HeatmapDay.dayKey`).
  DateTime? _selectedDay;

  void _step(int step) {
    setState(() {
      _monthOffset += step;
      // Seçim ayla birlikte kalkıyor: başka ayın gününü gösteren bir satır
      // ızgarayla çelişirdi.
      _selectedDay = null;
    });
  }

  /// Aynı hücreye ikinci dokunuş seçimi kaldırıyor — açılan bir şey yok, kapatma
  /// düğmesi de olmasın.
  void _toggleDay(HeatmapDay day) {
    setState(() => _selectedDay = _selectedDay == day.dayKey ? null : day.dayKey);
  }

  @override
  Widget build(BuildContext context) {
    return MonthlyHeatmapCard(
      heatmap: ref.watch(monthlyHeatmapProvider(_monthOffset)),
      selectedDay: _selectedDay,
      onDayTap: _toggleDay,
      onMonthStep: _step,
    );
  }
}

/// Haftalık kapanış kartı — pazar akşamı bildiriminin uygulamadaki ikizi.
///
/// İki pencere de boşken hiç çizilmiyor: ilk gününde olan kullanıcıya "bu hafta
/// 0 dakika" göstermek, eşlik eden bir tondan ölçen bir tona geçmek olurdu
/// (`WeeklySummary.isEmpty`).
///
/// Fark yönü renk taşıyor ama **kırmızı yok**: azalma `neutral` tonda
/// yazılıyor. Düşen bir haftayı uyarı rengiyle göstermek, sınav öğrencisinde
/// seri kaygısını besleyen tam o ters tepki.
class _WeeklyClosingCard extends ConsumerWidget {
  const _WeeklyClosingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final WeeklySummary summary = ref.watch(weeklySummaryProvider);
    if (summary.isEmpty) return const SizedBox.shrink();

    final int delta = summary.deltaSeconds;
    final (String text, Color color) = switch ((summary.hasComparison, delta)) {
      (false, _) => (l10n.statsWeeklyClosingNoComparison, colors.neutral600),
      (true, 0) => (l10n.statsWeeklyClosingDeltaSame, colors.neutral500),
      (true, final int d) when d > 0 => (
          l10n.statsWeeklyClosingDeltaUp(spellFocusDuration(l10n, d)),
          colors.mint,
        ),
      (true, final int d) => (
          l10n.statsWeeklyClosingDeltaDown(spellFocusDuration(l10n, -d)),
          colors.neutral500,
        ),
    };

    return _Card(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          Icon(PhosphorIconsDuotone.calendarCheck, size: 22, color: colors.accent400),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  l10n.statsWeeklyClosingLabel,
                  style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
                ),
                const SizedBox(height: 6),
                Text(
                  spellFocusDuration(l10n, summary.seconds),
                  style: AppTypography.display(
                    fontSize: AppTextSize.title,
                    weight: FontWeight.w700,
                    color: colors.text,
                  ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
                ),
                const SizedBox(height: 4),
                Text(text, style: AppTypography.body(fontSize: AppTextSize.md, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototipin `rgba(30,32,48,.72)` + `1px rgba(255,255,255,.07)` kartı.
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceCardSoft,
        borderRadius: BorderRadius.circular(26),
        border: Border.fromBorderSide(BorderSide(color: colors.hairline)),
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueText,
    required this.valueColor,
    this.unit,
  });

  final String label;

  /// Kayma yönünün kaynağı; çizilen metin [valueText] (oran tanımsızken `—`).
  final int value;
  final String valueText;
  final String? unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return _Card(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label,
              style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600)),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              RollingNumber(
                value: value,
                text: valueText,
                style: AppTypography.counter(fontSize: AppTextSize.counterSm, color: valueColor),
              ),
              if (unit != null)
                Text(unit!, style: AppTypography.label(fontSize: AppTextSize.lg, color: colors.neutral500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductiveWindowCard extends StatelessWidget {
  const _ProductiveWindowCard({required this.window});

  final ProductiveWindow window;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.skyDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.sky.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Icon(PhosphorIconsDuotone.lightning, size: 22, color: colors.sky),
          const SizedBox(width: 13),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral300),
                children: <InlineSpan>[
                  TextSpan(text: AppLocalizations.of(context).statsProductiveWindowPrefix),
                  TextSpan(text: _windowText, style: TextStyle(color: colors.sky)),
                  TextSpan(text: AppLocalizations.of(context).statsProductiveWindowSuffix(window.completionPercent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _windowText => '${_hh(window.startHour)}–${_hh(window.endHour)}';

  /// Gün sonundaki kova `24:00` yerine `00:00` yazar.
  String _hh(int hour) => '${(hour % 24).toString().padLeft(2, '0')}:00';
}
