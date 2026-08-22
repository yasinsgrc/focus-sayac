import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_math.dart';

void main() {
  group('phaseRemaining', () {
    test('computes startedAt + planned - now', () {
      final DateTime startedAt = DateTime.utc(2026, 8, 22, 10, 0, 0);
      final DateTime now = startedAt.add(const Duration(minutes: 9, seconds: 36));
      final Duration remaining = phaseRemaining(startedAtUtc: startedAt, plannedDurationSec: 25 * 60, nowUtc: now);
      expect(remaining, const Duration(minutes: 15, seconds: 24));
    });

    test('never goes negative — clamps to zero once planned duration passes', () {
      final DateTime startedAt = DateTime.utc(2026, 8, 22, 10);
      final DateTime now = startedAt.add(const Duration(minutes: 40));
      final Duration remaining = phaseRemaining(startedAtUtc: startedAt, plannedDurationSec: 25 * 60, nowUtc: now);
      expect(remaining, Duration.zero);
    });
  });

  group('phaseProgress', () {
    test('0 at start, 1 once planned duration has fully elapsed', () {
      final DateTime startedAt = DateTime.utc(2026, 8, 22, 10);
      expect(phaseProgress(startedAtUtc: startedAt, plannedDurationSec: 600, nowUtc: startedAt), 0);
      expect(
        phaseProgress(startedAtUtc: startedAt, plannedDurationSec: 600, nowUtc: startedAt.add(const Duration(seconds: 600))),
        1,
      );
      expect(
        phaseProgress(startedAtUtc: startedAt, plannedDurationSec: 600, nowUtc: startedAt.add(const Duration(seconds: 1200))),
        1,
      );
    });

    test('halfway through planned duration is 0.5', () {
      final DateTime startedAt = DateTime.utc(2026, 8, 22, 10);
      final double progress = phaseProgress(
        startedAtUtc: startedAt,
        plannedDurationSec: 600,
        nowUtc: startedAt.add(const Duration(seconds: 300)),
      );
      expect(progress, closeTo(0.5, 1e-9));
    });
  });

  group('resumeVirtualStart', () {
    test('produces a startedAt that reproduces the paused remaining duration from now', () {
      final DateTime now = DateTime.utc(2026, 8, 22, 11);
      final DateTime virtualStart = resumeVirtualStart(
        nowUtc: now,
        plannedDurationSec: 25 * 60,
        remainingAtPause: const Duration(minutes: 15, seconds: 24),
      );
      final Duration recomputed = phaseRemaining(startedAtUtc: virtualStart, plannedDurationSec: 25 * 60, nowUtc: now);
      expect(recomputed, const Duration(minutes: 15, seconds: 24));
    });
  });

  group('formatClock', () {
    test('pads seconds and minutes to two digits', () {
      expect(formatClock(const Duration(minutes: 9, seconds: 4)), '09:04');
    });

    test('allows minutes beyond two digits for long focus sessions (up to 90 min)', () {
      expect(formatClock(const Duration(minutes: 90)), '90:00');
    });

    test('zero duration formats as 00:00', () {
      expect(formatClock(Duration.zero), '00:00');
    });
  });

  group('nextCyclePosition / isLongBreakFor', () {
    test('advances 1 -> 2 -> 3 -> 4 then wraps to 1', () {
      expect(nextCyclePosition(1), 2);
      expect(nextCyclePosition(2), 3);
      expect(nextCyclePosition(3), 4);
      expect(nextCyclePosition(4), 1);
    });

    test('only cycle position 4 is a long break', () {
      expect(isLongBreakFor(1), isFalse);
      expect(isLongBreakFor(2), isFalse);
      expect(isLongBreakFor(3), isFalse);
      expect(isLongBreakFor(4), isTrue);
    });
  });
}
