import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stats/stats_providers.dart';
import 'flame_tier.dart';

/// Meşale avatarının o anki kademesi. `focusStatsProvider`ı okuyor, yani
/// Ekran 04, Ekran 03 ve widget anlık görüntüsü aynı `allSessionsProvider`
/// akışından besleniyor — üç yüzeyin sayısı birbirinden sapamaz.
final Provider<FlameTierStatus> flameTierProvider = Provider<FlameTierStatus>((Ref ref) {
  return flameTierFor(ref.watch(focusStatsProvider).cumulativeSeconds);
});
