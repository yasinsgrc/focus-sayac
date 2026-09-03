import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/stats/focus_stats.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Kısa gün adları, `DateTime.weekday - 1` ile indekslenir (prototipin
/// `dayNames` dizisi birebir). `intl`in `DateFormat.E` biçimlendiricisi yerine
/// ARB kataloğu: chart'ın `initializeDateFormatting` çağrılmadan da doğru
/// çizilmesi gerekiyor (Faz 9 kararı) ve SPEC.md §0 kural 7 metinleri ARB'de
/// istiyor.
List<String> shortDayNames(AppLocalizations l10n) => <String>[
      l10n.statsWeekdayMon,
      l10n.statsWeekdayTue,
      l10n.statsWeekdayWed,
      l10n.statsWeekdayThu,
      l10n.statsWeekdayFri,
      l10n.statsWeekdaySat,
      l10n.statsWeekdaySun,
    ];

/// Prototipin sütun üstündeki değer etiketi: `1s 35` / `2s` / veri yoksa `—`.
String formatBarValue(AppLocalizations l10n, int minutes) {
  if (minutes <= 0) return l10n.commonEmptyValue;
  final int remainder = minutes % 60;
  return remainder > 0
      ? l10n.statsBarHoursMinutes(minutes ~/ 60, remainder)
      : l10n.statsBarHours(minutes ~/ 60);
}

/// Ekran 06'nın 7 günlük bar chart'ı (SPEC.md Faz 9 "`CustomPainter` bar
/// chart"). Sütun yükseklikleri haftanın **kendi** en yüksek gününe göre
/// ölçeklenir — sabit bir tavan, az çalışılan bir haftada tüm sütunları
/// okunmaz biçimde kısaltırdı.
class WeeklyFocusBarPainter extends CustomPainter {
  const WeeklyFocusBarPainter({required this.week, required this.colors, required this.l10n});

  /// Eskiden yeniye 7 gün; son eleman bugün (bkz. [FocusStats.lastWeek]).
  final List<DailyFocus> week;
  final AppColors colors;

  /// Gün adları ve sütun değer etiketleri ARB'den; `CustomPainter`ın
  /// `BuildContext`i olmadığı için çağıran (`StatsScreen`) geçiriyor.
  final AppLocalizations l10n;

  /// Prototipteki sütun aralığı / köşe yarıçapı / en kısa sütun.
  static const double _barGap = 11;
  static const double _barRadius = 9;
  static const double _minBarHeight = 5;
  static const double _labelGap = 9;

  @override
  void paint(Canvas canvas, Size size) {
    if (week.isEmpty) return;

    final int maxMinutes = week.fold(0, (int max, DailyFocus d) => math.max(max, d.minutes));
    final double barWidth = (size.width - _barGap * (week.length - 1)) / week.length;
    final List<String> dayNames = shortDayNames(l10n);

    final TextPainter valuePainter = TextPainter(textDirection: TextDirection.ltr);
    final TextPainter dayPainter = TextPainter(textDirection: TextDirection.ltr);

    // Etiket yükseklikleri sütun alanını belirlediği için önce bir kez ölçülür
    // (iki etiket de tek satır ve aynı fontta, ölçüm sütuna göre değişmez).
    valuePainter
      ..text = TextSpan(text: l10n.commonEmptyValue, style: _valueStyle(colors.neutral600))
      ..layout();
    dayPainter
      ..text = TextSpan(text: dayNames.first, style: _dayStyle(colors.neutral600))
      ..layout();
    final double barAreaHeight =
        size.height - valuePainter.height - dayPainter.height - _labelGap * 2;
    if (barAreaHeight <= 0) return;

    for (int i = 0; i < week.length; i++) {
      final DailyFocus day = week[i];
      final bool isToday = i == week.length - 1;
      final double left = i * (barWidth + _barGap);

      final double ratio = maxMinutes == 0 ? 0 : day.minutes / maxMinutes;
      final double barHeight = math.max(_minBarHeight, ratio * barAreaHeight);
      final Rect barRect = Rect.fromLTWH(
        left,
        valuePainter.height + _labelGap + (barAreaHeight - barHeight),
        barWidth,
        barHeight,
      );
      final Paint barPaint = Paint();
      if (day.minutes == 0) {
        barPaint.color = const Color(0x14FFFFFF);
      } else {
        barPaint.shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isToday
              ? <Color>[colors.ember, colors.emberDim]
              : <Color>[colors.sky, colors.skyDeep],
        ).createShader(barRect);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(_barRadius)),
        barPaint,
      );

      valuePainter
        ..text = TextSpan(text: formatBarValue(l10n, day.minutes), style: _valueStyle(colors.neutral600))
        ..layout();
      valuePainter.paint(canvas, Offset(left + (barWidth - valuePainter.width) / 2, 0));

      dayPainter
        ..text = TextSpan(
          text: dayNames[day.dayKey.weekday - 1].toUpperCase(),
          style: _dayStyle(isToday ? colors.ember : colors.neutral600),
        )
        ..layout();
      dayPainter.paint(
        canvas,
        Offset(left + (barWidth - dayPainter.width) / 2, size.height - dayPainter.height),
      );
    }
  }

  TextStyle _valueStyle(Color color) =>
      AppTypography.kicker(fontSize: 7.5, color: color, letterSpacingEm: 0.1);

  TextStyle _dayStyle(Color color) =>
      AppTypography.kicker(fontSize: 8, color: color, letterSpacingEm: 0.12);

  @override
  bool shouldRepaint(covariant WeeklyFocusBarPainter oldDelegate) {
    if (oldDelegate.colors != colors || oldDelegate.l10n != l10n || oldDelegate.week.length != week.length) {
      return true;
    }
    for (int i = 0; i < week.length; i++) {
      if (oldDelegate.week[i].minutes != week[i].minutes ||
          oldDelegate.week[i].dayKey != week[i].dayKey) {
        return true;
      }
    }
    return false;
  }
}
