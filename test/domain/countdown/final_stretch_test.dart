import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/countdown/countdown_math.dart';
import 'package:focussayac/domain/stats/focus_stats.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// Ekran 02'nin son düzlükte hiyerarşiyi tersine çevirme kuralı: kahraman sayı
/// "kalan gün" olmaktan çıkıp o sınav için biriken odak saati olur.
int _id = 0;

PomodoroSession _session({
  int? examId,
  bool completed = true,
  int minutes = 25,
  SessionType type = SessionType.focus,
}) {
  return PomodoroSession(
    id: ++_id,
    examId: examId,
    type: type,
    startedAt: DateTime.utc(2026, 3, 10, 7),
    plannedDurationSec: minutes * 60,
    completed: completed,
    breakExtensions: 0,
  );
}

void main() {
  group('examFocusSeconds', () {
    test('yalnızca o sınavın tamamlanmış odak seansları toplanıyor', () {
      final List<PomodoroSession> sessions = <PomodoroSession>[
        _session(examId: 7, minutes: 25),
        _session(examId: 7, minutes: 50),
        // Başka hedefin saatleri bu toplama giremez — sayının altındaki cümle
        // sınav adıyla kuruluyor.
        _session(examId: 8, minutes: 90),
        // Aktif sınav yokken açılmış seans hiçbir sınavın toplamına girmez.
        _session(minutes: 40),
        // Yarıda bırakılan seans emek saymıyor (Ekran 06 ile aynı kural).
        _session(examId: 7, minutes: 25, completed: false),
        // Mola, odak değil.
        _session(examId: 7, minutes: 15, type: SessionType.shortBreak),
      ];

      expect(examFocusSeconds(sessions: sessions, examId: 7), 75 * 60);
      expect(examFocusSeconds(sessions: sessions, examId: 8), 90 * 60);
    });

    test('hiç seans yokken 0 — uydurma yok', () {
      expect(examFocusSeconds(sessions: const <PomodoroSession>[], examId: 7), 0);
    });
  });

  group('isFinalStretch', () {
    test('eşik gününde başlıyor, bir gün öncesinde başlamıyor', () {
      const int enough = kFinalStretchMinFocusSeconds;

      expect(isFinalStretch(days: kFinalStretchDays, examFocusSeconds: enough), isTrue);
      expect(isFinalStretch(days: kFinalStretchDays + 1, examFocusSeconds: enough), isFalse);
    });

    test('sınav günü de son düzlüğün içinde', () {
      expect(isFinalStretch(days: 0, examFocusSeconds: kFinalStretchMinFocusSeconds), isTrue);
    });

    // Asıl regresyon: emek eşiğin altındayken çevirmek ekranı "12 gün
    // kaldı"dan "0 SAAT ODAKLANDIN"a düşürürdü — tersine çevirmenin
    // amaçladığının tam tersi bir mesaj.
    test('emek eşiğin altındaysa geri sayım kahraman kalıyor', () {
      expect(isFinalStretch(days: 12, examFocusSeconds: 0), isFalse);
      expect(isFinalStretch(days: 12, examFocusSeconds: kFinalStretchMinFocusSeconds - 1), isFalse);
      expect(isFinalStretch(days: 12, examFocusSeconds: kFinalStretchMinFocusSeconds), isTrue);
    });
  });
}
