import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/app_day.dart';
import '../../services/storage/app_database.dart';
import '../pomodoro/pomodoro_stats_providers.dart';
import '../settings/settings_providers.dart';
import 'focus_stats.dart';
import 'weekly_goal.dart';
import 'weekly_summary.dart';

/// Ekran 06'nın (Faz 9) tüm sayıları. Ekran 02'nin `todayFocusStatsProvider`'ı
/// ile aynı `allSessionsProvider` akışını tüketir: iki ekranın sayıları tek
/// kaynaktan türediği için birbirinden sapamaz.
final Provider<FocusStats> focusStatsProvider = Provider<FocusStats>((Ref ref) {
  final List<PomodoroSession> sessions =
      ref.watch(allSessionsProvider).value ?? const <PomodoroSession>[];
  return calculateFocusStats(sessions: sessions, nowUtc: DateTime.now().toUtc());
});

/// Belirli bir sınav için biriken odak süresi (saniye) — Ekran 02'nin son
/// düzlükteki kahraman sayısı.
///
/// `activeExamProvider`'ı kendi içinde okumak yerine `examId` ile anahtarlanıyor:
/// tek çağıran zaten aktif sınavı elinde tutan `_CountdownBody`, ve bu yön
/// `domain/stats` → `domain/exams` bağımlılığını hiç kurmuyor.
///
/// Tip açıkça yazılmıyor (dosyadaki diğer sağlayıcıların aksine):
/// `flutter_riverpod` 3.1.0 `ProviderFamily`yi dışa vermiyor, yalnızca
/// `package:riverpod/misc.dart` veriyor. Çıkarım zaten `Provider.family`nin
/// açık `<int, int>` argümanlarından geliyor.
final examFocusSecondsProvider = Provider.family<int, int>((Ref ref, int examId) {
  final List<PomodoroSession> sessions =
      ref.watch(allSessionsProvider).value ?? const <PomodoroSession>[];
  return examFocusSeconds(sessions: sessions, examId: examId);
});

/// Haftalık kapanışın Ekran 06'da duran hâli — pencere **bugünle** bitiyor.
///
/// Pazar bildirimi aynı saf fonksiyonu hedef pazarla çağırıyor
/// (`NotificationService.rescheduleWeeklySummary` çağıranları); böylece iki
/// yüzey tek bir hesabı paylaşıyor ve bildirimde gördüğü sayıyı uygulamada
/// arayan kullanıcı başka bir sayı bulmuyor.
final Provider<WeeklySummary> weeklySummaryProvider = Provider<WeeklySummary>((Ref ref) {
  final List<PomodoroSession> sessions =
      ref.watch(allSessionsProvider).value ?? const <PomodoroSession>[];
  return calculateWeeklySummary(
    sessions: sessions,
    weekEndDayKey: currentAppDayKey(DateTime.now().toUtc()),
  );
});

/// Ekran 02'nin haftalık hedef satırı (ROADMAP madde 24).
///
/// Odak saniyesi **`weeklySummaryProvider`den** geliyor, seans listesinden
/// yeniden hesaplanmıyor: hedefin haftası ile Ekran 06'nın kartının ve pazar
/// bildiriminin haftası aynı pencere olmak zorunda, ve bunu sağlamanın en
/// güvenli yolu ikinci bir hesabın hiç var olmaması.
///
/// Ayar akışı ilk değerini yayınlamadan önce hedef **kapalı** sayılıyor
/// (`focusMinutesProvider`ın "süre bilinmiyorken sayı gösterme" gerekçesi):
/// satır o tek karede çizilmiyor, kullanıcının koymadığı bir hedefle dolu bir
/// çubuk gösterilmiyor.
final Provider<WeeklyGoalProgress> weeklyGoalProgressProvider =
    Provider<WeeklyGoalProgress>((Ref ref) {
  final int? goalMinutes = ref.watch(appSettingsProvider).value?.weeklyGoalMinutes;
  if (goalMinutes == null || goalMinutes <= 0) return WeeklyGoalProgress.off;
  return WeeklyGoalProgress(
    goalSeconds: goalMinutes * 60,
    focusedSeconds: ref.watch(weeklySummaryProvider).seconds,
  );
});
