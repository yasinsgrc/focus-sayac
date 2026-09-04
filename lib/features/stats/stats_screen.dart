import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../domain/stats/focus_stats.dart';
import '../../domain/stats/stats_providers.dart';
import '../../domain/time/duration_formatter.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/ads/banner_ad_slot.dart';
import 'widgets/weekly_focus_bar_painter.dart';

/// Ekran 06 — istatistik. Prototip v2 satır 248-285 birebir. Prototipin
/// `42 SAAT` / `1 sa 48 dk` / `11 GÜN` / `%86` / `%94` değerlerinin hiçbiri
/// kodda yok; hepsi `PomodoroSession` kayıtlarından türetilir (SPEC.md DoD).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  /// Prototipin bar chart kartı yüksekliği (satır 259).
  static const double _chartHeight = 162;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FocusStats stats = ref.watch(focusStatsProvider);

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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 8),
                  Text(l10n.statsTotalFocus, style: AppTypography.kicker(fontSize: 9, color: colors.neutral600)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) => const LinearGradient(
                        colors: AppColors.chromeGradient,
                        stops: AppColors.chromeGradientStops,
                      ).createShader(bounds),
                      child: Text(
                        _cumulativeText(l10n, stats.cumulativeSeconds),
                        style: AppTypography.counter(
                          fontSize: 46,
                          color: Colors.white,
                          letterSpacingEm: -0.055,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.statsWeeklyAverage(_averageText(l10n, stats.dailyAverageSeconds)),
                    style: AppTypography.body(fontSize: 12.5, color: colors.neutral500),
                  ),
                  const SizedBox(height: 20),
                  _Card(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(double.infinity, _chartHeight),
                        painter: WeeklyFocusBarPainter(week: stats.lastWeek, colors: colors, l10n: l10n),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricCard(
                          label: l10n.statsLongestStreak,
                          value: '${stats.longestStreak}',
                          unit: l10n.statsDaysUnit,
                          valueColor: colors.ember,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: l10n.statsCompletion,
                          value: stats.completionPercent == null
                              ? l10n.commonEmptyValue
                              : l10n.statsCompletionPercent(stats.completionPercent!),
                          valueColor: colors.mint,
                        ),
                      ),
                    ],
                  ),
                  if (stats.productiveWindow != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _ProductiveWindowCard(window: stats.productiveWindow!),
                  ],
                  const Spacer(),
                  // SPEC.md §7.1: banner yalnızca Ekran 02 ve Ekran 06.
                  const BannerAdSlot(bottomMargin: 88),
                ],
              ),
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

/// Prototipin `rgba(30,32,48,.72)` + `1px rgba(255,255,255,.07)` kartı.
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xB81E2030),
        borderRadius: BorderRadius.circular(26),
        border: const Border.fromBorderSide(BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.valueColor,
    this.unit,
  });

  final String label;
  final String value;
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
          Text(label, style: AppTypography.kicker(fontSize: 8, color: colors.neutral600, letterSpacingEm: 0.22)),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: value,
                  style: AppTypography.counter(fontSize: 30, color: valueColor, letterSpacingEm: -0.05),
                ),
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: AppTypography.display(fontSize: 14, color: colors.neutral500),
                  ),
              ],
            ),
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
        color: const Color(0x9910283F),
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
                style: AppTypography.body(fontSize: 12.5, color: colors.neutral300, height: 1.5),
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
