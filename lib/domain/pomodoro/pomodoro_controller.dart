import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/notifications/notification_service.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_enums.dart';
import '../../services/storage/storage_providers.dart';
import '../badges/badge_providers.dart';
import '../exams/exam_providers.dart';
import 'pomodoro_math.dart';
import 'pomodoro_phase.dart';
import 'pomodoro_stats_providers.dart';

/// Kalıcı faz kaydının `SharedPreferences` anahtarı — SPEC.md DoD "Uygulama
/// öldürülüp açıldığında aktif seans kurtarılıyor" gereği.
const String kPomodoroPhasePrefsKey = 'pomodoro_active_phase_v1';

/// Molada en fazla kaç kez "5 dk ekle" kullanılabilir (SPEC.md Ekran 09).
const int kMaxBreakExtensions = 2;

final NotifierProvider<PomodoroController, PomodoroPhase> pomodoroControllerProvider =
    NotifierProvider<PomodoroController, PomodoroPhase>(PomodoroController.new);

/// Pomodoro durum makinesinin tek sahibi — SPEC.md §5.2. Faz geçişlerini
/// yönetir, her geçişte `PomodoroSessionDao`'ya yazar ve aktif fazı
/// `SharedPreferences`'a yansıtır (soğuk başlangıç kurtarması için).
///
/// Zaman her zaman `phaseRemaining`/`phaseProgress` ile `startedAtUtc`'den
/// hesaplanır (SPEC §5.1) — bu sınıf hiçbir yerde azalan bir sayaç tutmaz.
/// Ekranlar canlı saniye görüntüsü için kendi yerel `Timer.periodic`'ini
/// tutar (Ekran 02'nin Faz 4'te kurduğu kalıpla aynı) ve her tikte bu
/// controller'ın [tick] metodunu çağırır; bu metot yalnızca "tamamlandı mı"
/// kontrolü yapar, ekranın kendi görsel yenilemesi ekranın sorumluluğudur.
class PomodoroController extends Notifier<PomodoroPhase> {
  DateTime? _lastCheckedNowUtc;
  bool _ticking = false;

  @override
  PomodoroPhase build() {
    final PomodoroPhase restored = _restoreFromPrefs() ?? const PomodoroPhase.idle();
    _lastCheckedNowUtc = DateTime.now().toUtc();
    return restored;
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  NotificationService get _notifications => ref.read(notificationServiceProvider);

  PomodoroPhase? _restoreFromPrefs() {
    final String? raw = _prefs.getString(kPomodoroPhasePrefsKey);
    if (raw == null) return null;
    try {
      final Map<String, Object?> json = jsonDecode(raw) as Map<String, Object?>;
      return _decodePhase(json);
    } on FormatException {
      return null;
    }
  }

  Future<void> _persist() async {
    final Map<String, Object?>? json = _encodePhase(state);
    if (json == null) {
      await _prefs.remove(kPomodoroPhasePrefsKey);
    } else {
      await _prefs.setString(kPomodoroPhasePrefsKey, jsonEncode(json));
    }
  }

  Future<void> _clearPersisted() => _prefs.remove(kPomodoroPhasePrefsKey);

  Future<bool> _hapticEnabled() async {
    final AppSettingsTableData settings = await ref.read(appSettingsDaoProvider).getSettings();
    return settings.hapticEnabled;
  }

  Future<void> _haptic() async {
    if (await _hapticEnabled()) {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  /// Ekran 02'nin "25 DAKİKA ODAKLAN" butonu. Yalnızca `idle`'dan çağrılabilir.
  Future<void> startFocus() async {
    if (state is! PomodoroIdle) return;
    final AppSettingsTableData settings = await ref.read(appSettingsDaoProvider).getSettings();
    final Exam? exam = ref.read(activeExamProvider).value;
    final TodayFocusStats stats = ref.read(todayFocusStatsProvider);
    final int completedInCycle = stats.completedCount % 4;
    final int cyclePosition = completedInCycle + 1;
    final DateTime startedAt = DateTime.now().toUtc();
    final int plannedSec = settings.focusMinutes * 60;
    final int sessionId = await ref.read(pomodoroSessionDaoProvider).startSession(
          examId: exam?.id,
          type: SessionType.focus,
          startedAt: startedAt,
          plannedDurationSec: plannedSec,
        );
    state = PomodoroPhase.focusRunning(
      sessionId: sessionId,
      examId: exam?.id,
      startedAtUtc: startedAt,
      plannedDurationSec: plannedSec,
      cyclePosition: cyclePosition,
    );
    _lastCheckedNowUtc = startedAt;
    await _persist();
    final int breakMinutes =
        isLongBreakFor(cyclePosition) ? settings.longBreakMinutes : settings.shortBreakMinutes;
    await _notifications.scheduleFocusSessionEnd(
      endAtUtc: startedAt.add(Duration(seconds: plannedSec)),
      focusMinutes: settings.focusMinutes,
      breakMinutes: breakMinutes,
    );
    await _notifications.showOngoingFocus(cyclePosition: cyclePosition);
    await _haptic();
  }

  /// Oynat/duraklat düğmesi — yalnızca odak fazında var (Ekran 03).
  Future<void> togglePause() async {
    final PomodoroPhase current = state;
    if (current is PomodoroFocusRunning) {
      final DateTime now = DateTime.now().toUtc();
      final Duration remaining = phaseRemaining(
        startedAtUtc: current.startedAtUtc,
        plannedDurationSec: current.plannedDurationSec,
        nowUtc: now,
      );
      state = PomodoroPhase.focusPaused(
        sessionId: current.sessionId,
        examId: current.examId,
        startedAtUtc: current.startedAtUtc,
        plannedDurationSec: current.plannedDurationSec,
        cyclePosition: current.cyclePosition,
        remainingAtPause: remaining,
      );
      await _persist();
      await _notifications.cancelFocusSessionEnd();
      await _notifications.cancelOngoingFocus();
      await _haptic();
      return;
    }
    if (current is PomodoroFocusPaused) {
      final DateTime now = DateTime.now().toUtc();
      final DateTime virtualStart = resumeVirtualStart(
        nowUtc: now,
        plannedDurationSec: current.plannedDurationSec,
        remainingAtPause: current.remainingAtPause,
      );
      state = PomodoroPhase.focusRunning(
        sessionId: current.sessionId,
        examId: current.examId,
        startedAtUtc: virtualStart,
        plannedDurationSec: current.plannedDurationSec,
        cyclePosition: current.cyclePosition,
      );
      _lastCheckedNowUtc = now;
      await _persist();
      final AppSettingsTableData settings = await ref.read(appSettingsDaoProvider).getSettings();
      final int breakMinutes = isLongBreakFor(current.cyclePosition)
          ? settings.longBreakMinutes
          : settings.shortBreakMinutes;
      await _notifications.scheduleFocusSessionEnd(
        endAtUtc: virtualStart.add(Duration(seconds: current.plannedDurationSec)),
        focusMinutes: settings.focusMinutes,
        breakMinutes: breakMinutes,
      );
      await _notifications.showOngoingFocus(cyclePosition: current.cyclePosition);
      await _haptic();
    }
  }

  /// Ekran 03'ün "X" düğmesi → Ekran 10 onayından sonra çağrılır. Seans
  /// `completed = false` ile kapanır; rozet/seri sayılmaz (SPEC Ekran 10).
  Future<void> cancelFocusSession() async {
    final PomodoroPhase current = state;
    final int? sessionId = switch (current) {
      final PomodoroFocusRunning r => r.sessionId,
      final PomodoroFocusPaused p => p.sessionId,
      _ => null,
    };
    if (sessionId == null) return;
    await ref.read(pomodoroSessionDaoProvider).finishSession(
          id: sessionId,
          completed: false,
          endedAt: DateTime.now().toUtc(),
        );
    state = const PomodoroPhase.idle();
    await _clearPersisted();
    await _notifications.cancelFocusSessionEnd();
    await _notifications.cancelOngoingFocus();
    await _haptic();
  }

  /// Ekran 09'un "ODAĞA DÖN" düğmesi — molayı erken bitirir ve geri sayım
  /// ekranına döner (SPEC durum diyagramı: `breakCompleted → idle`; erken
  /// bitirme de aynı hedefe gider, yalnızca beklemeden).
  Future<void> endBreakEarly() async {
    final PomodoroPhase current = state;
    if (current is! PomodoroBreakRunning) return;
    await ref.read(pomodoroSessionDaoProvider).finishSession(
          id: current.sessionId,
          completed: false,
          endedAt: DateTime.now().toUtc(),
        );
    state = const PomodoroPhase.idle();
    await _clearPersisted();
    await _haptic();
  }

  /// Ekran 09'un "5 dk ekle" düğmesi — molada en fazla [kMaxBreakExtensions]
  /// kez kullanılabilir (SPEC.md Ekran 09).
  Future<void> extendBreak() async {
    final PomodoroPhase current = state;
    if (current is! PomodoroBreakRunning) return;
    if (current.extensionsUsed >= kMaxBreakExtensions) return;
    await ref.read(pomodoroSessionDaoProvider).incrementBreakExtension(current.sessionId);
    state = current.copyWith(
      plannedDurationSec: current.plannedDurationSec + (5 * 60),
      extensionsUsed: current.extensionsUsed + 1,
    );
    await _persist();
  }

  /// Ekranın yerel saniye tikleyicisinin her çağırdığı kontrol noktası:
  /// tamamlanmayı ve cihaz saati geri alma anomalisini yakalar.
  ///
  /// Tikleyici uygulama arka plandayken duruyor (Ekran 03) ve uygulama
  /// öldürülüp açıldığında hiç çalışmamış oluyor; bu yüzden tek bir tik
  /// gecikmeli gelebilir ve o aralıkta birden fazla fazın süresi dolmuş
  /// olabilir. Dolan fazlar burada sırayla, her biri kendi **planlanan bitiş
  /// anıyla** kapatılır — tikin geldiği anla değil. Böylece geç dönmek ne
  /// `completedAt`'i bozar ne de molayı sıfırdan, tam süreyle başlatır.
  Future<void> tick() async {
    // Gecikmeli bir yakalama tiki birkaç DB yazımı sürebiliyor; bu sırada
    // gelen bir sonraki saniye tiki aynı fazı ikinci kez tamamlamamalı.
    if (_ticking) return;
    _ticking = true;
    try {
      final DateTime now = DateTime.now().toUtc();
      final DateTime? last = _lastCheckedNowUtc;
      final PomodoroPhase current = state;
      final bool isRunningPhase = current is PomodoroFocusRunning || current is PomodoroBreakRunning;

      if (isRunningPhase && last != null && now.isBefore(last)) {
        // Cihaz saati geriye alındı: SPEC §5.1 — seans anında "tamamlanmış"
        // sayılmaz, completed=false ile kapatılır (bir sonraki now() okuması
        // ile tutarlı bir taban oluşturmak için de idle'a dönülür).
        _lastCheckedNowUtc = now;
        await _forceCancelForClockRollback(current, now);
        return;
      }
      _lastCheckedNowUtc = now;

      // Zincir en fazla iki geçiş sürer (odak → mola → idle): her adım ya
      // fazı tamamlayıp durumu ilerletir ya da döngüden çıkar.
      while (true) {
        final PomodoroPhase phase = state;
        switch (phase) {
          case final PomodoroFocusRunning r:
            final DateTime endsAtUtc = r.startedAtUtc.add(Duration(seconds: r.plannedDurationSec));
            if (now.isBefore(endsAtUtc)) return;
            await _completeFocus(r, endsAtUtc);
          case final PomodoroBreakRunning b:
            final DateTime endsAtUtc = b.startedAtUtc.add(Duration(seconds: b.plannedDurationSec));
            if (now.isBefore(endsAtUtc)) return;
            await _completeBreak(b, endsAtUtc);
          case PomodoroIdle _:
          case PomodoroFocusPaused _:
            return;
        }
      }
    } finally {
      _ticking = false;
    }
  }

  Future<void> _forceCancelForClockRollback(PomodoroPhase current, DateTime now) async {
    final int? sessionId = switch (current) {
      final PomodoroFocusRunning r => r.sessionId,
      final PomodoroBreakRunning b => b.sessionId,
      _ => null,
    };
    if (sessionId != null) {
      await ref.read(pomodoroSessionDaoProvider).finishSession(
            id: sessionId,
            completed: false,
            endedAt: now,
          );
    }
    if (current is PomodoroFocusRunning) {
      await _notifications.cancelFocusSessionEnd();
      await _notifications.cancelOngoingFocus();
    }
    state = const PomodoroPhase.idle();
    await _clearPersisted();
  }

  /// [endedAtUtc] odağın **planlanan bitiş anı**dır, tikin geldiği an değil
  /// (bkz. [tick]): mola da tam o andan itibaren başlatılır, aksi hâlde geç
  /// gelen bir tik molayı baştan ve tam süreyle kurardı.
  Future<void> _completeFocus(PomodoroFocusRunning r, DateTime endedAtUtc) async {
    await ref.read(pomodoroSessionDaoProvider).finishSession(
          id: r.sessionId,
          completed: true,
          endedAt: endedAtUtc,
        );
    await _notifications.cancelFocusSessionEnd();
    await _notifications.cancelOngoingFocus();
    final bool isLong = isLongBreakFor(r.cyclePosition);
    final AppSettingsTableData settings = await ref.read(appSettingsDaoProvider).getSettings();
    final int breakSec = (isLong ? settings.longBreakMinutes : settings.shortBreakMinutes) * 60;
    final int breakSessionId = await ref.read(pomodoroSessionDaoProvider).startSession(
          examId: r.examId,
          type: isLong ? SessionType.longBreak : SessionType.shortBreak,
          startedAt: endedAtUtc,
          plannedDurationSec: breakSec,
        );
    state = PomodoroPhase.breakRunning(
      sessionId: breakSessionId,
      examId: r.examId,
      isLong: isLong,
      startedAtUtc: endedAtUtc,
      plannedDurationSec: breakSec,
      cyclePosition: r.cyclePosition,
      extensionsUsed: 0,
    );
    await _persist();
    await _notifications.rescheduleStreakRiskReminder(completedToday: true, streak: ref.read(streakProvider));
    await ref.read(badgeUnlockServiceProvider).evaluateAfterFocusCompletion();
    await _haptic();
  }

  /// [endedAtUtc] molanın **planlanan bitiş anı**dır — bkz. [_completeFocus].
  Future<void> _completeBreak(PomodoroBreakRunning b, DateTime endedAtUtc) async {
    await ref.read(pomodoroSessionDaoProvider).finishSession(
          id: b.sessionId,
          completed: true,
          endedAt: endedAtUtc,
        );
    state = const PomodoroPhase.idle();
    await _clearPersisted();
    await _haptic();
  }
}

Map<String, Object?>? _encodePhase(PomodoroPhase phase) {
  return switch (phase) {
    PomodoroIdle _ => null,
    final PomodoroFocusRunning r => <String, Object?>{
        'type': 'focusRunning',
        'sessionId': r.sessionId,
        'examId': r.examId,
        'startedAtUtc': r.startedAtUtc.toIso8601String(),
        'plannedDurationSec': r.plannedDurationSec,
        'cyclePosition': r.cyclePosition,
      },
    final PomodoroFocusPaused p => <String, Object?>{
        'type': 'focusPaused',
        'sessionId': p.sessionId,
        'examId': p.examId,
        'startedAtUtc': p.startedAtUtc.toIso8601String(),
        'plannedDurationSec': p.plannedDurationSec,
        'cyclePosition': p.cyclePosition,
        'remainingAtPauseSec': p.remainingAtPause.inSeconds,
      },
    final PomodoroBreakRunning b => <String, Object?>{
        'type': 'breakRunning',
        'sessionId': b.sessionId,
        'examId': b.examId,
        'isLong': b.isLong,
        'startedAtUtc': b.startedAtUtc.toIso8601String(),
        'plannedDurationSec': b.plannedDurationSec,
        'cyclePosition': b.cyclePosition,
        'extensionsUsed': b.extensionsUsed,
      },
  };
}

PomodoroPhase? _decodePhase(Map<String, Object?> json) {
  final String? type = json['type'] as String?;
  switch (type) {
    case 'focusRunning':
      return PomodoroPhase.focusRunning(
        sessionId: json['sessionId']! as int,
        examId: json['examId'] as int?,
        startedAtUtc: DateTime.parse(json['startedAtUtc']! as String),
        plannedDurationSec: json['plannedDurationSec']! as int,
        cyclePosition: json['cyclePosition']! as int,
      );
    case 'focusPaused':
      return PomodoroPhase.focusPaused(
        sessionId: json['sessionId']! as int,
        examId: json['examId'] as int?,
        startedAtUtc: DateTime.parse(json['startedAtUtc']! as String),
        plannedDurationSec: json['plannedDurationSec']! as int,
        cyclePosition: json['cyclePosition']! as int,
        remainingAtPause: Duration(seconds: json['remainingAtPauseSec']! as int),
      );
    case 'breakRunning':
      return PomodoroPhase.breakRunning(
        sessionId: json['sessionId']! as int,
        examId: json['examId'] as int?,
        isLong: json['isLong']! as bool,
        startedAtUtc: DateTime.parse(json['startedAtUtc']! as String),
        plannedDurationSec: json['plannedDurationSec']! as int,
        cyclePosition: json['cyclePosition']! as int,
        extensionsUsed: json['extensionsUsed']! as int,
      );
    default:
      return null;
  }
}
