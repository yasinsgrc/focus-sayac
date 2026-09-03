import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/app_database.dart';
import '../pomodoro/pomodoro_stats_providers.dart';
import 'focus_stats.dart';

/// Ekran 06'nın (Faz 9) tüm sayıları. Ekran 02'nin `todayFocusStatsProvider`'ı
/// ile aynı `allSessionsProvider` akışını tüketir: iki ekranın sayıları tek
/// kaynaktan türediği için birbirinden sapamaz.
final Provider<FocusStats> focusStatsProvider = Provider<FocusStats>((Ref ref) {
  final List<PomodoroSession> sessions =
      ref.watch(allSessionsProvider).value ?? const <PomodoroSession>[];
  return calculateFocusStats(sessions: sessions, nowUtc: DateTime.now().toUtc());
});
