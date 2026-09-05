import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/exams/exam_accent.dart';
import '../../domain/exams/exam_providers.dart';
import '../../domain/pomodoro/pomodoro_controller.dart';
import '../../domain/pomodoro/pomodoro_phase.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import '../../domain/stats/focus_stats.dart';
import '../../domain/stats/stats_providers.dart';
import '../../domain/widgets/home_widget_snapshot.dart';
import '../storage/app_database.dart';
import 'home_widget_service.dart';

final Provider<HomeWidgetService> homeWidgetServiceProvider =
    Provider<HomeWidgetService>((Ref ref) => const HomeWidgetService());

/// Widget'lara yazılacak anlık görüntü. Aktif sınav akışı ilk değerini
/// yayınlamadan `null` kalır — yükleniyorken yazmak, widget'ın bir an için
/// "sınav seç" durumuna düşüp geri dönmesine yol açardı.
final Provider<HomeWidgetSnapshot?> homeWidgetSnapshotProvider =
    Provider<HomeWidgetSnapshot?>((Ref ref) {
  final AsyncValue<Exam?> activeExam = ref.watch(activeExamProvider);
  if (!activeExam.hasValue) return null;

  final FocusStats stats = ref.watch(focusStatsProvider);
  final TodayFocusStats today = ref.watch(todayFocusStatsProvider);
  final int streak = ref.watch(streakProvider);
  final PomodoroPhase phase = ref.watch(pomodoroControllerProvider);
  final DateTime nowUtc = DateTime.now().toUtc();

  final List<int> weeklyMinutes =
      stats.lastWeek.map((DailyFocus day) => day.minutes).toList(growable: false);
  final bool sessionActive = phase is! PomodoroIdle;
  final int todayMinutes = today.totalSeconds ~/ 60;

  final Exam? exam = activeExam.value;
  if (exam == null) {
    return HomeWidgetSnapshot.noExam(
      streak: streak,
      todayMinutes: todayMinutes,
      weeklyMinutes: weeklyMinutes,
      sessionActive: sessionActive,
      updatedAtUtc: nowUtc,
    );
  }

  return HomeWidgetSnapshot(
    examName: exam.name,
    examSubtitle: exam.subtitle,
    targetUtc: examTargetUtc(exam),
    // Widget'lar Flutter tema agacinin disinda, sistem temasini izliyor
    // (`FocusPalette` + `values-night`). Uygulama ici "Acik/Koyu" secimi burada
    // yanlis cevap olurdu: kullanici koyu secse bile launcher acik kalabilir.
    accentColor: examAccentColor(exam.accentRole, _systemPalette()),
    streak: streak,
    todayMinutes: todayMinutes,
    weeklyMinutes: weeklyMinutes,
    sessionActive: sessionActive,
    updatedAtUtc: nowUtc,
  );
});

/// Cihazın o anki sistem teması. Sağlayıcının `BuildContext`i yok, bu yüzden
/// `MediaQuery` yerine doğrudan platformdan okunuyor — zaten istenen de
/// uygulama içi tercih değil, launcher'ın gördüğü tema.
AppColors _systemPalette() {
  return PlatformDispatcher.instance.platformBrightness == Brightness.dark
      ? AppColors.dark()
      : AppColors.light();
}

/// `Exam.dateUtc` günü, `Exam.timeOfDay` ("HH:mm") saati taşır — geri sayım
/// ekranı ikisini birlikte kullanır, widget'ın da aynı anı görmesi gerekir.
/// Saat alanı bozuksa günün başlangıcına düşülür: widget'ın hiç çizilmemesi,
/// bir saat kayması göstermesinden daha kötü olurdu.
DateTime examTargetUtc(Exam exam) {
  final List<String> parts = exam.timeOfDay.split(':');
  final int hour = parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0;
  final int minute = parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime.utc(
    exam.dateUtc.year,
    exam.dateUtc.month,
    exam.dateUtc.day,
    hour,
    minute,
  );
}

/// Anlık görüntü her değiştiğinde widget'ları tazeleyen görünmez bileşen.
/// Tek işi dinlemek; hiçbir şey çizmez, [child]'ı olduğu gibi geçirir.
class HomeWidgetSyncScope extends ConsumerStatefulWidget {
  const HomeWidgetSyncScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<HomeWidgetSyncScope> createState() => _HomeWidgetSyncScopeState();
}

class _HomeWidgetSyncScopeState extends ConsumerState<HomeWidgetSyncScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ilk itis burada: `ref.listen` yalnizca DEGISIMDE tetikleniyor, acilista
    // zaten dogru olan bir anlik goruntu hic yazilmadan kalirdi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _push(ref.read(homeWidgetSnapshotProvider));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Öne dönüşte bir kez daha it: arka planda geçen sürede gün dönmüş
    // olabilir ve bunu tetikleyecek bir provider olayı olmayabilir.
    if (state == AppLifecycleState.resumed) {
      _push(ref.read(homeWidgetSnapshotProvider));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _push(HomeWidgetSnapshot? snapshot) {
    if (snapshot == null) return;
    unawaited(ref.read(homeWidgetServiceProvider).push(snapshot));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HomeWidgetSnapshot?>(
      homeWidgetSnapshotProvider,
      (HomeWidgetSnapshot? previous, HomeWidgetSnapshot? next) => _push(next),
    );
    return widget.child;
  }
}
