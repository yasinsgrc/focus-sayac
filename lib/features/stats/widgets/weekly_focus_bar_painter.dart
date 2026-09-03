import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/stats/focus_stats.dart';

/// Türkçe kısa gün adları, `DateTime.weekday - 1` ile indekslenir
/// (prototipin `dayNames` dizisi birebir). `intl` üzerinden üretmek yerine
/// sabit liste: chart'ın `initializeDateFormatting` çağrılmadan da doğru
/// çizilmesi gerekiyor. Faz 13'te bu liste de ARB'ye taşınacak.
const List<String> kShortDayNames = <String>['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Prototipin sütun üstündeki değer etiketi: `1s 35` / `2s` / veri yoksa `—`.
String formatBarValue(int minutes) {
  if (minutes <= 0) return '—';
  final int remainder = minutes % 60;
  return '${minutes ~/ 60}s${remainder > 0 ? ' $remainder' : ''}';
}

/// Ekran 06'nın 7 günlük bar chart'ı (SPEC.md Faz 9 "`CustomPainter` bar
/// chart"). Sütun yükseklikleri haftanın **kendi** en yüksek gününe göre
/// ölçeklenir — sabit bir tavan, az çalışılan bir haftada tüm sütunları
/// okunmaz biçimde kısaltırdı.
class WeeklyFocusBarPainter extends CustomPainter {
  const WeeklyFocusBarPainter({required this.week, required this.colors});

  /// Eskiden yeniye 7 gün; son eleman bugün (bkz. [FocusStats.lastWeek]).
  final List<DailyFocus> week;
  final AppColors colors;

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

    final TextPainter valuePainter = TextPainter(textDirection: TextDirection.ltr);
    final TextPainter dayPainter = TextPainter(textDirection: TextDirection.ltr);

    // Etiket yükseklikleri sütun alanını belirlediği için önce bir kez ölçülür
    // (iki etiket de tek satır ve aynı fontta, ölçüm sütuna göre değişmez).
    valuePainter
      ..text = TextSpan(text: '—', style: _valueStyle(colors.neutral600))
      ..layout();
    dayPainter
      ..text = TextSpan(text: kShortDayNames.first, style: _dayStyle(colors.neutral600))
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
        ..text = TextSpan(text: formatBarValue(day.minutes), style: _valueStyle(colors.neutral600))
        ..layout();
      valuePainter.paint(canvas, Offset(left + (barWidth - valuePainter.width) / 2, 0));

      dayPainter
        ..text = TextSpan(
          text: kShortDayNames[day.dayKey.weekday - 1].toUpperCase(),
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
    if (oldDelegate.colors != colors || oldDelegate.week.length != week.length) return true;
    for (int i = 0; i < week.length; i++) {
      if (oldDelegate.week[i].minutes != week[i].minutes ||
          oldDelegate.week[i].dayKey != week[i].dayKey) {
        return true;
      }
    }
    return false;
  }
}
