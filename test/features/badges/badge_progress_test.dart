import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/badges/badge_definition.dart';
import 'package:focussayac/domain/badges/badge_providers.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/features/badges/badges_screen.dart';
import 'package:focussayac/features/badges/widgets/badge_progress_ring_painter.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

import '../../support/localized_test_app.dart';

int _id = 0;

/// [count] saatlik tamamlanmış odak geçmişi — günde üç adet 60 dakikalık seans.
List<PomodoroSession> _hours(int count) => <PomodoroSession>[
      for (int i = 0; i < count; i++)
        PomodoroSession(
          id: ++_id,
          type: SessionType.focus,
          startedAt: DateTime.utc(2026, 3, 1 + i ~/ 3, 6 + i % 3),
          plannedDurationSec: 3600,
          completed: true,
          breakExtensions: 0,
        ),
    ];

/// Ekran 04'ü kontrollü bir geçmişle kaldırır. `Stream.value` tek abonelikli:
/// yayın (`broadcast`) denetleyicisinin aksine Riverpod geç abone olsa da olayı
/// düşürmüyor (`streak_protection_badge_test.dart`'taki tuzak).
Future<void> _pumpBadges(
  WidgetTester tester, {
  required List<PomodoroSession> sessions,
  List<UserBadge> unlocked = const <UserBadge>[],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      // `Override` tipi `flutter_riverpod` 3.1.0'da dışa verilmiyor; liste tipi
      // çıkarıma bırakılıyor (diğer ekran testlerindeki gibi).
      overrides: [
        allSessionsProvider.overrideWith((Ref ref) => Stream<List<PomodoroSession>>.value(sessions)),
        unlockedBadgesProvider.overrideWith((Ref ref) => Stream<List<UserBadge>>.value(unlocked)),
      ],
      child: localizedTestApp(const BadgesScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

/// Kilitli kartların halkaları — sayıları hangi kartların ilerleme gösterdiğini
/// söylüyor.
Iterable<BadgeProgressRingPainter> _rings(WidgetTester tester) {
  return tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((CustomPaint paint) => paint.painter)
      .whereType<BadgeProgressRingPainter>();
}

void main() {
  testWidgets('kilitli "100 saat" rozeti 61/100 ilerlemesini gösteriyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(61));

    // Kuralın istediği sayaç: kilitli rozet artık yalnızca kuralı yazmıyor.
    expect(find.text('61/100'), findsOneWidget);
    expect(find.text('61/250'), findsOneWidget);

    // Halka sayaçla aynı oranı taşıyor.
    final BadgeProgressRingPainter hundred =
        _rings(tester).firstWhere((BadgeProgressRingPainter r) => r.ratio > 0.6 && r.ratio < 0.62);
    expect(hundred.ratio, closeTo(0.61, 0.0001));
  });

  testWidgets('hedefe ulaşılmış basamak açık görünüyor — "61/10" gibi bir sayaç çıkmıyor',
      (WidgetTester tester) async {
    // DB'de hiç rozet yok (güncellemeden önce birikmiş emek) ama 61 saatlik
    // geçmiş merdivenin ilk iki basamağını zaten hak etmiş durumda.
    await _pumpBadges(tester, sessions: _hours(61));
    // `addTearDown` ile bırakılamıyor: çerçeve "tutamak sızdı" kontrolünü
    // tear-down'lardan **önce** yapıyor.
    final SemanticsHandle semantics = tester.ensureSemantics();

    expect(find.text('61/10'), findsNothing);
    expect(find.text('61/50'), findsNothing);
    // Üstteki sayaç `RollingNumber` içinde karakterlere bölündüğü için okunabilir
    // tek bütün anlamsal etiket. Dört rozet hak edilmiş durumda: İlk Kıvılcım,
    // Haftalık Seri (geçmiş 21 ardışık gün), 10 saat ve 50 saat.
    expect(find.bySemanticsLabel('4/${kBadgeCatalog.length}'), findsOneWidget);

    semantics.dispose();
  });

  testWidgets('halka yalnızca kilitli ve sayılabilir rozetlerde', (WidgetTester tester) async {
    await _pumpBadges(
      tester,
      sessions: _hours(61),
      unlocked: <UserBadge>[
        UserBadge(badgeKey: BadgeKeys.tenHours, unlockedAt: DateTime.utc(2026, 3, 20)),
      ],
    );

    final List<double> ratios = _rings(tester).map((BadgeProgressRingPainter r) => r.ratio).toList();
    // Halkalı olanlar yalnızca kilitli **ve** sayılabilir dördü: Odak Meşalesi
    // (3/4), Maraton (3/8), 100 Saat (61/100), 250 Saat (61/250). Sabah Yıldızı
    // / Gece Nöbeti / İlk Kıvılcım hedefi 1 olduğu için halkasız; Haftalık Seri,
    // 10 ve 50 saat ise açık olduğu için.
    expect(ratios, hasLength(4));
    expect(ratios.every((double r) => r < 1), isTrue, reason: 'dolmuş halka kilitli kartta durmaz');
  });

  testWidgets('geçmiş boşken merdiven boş halkalarla çiziliyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: const <PomodoroSession>[]);

    expect(find.text('0/100'), findsOneWidget);
    expect(find.text('0/250'), findsOneWidget);
    // Kilitli ve sayılabilir yedi rozetin hepsi ağaçta, hepsi sıfırda.
    expect(_rings(tester), hasLength(7));
    expect(_rings(tester).every((BadgeProgressRingPainter r) => r.ratio == 0), isTrue);
  });
}
