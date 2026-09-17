import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/domain/stats/monthly_heatmap.dart';
import 'package:focussayac/features/stats/widgets/monthly_heatmap_card.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

import '../../support/localized_test_app.dart';

/// 17 Eylül 2026, 15:00 TSİ. Eylül 30 günlük, ayın 1'i salı.
final DateTime _nowUtc = DateTime.utc(2026, 9, 17, 12);

int _id = 0;

PomodoroSession _september(int day, {int minutes = 25}) {
  return PomodoroSession(
    id: ++_id,
    type: SessionType.focus,
    startedAt: DateTime.utc(2026, 9, day, 12),
    plannedDurationSec: minutes * 60,
    completed: true,
    breakExtensions: 0,
  );
}

final AppColors _colors = AppColors.dark();

/// Kartı tek başına çizer — veritabanı ve Riverpod yok, ızgara doğrudan saf
/// hesaplayıcıdan besleniyor.
Future<void> _pumpCard(WidgetTester tester, List<PomodoroSession> sessions) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    localizedTestApp(
      Scaffold(
        backgroundColor: _colors.bg,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: MonthlyHeatmapCard(
            heatmap: calculateMonthlyHeatmap(sessions: sessions, nowUtc: _nowUtc),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

BoxDecoration _cellDecoration(WidgetTester tester, int dayOfMonth) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.byKey(heatmapDayCellKey(dayOfMonth)),
  );
  return box.decoration as BoxDecoration;
}

void main() {
  testWidgets('kısmi ay: seviyeler renge, gelecek günler soluk dolguya çevriliyor',
      (WidgetTester tester) async {
    await _pumpCard(tester, <PomodoroSession>[
      _september(2, minutes: 10), // seviye 1
      _september(9, minutes: 30), // seviye 2
      _september(14, minutes: 60), // seviye 3
      _september(16, minutes: 120), // seviye 4
    ]);

    // Ayın tamamı çiziliyor: 30 hücre.
    for (int day = 1; day <= 30; day++) {
      expect(find.byKey(heatmapDayCellKey(day)), findsOneWidget, reason: '$day. gün hücresi');
    }
    expect(find.byKey(heatmapDayCellKey(31)), findsNothing);

    expect(_cellDecoration(tester, 2).color, heatmapLevelColor(_colors, 1));
    expect(_cellDecoration(tester, 9).color, heatmapLevelColor(_colors, 2));
    expect(_cellDecoration(tester, 14).color, heatmapLevelColor(_colors, 3));
    expect(_cellDecoration(tester, 16).color, heatmapLevelColor(_colors, 4));
    // Geçmişte kalan boş gün: dolu bir hücreden zayıf, gelecekten güçlü.
    expect(_cellDecoration(tester, 3).color, _colors.fillSubtle);
    // Gelecek gün: yaşanmamış gün kaçırılmış gün gibi okunmasın.
    expect(_cellDecoration(tester, 18).color, _colors.fillFaint);
    expect(_cellDecoration(tester, 30).color, _colors.fillFaint);

    // Bugünün çerçevesi seviyesinden bağımsız.
    expect(_cellDecoration(tester, 17).border, isNotNull);
    expect(_cellDecoration(tester, 16).border, isNull);

    // Başlık, toplam ve ölçek.
    expect(find.text('BU AY'), findsOneWidget);
    expect(find.text('3 saat 40 dakika'), findsOneWidget);
    expect(find.text('az'), findsOneWidget);
    expect(find.text('çok'), findsOneWidget);
    // Gün başlıkları bar chart'ın ARB kataloğundan.
    expect(find.text('Pzt'), findsOneWidget);
    expect(find.text('Paz'), findsOneWidget);

    expect(
      find.bySemanticsLabel('Bu ay 30 günün 4 gününde odaklandın, toplam 3 saat 40 dakika.'),
      findsOneWidget,
    );
  });

  testWidgets('boş ay: ızgara çiziliyor, toplam metni yazılmıyor', (WidgetTester tester) async {
    await _pumpCard(tester, const <PomodoroSession>[]);

    expect(find.byKey(heatmapDayCellKey(1)), findsOneWidget);
    expect(find.byKey(heatmapDayCellKey(30)), findsOneWidget);
    expect(find.text('BU AY'), findsOneWidget);
    // "0 dakika" ölçen bir ton olurdu (haftalık kapanış kartıyla aynı gerekçe).
    expect(find.textContaining('dakika'), findsNothing);
    expect(find.bySemanticsLabel('Bu ay henüz odak yok.'), findsOneWidget);

    // Geçmiş günler boş dolguda, gelecek günler soluk.
    expect(_cellDecoration(tester, 1).color, _colors.fillSubtle);
    expect(_cellDecoration(tester, 17).color, _colors.fillSubtle);
    expect(_cellDecoration(tester, 18).color, _colors.fillFaint);
  });

  testWidgets('yoğun ay: her gün en üst seviyede', (WidgetTester tester) async {
    await _pumpCard(tester, <PomodoroSession>[
      for (int day = 1; day <= 17; day++) _september(day, minutes: 150),
    ]);

    for (int day = 1; day <= 17; day++) {
      expect(
        _cellDecoration(tester, day).color,
        heatmapLevelColor(_colors, kHeatmapLevels),
        reason: '$day. gün',
      );
    }
    expect(
      find.bySemanticsLabel('Bu ay 30 günün 17 gününde odaklandın, toplam 42 saat 30 dakika.'),
      findsOneWidget,
    );
  });
}
