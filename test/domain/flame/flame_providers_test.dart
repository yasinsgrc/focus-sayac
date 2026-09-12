import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/flame/flame_providers.dart';
import 'package:focussayac/domain/flame/flame_tier.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// [count] saatlik tamamlanmış odak geçmişi.
List<PomodoroSession> _hours(int count) => <PomodoroSession>[
      for (int i = 0; i < count; i++)
        PomodoroSession(
          id: i + 1,
          type: SessionType.focus,
          startedAt: DateTime.utc(2026, 3, 1 + i ~/ 3, 6 + i % 3),
          plannedDurationSec: 3600,
          completed: true,
          breakExtensions: 0,
        ),
    ];

/// `Stream.value` tek abonelikli: yayın denetleyicisinin aksine Riverpod geç
/// abone olsa da olayı düşürmüyor (`streak_protection_badge_test.dart` tuzağı).
///
/// `container.listen` burada zorunlu: Riverpod 3.1'de hiçbir dinleyici yokken
/// `container.read(allSessionsProvider.future)` asla tamamlanmıyor (element
/// inşa ediliyor ama tamamlayıcıya bağlanmıyor) — 30 saniyelik test zaman
/// aşımıyla doğrulandı. Dinleyici, akışın senkron olarak henüz teslim
/// edilmediği anı (yüklenme durumu, 3. test) değiştirmiyor: `Stream.value`
/// değeri yine de bir mikro görevle geliyor.
ProviderContainer _containerWith(List<PomodoroSession> sessions) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      allSessionsProvider.overrideWith((Ref ref) => Stream<List<PomodoroSession>>.value(sessions)),
    ],
  );
  addTearDown(container.dispose);
  container.listen(allSessionsProvider, (_, _) {});
  return container;
}

void main() {
  test('geçmiş boşken K1', () async {
    final ProviderContainer container = _containerWith(const <PomodoroSession>[]);
    await container.read(allSessionsProvider.future);
    expect(container.read(flameTierProvider).tier.index, 1);
  });

  test('62 saatlik geçmiş K6, sonraki kademeye 38 saat', () async {
    final ProviderContainer container = _containerWith(_hours(62));
    await container.read(allSessionsProvider.future);

    final FlameTierStatus status = container.read(flameTierProvider);
    expect(status.tier.index, 6);
    expect(status.cumulativeHours, 62);
    expect(status.hoursRemaining, 38);
  });

  test('akış yüklenirken K1e düşüyor, patlamıyor', () {
    // `allSessionsProvider` ilk değerini yayınlamadan okunursa ekran yine de
    // çizilebilmeli — `focusStatsProvider`ın `?? const []` davranışı.
    final ProviderContainer container = _containerWith(_hours(62));
    expect(container.read(flameTierProvider).tier.index, 1);
  });
}
