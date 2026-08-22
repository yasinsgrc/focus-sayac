import 'package:freezed_annotation/freezed_annotation.dart';

part 'pomodoro_phase.freezed.dart';

/// Pomodoro durum makinesi — SPEC.md §5.2. Diyagram sekiz ad sayar
/// (`idle → focusRunning → focusPaused → focusCompleted → breakRunning →
/// breakPaused → breakCompleted → idle`); `focusCompleted`/`breakCompleted`
/// kendi başına render edilen bir ekrana sahip değil — tamamlanma (DB yazımı
/// + bir sonraki faza geçiş) `PomodoroController` içinde tek senkron adımda
/// olur, bu yüzden ayrı bir union üyesi olarak modellenmedi. `breakPaused` da
/// union'da yok: Ekran 09 prototipinde molayı duraklatan bir kontrol
/// bulunmuyor (yalnızca "5 dk ekle"/"ODAĞA DÖN"), hiç üretilmeyecek bir
/// durumu union'a eklemek SPEC.md §0 "basitlik" ilkesine aykırı düşerdi
/// (Faz 5 kararı — DECISIONS.md).
@freezed
sealed class PomodoroPhase with _$PomodoroPhase {
  const factory PomodoroPhase.idle() = PomodoroIdle;

  const factory PomodoroPhase.focusRunning({
    required int sessionId,
    required int? examId,
    required DateTime startedAtUtc,
    required int plannedDurationSec,
    required int cyclePosition,
  }) = PomodoroFocusRunning;

  const factory PomodoroPhase.focusPaused({
    required int sessionId,
    required int? examId,
    required DateTime startedAtUtc,
    required int plannedDurationSec,
    required int cyclePosition,
    required Duration remainingAtPause,
  }) = PomodoroFocusPaused;

  const factory PomodoroPhase.breakRunning({
    required int sessionId,
    required int? examId,
    required bool isLong,
    required DateTime startedAtUtc,
    required int plannedDurationSec,
    required int cyclePosition,
    required int extensionsUsed,
  }) = PomodoroBreakRunning;
}
