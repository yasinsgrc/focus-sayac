import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/widgets/flame_widget.dart';
import 'package:focussayac/domain/badges/badge_providers.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/features/badges/badges_screen.dart';
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

Future<void> _pumpBadges(WidgetTester tester, {required List<PomodoroSession> sessions}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSessionsProvider.overrideWith((Ref ref) => Stream<List<PomodoroSession>>.value(sessions)),
        unlockedBadgesProvider.overrideWith((Ref ref) => Stream<List<UserBadge>>.value(const <UserBadge>[])),
      ],
      child: localizedTestApp(const BadgesScreen()),
    ),
  );
  // Kart durağan olduğu için `pumpAndSettle` burada takılmamalı — bu testin
  // sessiz ikinci işlevi tam olarak bunu doğrulamak.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('62 saatte K6 kartı, sayaç ve kalan saat', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(62));

    expect(find.text('Ocak'), findsOneWidget);
    expect(find.text('62 / 100 sa'), findsOneWidget);
    expect(find.text('Sonraki kademeye 38 saat'), findsOneWidget);
    expect(find.byType(FlameWidget), findsOneWidget);
  });

  testWidgets('geçmiş boşken K1 kartı çiziliyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: const <PomodoroSession>[]);

    expect(find.text('Kıvılcım'), findsOneWidget);
    expect(find.text('0 / 1 sa'), findsOneWidget);
    expect(find.text('Sonraki kademeye 1 saat'), findsOneWidget);
  });

  testWidgets('en üst kademede kalan saat yerine "En üst kademe"',
      (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(420));

    expect(find.text('Güneş'), findsOneWidget);
    expect(find.text('En üst kademe'), findsOneWidget);
    expect(find.textContaining('Sonraki kademeye'), findsNothing);
  });

  testWidgets('karttaki alev titremiyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(62));
    expect(tester.widget<FlameWidget>(find.byType(FlameWidget)).flickering, isFalse);
  });

  testWidgets('rozet ızgarası bozulmadan duruyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(62));
    // Kart eklendikten sonra ızgaranın kendisinin hâlâ çizildiğini doğrular:
    // ilk kataloğun kilitli/açık durumdan bağımsız her zaman gösterdiği ad
    // metni. Kart ızgarayı ekran dışına itseydi ya da ızgara hiç çizilmeseydi
    // bu bulunamazdı.
    expect(find.text('İlk Kıvılcım'), findsOneWidget);
    // "ROZETLER" iki kopya bekliyor: sayfa başlığı ve alt gezinme çubuğunun
    // aktif hapı — ikisi de aynı `badgesTitle` dizesini kullanıyor. Bu satır
    // ızgarayı değil, üçüncü bir kopyanın sessizce sızmadığını koruyor.
    expect(find.text('ROZETLER'), findsNWidgets(2));
  });
}
