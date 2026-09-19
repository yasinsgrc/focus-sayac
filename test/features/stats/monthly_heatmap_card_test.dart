import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/domain/stats/monthly_heatmap.dart';
import 'package:focussayac/domain/stats/rolling_year_heatmap.dart';
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

/// Geçmiş ayın (ağustos 2026) günü — ay gezinme testleri için.
PomodoroSession _august(int day, {int minutes = 25}) {
  return PomodoroSession(
    id: ++_id,
    type: SessionType.focus,
    startedAt: DateTime.utc(2026, 8, day, 12),
    plannedDurationSec: minutes * 60,
    completed: true,
    breakExtensions: 0,
  );
}

final AppColors _colors = AppColors.dark();

/// Kartı tek başına çizer — veritabanı ve Riverpod yok, ızgara doğrudan saf
/// hesaplayıcıdan besleniyor.
Future<void> _pumpCard(
  WidgetTester tester,
  List<PomodoroSession> sessions, {
  int monthOffset = 0,
  DateTime? selectedDay,
  ValueChanged<HeatmapDay>? onDayTap,
  ValueChanged<int>? onMonthStep,
}) async {
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
            heatmap: calculateMonthlyHeatmap(
              sessions: sessions,
              nowUtc: _nowUtc,
              monthOffset: monthOffset,
            ),
            // Şerit aynı seans listesinden besleniyor: ay gezinse de pencere
            // sabit olduğu için `monthOffset` buraya geçmiyor.
            year: calculateRollingYearHeatmap(sessions: sessions, nowUtc: _nowUtc),
            selectedDay: selectedDay,
            onDayTap: onDayTap,
            onMonthStep: onMonthStep,
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

BoxDecoration _yearCellDecoration(WidgetTester tester, int index) {
  final DecoratedBox box = tester.widget<DecoratedBox>(find.byKey(heatmapYearCellKey(index)));
  return box.decoration as BoxDecoration;
}

/// Şeritte gerçekten çizilen hücre sayısı. Şeridin kabının altında sayılıyor,
/// yoksa aylık ızgaranın hücreleri de sayıya karışırdı.
int _drawnYearCells(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byKey(heatmapYearStripKey),
        matching: find.byType(DecoratedBox),
      ),
    )
    .length;

void main() {
  testWidgets('kısmi ay: seviyeler renge çevriliyor, gelecek günler çizilmiyor',
      (WidgetTester tester) async {
    await _pumpCard(tester, <PomodoroSession>[
      _september(2, minutes: 10), // seviye 1
      _september(9, minutes: 30), // seviye 2
      _september(14, minutes: 60), // seviye 3
      _september(16, minutes: 120), // seviye 4
    ]);

    // Yaşanmış her gün bir hücre: ayın 1'inden bugüne (17 Eylül).
    for (int day = 1; day <= 17; day++) {
      expect(find.byKey(heatmapDayCellKey(day)), findsOneWidget, reason: '$day. gün hücresi');
    }
    // Ayın gelecek günleri baştaki boşluklar gibi yer tutuyor ama çizilmiyor.
    for (int day = 18; day <= 30; day++) {
      expect(find.byKey(heatmapDayCellKey(day)), findsNothing, reason: '$day. gün hücresi');
    }
    expect(find.byKey(heatmapDayCellKey(31)), findsNothing);

    expect(_cellDecoration(tester, 2).color, heatmapLevelColor(_colors, 1));
    expect(_cellDecoration(tester, 9).color, heatmapLevelColor(_colors, 2));
    expect(_cellDecoration(tester, 14).color, heatmapLevelColor(_colors, 3));
    expect(_cellDecoration(tester, 16).color, heatmapLevelColor(_colors, 4));
    // Doldurulmamış gün nötr dolguda — bir sonraki tona benzemiyor.
    expect(_cellDecoration(tester, 3).color, _colors.fillSubtle);

    // Bugünün çerçevesi seviyesinden bağımsız.
    expect(_cellDecoration(tester, 17).border, isNotNull);
    expect(_cellDecoration(tester, 16).border, isNull);

    // Başlık, toplam ve ölçek. Toplam iki kez: seansların hepsi eylülde, yani
    // yıl şeridinin toplamı da aynı sayı (biri ızgaranın başlığında, biri
    // şeridinkinde). Efsane **tek** — ikisine birden hizmet ediyor.
    expect(find.text('BU AY'), findsOneWidget);
    expect(find.text('SON 52 HAFTA'), findsOneWidget);
    expect(find.text('3 saat 40 dakika'), findsNWidgets(2));
    expect(find.text('az'), findsOneWidget);
    expect(find.text('çok'), findsOneWidget);
    // Gün başlıkları bar chart'ın ARB kataloğundan.
    expect(find.text('Pzt'), findsOneWidget);
    expect(find.text('Paz'), findsOneWidget);

    // Şeridin cümlesi ızgaranınkinin hemen ardından — görsel sıra. Seansların
    // hepsi eylülde, yani 52 haftalık pencerenin de içinde: iki cümlenin
    // sayıları burada bilerek aynı.
    expect(
      find.bySemanticsLabel(
        'Bu ay 30 günün 4 gününde odaklandın, toplam 3 saat 40 dakika. '
        'Son 52 haftanın 4 gününde odaklandın, toplam 3 saat 40 dakika.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('boş ay: ızgara çiziliyor, toplam metni yazılmıyor', (WidgetTester tester) async {
    await _pumpCard(tester, const <PomodoroSession>[]);

    expect(find.byKey(heatmapDayCellKey(1)), findsOneWidget);
    expect(find.byKey(heatmapDayCellKey(30)), findsNothing);
    expect(find.text('BU AY'), findsOneWidget);
    // "0 dakika" ölçen bir ton olurdu (haftalık kapanış kartıyla aynı gerekçe).
    expect(find.textContaining('dakika'), findsNothing);
    expect(
      find.bySemanticsLabel('Bu ay henüz odak yok. Son 52 haftada henüz odak yok.'),
      findsOneWidget,
    );

    // Yaşanmış günlerin hepsi boş dolguda; bugün yine çerçeveli.
    expect(_cellDecoration(tester, 1).color, _colors.fillSubtle);
    expect(_cellDecoration(tester, 17).color, _colors.fillSubtle);
    expect(_cellDecoration(tester, 17).border, isNotNull);
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
      find.bySemanticsLabel(
        'Bu ay 30 günün 17 gününde odaklandın, toplam 42 saat 30 dakika. '
        'Son 52 haftanın 17 gününde odaklandın, toplam 42 saat 30 dakika.',
      ),
      findsOneWidget,
    );
  });

  group('ay gezinme (madde 35)', () {
    testWidgets('geçmiş ay: başlık ay adını yazıyor, ızgara ay sonuna kadar dolu',
        (WidgetTester tester) async {
      await _pumpCard(
        tester,
        <PomodoroSession>[_august(3, minutes: 45)],
        monthOffset: -1,
      );

      expect(find.text('Ağustos 2026'), findsOneWidget);
      expect(find.text('BU AY'), findsNothing);
      // Ağustos 31 günlük ve tamamı yaşandı: hiçbir hücre gelecek değil.
      for (int day = 1; day <= 31; day++) {
        expect(find.byKey(heatmapDayCellKey(day)), findsOneWidget, reason: '$day. gün hücresi');
      }
      // Bugün çerçevesi yalnızca içinde bulunulan ayın işareti; geçmiş ayın
      // son gününe çizilseydi 31 Ağustos "bugün" gibi okunurdu.
      for (int day = 1; day <= 31; day++) {
        expect(_cellDecoration(tester, day).border, isNull, reason: '$day. günün çerçevesi');
      }
      expect(_cellDecoration(tester, 3).color, heatmapLevelColor(_colors, 2));
    });

    testWidgets('geri ok adımı bildiriyor, ileri ok bu ayda çalışmıyor',
        (WidgetTester tester) async {
      final List<int> steps = <int>[];
      await _pumpCard(
        tester,
        <PomodoroSession>[_august(3), _september(10)],
        onMonthStep: steps.add,
      );

      await tester.tap(find.byKey(heatmapPrevMonthKey));
      expect(steps, <int>[-1]);

      // Gelecek aya gezinme yok: yaşanmamış gün gösterilmiyor.
      await tester.tap(find.byKey(heatmapNextMonthKey));
      expect(steps, <int>[-1]);

      expect(find.bySemanticsLabel('Önceki ay'), findsOneWidget);
      expect(find.bySemanticsLabel('Sonraki ay'), findsOneWidget);
    });

    testWidgets('geçmiş ayda ileri ok çalışıyor', (WidgetTester tester) async {
      final List<int> steps = <int>[];
      await _pumpCard(
        tester,
        <PomodoroSession>[_august(3)],
        monthOffset: -1,
        onMonthStep: steps.add,
      );

      await tester.tap(find.byKey(heatmapNextMonthKey));
      expect(steps, <int>[1]);
      // Ağustostan öncesinde seans yok → geri ok kapalı.
      await tester.tap(find.byKey(heatmapPrevMonthKey));
      expect(steps, <int>[1]);
    });

    testWidgets('daha eski seans yokken geri ok çalışmıyor', (WidgetTester tester) async {
      final List<int> steps = <int>[];
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(10)],
        onMonthStep: steps.add,
      );

      await tester.tap(find.byKey(heatmapPrevMonthKey));
      expect(steps, isEmpty);
    });
  });

  group('özet cümlesinin ayı (madde 40)', () {
    testWidgets('geçmiş ayda cümle ay adını söylüyor', (WidgetTester tester) async {
      await _pumpCard(
        tester,
        <PomodoroSession>[_august(3, minutes: 45)],
        monthOffset: -1,
      );

      // Gören kullanıcı başlıktan ağustosa baktığını biliyor; ekran okuyucu
      // kullanıcısı yalnızca bu cümleden biliyor — üstelik gezinme okları
      // onun da kullanabildiği iki durak (madde 35).
      expect(
        find.bySemanticsLabel(
          'Ağustos 2026: 31 günün 1 gününde odaklandın, toplam 45 dakika. '
          'Son 52 haftanın 1 gününde odaklandın, toplam 45 dakika.',
        ),
        findsOneWidget,
      );
      // "Bu ay" hiçbir durakta geçmiyor: başlık da ay adına çevrilmişti.
      expect(find.bySemanticsLabel(RegExp('Bu ay')), findsNothing);
    });

    testWidgets('boş geçmiş ayda da ay adını söylüyor', (WidgetTester tester) async {
      // Seanslar eylülde: ağustos boş, şerit dolu.
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(10)],
        monthOffset: -1,
      );

      expect(
        find.bySemanticsLabel(
          'Ağustos 2026: henüz odak yok. '
          'Son 52 haftanın 1 gününde odaklandın, toplam 25 dakika.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Bu ay')), findsNothing);
    });

    testWidgets('içinde bulunulan ay "Bu ay" demeye devam ediyor',
        (WidgetTester tester) async {
      await _pumpCard(tester, <PomodoroSession>[_september(10)]);

      // Bugünün ayında ay adı yazmak, başlığın `BU AY` demesiyle çelişirdi.
      expect(
        find.bySemanticsLabel(
          'Bu ay 30 günün 1 gününde odaklandın, toplam 25 dakika. '
          'Son 52 haftanın 1 gününde odaklandın, toplam 25 dakika.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('Eylül')), findsNothing);
    });
  });

  group('gün seçimi (madde 35)', () {
    testWidgets('hücreye dokunmak o günü bildiriyor', (WidgetTester tester) async {
      final List<HeatmapDay> tapped = <HeatmapDay>[];
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(9, minutes: 100)],
        onDayTap: tapped.add,
      );

      await tester.tap(find.byKey(heatmapDayCellKey(9)));
      expect(tapped.single.dayKey, DateTime.utc(2026, 9, 9));
      expect(tapped.single.minutes, 100);

      // Odaksız gün de seçilebiliyor: "o gün hiç çalışmamışım" da bir cevap.
      await tester.tap(find.byKey(heatmapDayCellKey(3)));
      expect(tapped.last.dayKey, DateTime.utc(2026, 9, 3));
      expect(tapped, hasLength(2));
    });

    testWidgets('seçili gün efsane satırında ve özet cümlesinde', (WidgetTester tester) async {
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(9, minutes: 100)],
        selectedDay: DateTime.utc(2026, 9, 9),
      );

      expect(find.text('9 Eyl • 1sa 40dk'), findsOneWidget);
      // Ay toplamı yerinde duruyor: seçim onun yerine geçmiyor. İki kez
      // bulunuyor çünkü tek seans eylülde, yani yıl şeridinin toplamı da aynı
      // sayı — biri ızgaranın başlığında, biri şeridin başlığında.
      expect(find.text('1 saat 40 dakika'), findsNWidgets(2));
      expect(
        find.bySemanticsLabel(
          'Bu ay 30 günün 1 gününde odaklandın, toplam 1 saat 40 dakika. '
          'Son 52 haftanın 1 gününde odaklandın, toplam 1 saat 40 dakika. '
          'Seçili gün 9 Eyl: 1 saat 40 dakika.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('odaksız seçili gün sayı uydurmuyor', (WidgetTester tester) async {
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(9, minutes: 100)],
        selectedDay: DateTime.utc(2026, 9, 3),
      );

      expect(find.text('3 Eyl • odak yok'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Bu ay 30 günün 1 gününde odaklandın, toplam 1 saat 40 dakika. '
          'Son 52 haftanın 1 gününde odaklandın, toplam 1 saat 40 dakika. '
          'Seçili gün 3 Eyl: odak yok.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('seçim çerçevesi bugünün çerçevesinden ayrı ve onu yeniyor',
        (WidgetTester tester) async {
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(9, minutes: 100)],
        selectedDay: DateTime.utc(2026, 9, 9),
      );

      expect(_cellDecoration(tester, 9).border!.top.color, _colors.text);
      // Bugün seçili değilken kendi ember çerçevesinde.
      expect(_cellDecoration(tester, 17).border!.top.color, _colors.ember);
    });

    testWidgets('bugün seçilince seçim kazanıyor', (WidgetTester tester) async {
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(9, minutes: 100)],
        selectedDay: DateTime.utc(2026, 9, 17),
      );

      expect(_cellDecoration(tester, 17).border!.top.color, _colors.text);
    });
  });

  group('yıl şeridi (madde 37)', () {
    testWidgets('gelecek günler dışında her gün bir hücre', (WidgetTester tester) async {
      await _pumpCard(tester, <PomodoroSession>[_september(9, minutes: 100)]);

      // 17 Eylül 2026 perşembe: haftanın cuma/cumartesi/pazarı henüz
      // yaşanmadı, yani 364 günün 361'i çiziliyor.
      expect(_drawnYearCells(tester), 361);
      expect(find.byKey(heatmapYearCellKey(0)), findsOneWidget);
      expect(find.byKey(heatmapYearCellKey(363)), findsNothing);
    });

    testWidgets('şeridin son çizilen hücresi bugün', (WidgetTester tester) async {
      await _pumpCard(tester, <PomodoroSession>[_september(17, minutes: 120)]);

      // Bugünün indeksi: 364 − 4 = 360 (pazar 363, perşembe 360).
      const int todayIndex = 360;
      expect(find.byKey(heatmapYearCellKey(todayIndex)), findsOneWidget);
      expect(find.byKey(heatmapYearCellKey(todayIndex + 1)), findsNothing);

      // Bugünün hücresi en üst seviyede ve **çerçevesiz**: şeritte bugün
      // işareti yok, çünkü son çizilen hücre zaten bugün.
      final BoxDecoration decoration = _yearCellDecoration(tester, todayIndex);
      expect(decoration.color, heatmapLevelColor(_colors, kHeatmapLevels));
      expect(decoration.border, isNull);
    });

    testWidgets('seviyeler aylık ızgarayla aynı rampadan', (WidgetTester tester) async {
      await _pumpCard(tester, <PomodoroSession>[_september(16, minutes: 120)]);

      // 16 Eylül çarşamba, bugünden (perşembe) bir gün önce → indeks 359.
      expect(_yearCellDecoration(tester, 359).color, _cellDecoration(tester, 16).color);
      expect(_yearCellDecoration(tester, 359).color, heatmapLevelColor(_colors, kHeatmapLevels));
    });

    testWidgets('boş gün nötr dolguda, şerit boş pencerede de çiziliyor',
        (WidgetTester tester) async {
      await _pumpCard(tester, const <PomodoroSession>[]);

      expect(_drawnYearCells(tester), 361);
      expect(_yearCellDecoration(tester, 0).color, _colors.fillSubtle);
      expect(find.text('SON 52 HAFTA'), findsOneWidget);
      // Toplam boş pencerede yazılmıyor — ay toplamıyla aynı gerekçe.
      expect(find.textContaining('dakika'), findsNothing);
    });

    testWidgets('şerit dokunmayı karşılamıyor', (WidgetTester tester) async {
      final List<HeatmapDay> tapped = <HeatmapDay>[];
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(9, minutes: 100)],
        onDayTap: tapped.add,
      );

      // Aylık hücre `onDayTap`i tetikliyor…
      await tester.tap(find.byKey(heatmapDayCellKey(9)));
      await tester.pump();
      expect(tapped, hasLength(1));

      // …şeridin hücresi tetiklemiyor: 4.2dp dokunma hedefi olamaz, o yüzden
      // jest ağacı hiç kurulmuyor.
      await tester.tap(find.byKey(heatmapYearCellKey(0)), warnIfMissed: false);
      await tester.pump();
      expect(tapped, hasLength(1));
    });

    testWidgets('ay gezinince şerit değişmiyor', (WidgetTester tester) async {
      await _pumpCard(
        tester,
        <PomodoroSession>[_september(9, minutes: 100), _august(3, minutes: 50)],
        monthOffset: -1,
      );

      // Izgara ağustosta ama pencere sabit: şerit yine 361 hücre ve toplamı
      // iki ayın toplamı (1sa 40dk + 50dk = 2 saat 30 dakika).
      expect(_drawnYearCells(tester), 361);
      expect(find.text('2 saat 30 dakika'), findsOneWidget);
      // Buradaki iddia şeridin cümlesi: ay gezinse de sayıları değişmiyor.
      // Izgaranınki ağustosa geçti (madde 40), şeridinki iki ayın toplamında.
      expect(
        find.bySemanticsLabel(
          'Ağustos 2026: 31 günün 1 gününde odaklandın, toplam 50 dakika. '
          'Son 52 haftanın 2 gününde odaklandın, toplam 2 saat 30 dakika.',
        ),
        findsOneWidget,
      );
    });
  });
}
