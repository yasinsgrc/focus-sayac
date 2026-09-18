import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/stats/subject_breakdown.dart';
import 'package:focussayac/domain/subjects/subject_catalog.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// 17 Eylül 2026, 15:00 TSİ. Pencere 11-17 eylül, karşılaştırma penceresi
/// 4-10 eylül (`calculateWeeklySummary` ile birebir aynı tanım).
final DateTime _nowUtc = DateTime.utc(2026, 9, 17, 12);

final List<String> _yks = subjectsForExam('yks');

int _id = 0;

PomodoroSession _session(
  int day, {
  required int minutes,
  String? subject,
  bool completed = true,
  SessionType type = SessionType.focus,
}) {
  return PomodoroSession(
    id: ++_id,
    type: type,
    startedAt: DateTime.utc(2026, 9, day, 12),
    plannedDurationSec: minutes * 60,
    completed: completed,
    breakExtensions: 0,
    subjectKey: subject,
  );
}

SubjectBreakdown _calculate(List<PomodoroSession> sessions, {List<String>? catalog}) {
  return calculateSubjectBreakdown(
    sessions: sessions,
    catalog: catalog ?? _yks,
    nowUtc: _nowUtc,
  );
}

void main() {
  test('boş geçmiş: kart çizilmiyor', () {
    final SubjectBreakdown breakdown = _calculate(const <PomodoroSession>[]);

    expect(breakdown.isEmpty, isTrue);
    expect(breakdown.slices, isEmpty);
    expect(breakdown.biggestRise, isNull);
    expect(breakdown.neglect, isNull);
  });

  test('dağılım süreye göre azalan, oranlar toplamı 1', () {
    final SubjectBreakdown breakdown = _calculate(<PomodoroSession>[
      _session(15, minutes: 50, subject: SubjectKeys.math),
      _session(16, minutes: 10, subject: SubjectKeys.math),
      _session(16, minutes: 30, subject: SubjectKeys.turkish),
      _session(12, minutes: 30, subject: SubjectKeys.physics),
    ]);

    expect(breakdown.totalSeconds, 120 * 60);
    expect(
      breakdown.slices.map((SubjectSlice s) => s.key),
      <String>[SubjectKeys.math, SubjectKeys.turkish, SubjectKeys.physics],
    );
    expect(breakdown.slices.first.seconds, 60 * 60);
    expect(breakdown.slices.first.ratio, closeTo(0.5, 0.001));
    expect(
      breakdown.slices.fold<double>(0, (double sum, SubjectSlice s) => sum + s.ratio),
      closeTo(1, 0.001),
    );
  });

  test('dersiz seanslar belirtilmemiş diliminde toplanıyor ve eşitlikte sona düşüyor', () {
    final SubjectBreakdown breakdown = _calculate(<PomodoroSession>[
      _session(13, minutes: 30, subject: SubjectKeys.math),
      // Göçten gelen geçmiş: dersi yok ama emeği ekranın toplamında durmalı.
      _session(14, minutes: 20),
      _session(15, minutes: 10),
    ]);

    expect(breakdown.totalSeconds, 60 * 60);
    expect(breakdown.slices.length, 2);
    // İkisi de 30 dk: belirtilmemiş dilim bir ders değil, eşitlikte sona.
    expect(breakdown.slices.first.key, SubjectKeys.math);
    expect(breakdown.slices.last.key, isNull);
    expect(breakdown.slices.last.seconds, 30 * 60);
  });

  test('yalnızca tamamlanmış odak seansları sayılıyor', () {
    final SubjectBreakdown breakdown = _calculate(<PomodoroSession>[
      _session(15, minutes: 25, subject: SubjectKeys.math),
      // İptal edilen odak ve mola: ikisi de dağılımın dışında.
      _session(15, minutes: 25, subject: SubjectKeys.physics, completed: false),
      _session(15, minutes: 5, subject: SubjectKeys.physics, type: SessionType.shortBreak),
      // Pencerenin dışında kalan gün (10 eylül) bu haftanın toplamına girmiyor.
      _session(10, minutes: 40, subject: SubjectKeys.biology),
    ]);

    expect(breakdown.totalSeconds, 25 * 60);
    expect(breakdown.slices.single.key, SubjectKeys.math);
  });

  test('denge: en çok artan ve en çok azalan ders', () {
    final SubjectBreakdown breakdown = _calculate(<PomodoroSession>[
      // Geçen hafta (4-10 eylül)
      _session(6, minutes: 120, subject: SubjectKeys.math),
      _session(7, minutes: 20, subject: SubjectKeys.chemistry),
      // Bu hafta (11-17 eylül)
      _session(14, minutes: 60, subject: SubjectKeys.math),
      _session(15, minutes: 90, subject: SubjectKeys.turkish),
      _session(16, minutes: 20, subject: SubjectKeys.chemistry),
    ]);

    expect(breakdown.previousTotalSeconds, 140 * 60);
    expect(breakdown.biggestRise!.key, SubjectKeys.turkish);
    expect(breakdown.biggestRise!.deltaSeconds, 90 * 60);
    expect(breakdown.biggestFall!.key, SubjectKeys.math);
    expect(breakdown.biggestFall!.deltaSeconds, -60 * 60);
    // Değişmeyen ders (kimya 20 → 20) hiçbir uca aday değil.
  });

  test('ilk hafta: karşılaştırma penceresi boşken denge kurulmuyor', () {
    final SubjectBreakdown breakdown = _calculate(<PomodoroSession>[
      _session(15, minutes: 60, subject: SubjectKeys.math),
    ]);

    // Kendi sıfırıyla kıyas `WeeklySummary.hasComparison`ın reddettiği şey.
    expect(breakdown.biggestRise, isNull);
    expect(breakdown.biggestFall, isNull);
  });

  test('ihmal: geçmişi olan ve en uzun süredir dokunulmayan ders', () {
    final SubjectBreakdown breakdown = _calculate(<PomodoroSession>[
      _session(15, minutes: 60, subject: SubjectKeys.math),
      // 3 eylülden beri kimya yok → 14 gün.
      _session(3, minutes: 60, subject: SubjectKeys.chemistry),
      // 8 eylülden beri fizik yok → 9 gün, kimyadan taze.
      _session(8, minutes: 60, subject: SubjectKeys.physics),
    ]);

    expect(breakdown.neglect!.key, SubjectKeys.chemistry);
    expect(breakdown.neglect!.daysSince, 14);
  });

  test('ihmal: hiç çalışılmamış ders ve bu hafta çalışılan ders aday değil', () {
    final SubjectBreakdown onlyThisWeek = _calculate(<PomodoroSession>[
      _session(13, minutes: 60, subject: SubjectKeys.math),
      _session(16, minutes: 30, subject: SubjectKeys.chemistry),
    ]);

    // Katalogda 11 ders var; dokunulmamış dokuzu suçlama listesine dönmüyor.
    expect(onlyThisWeek.neglect, isNull);

    // Katalog dışındaki bir dersin geçmişi de aday değil: LGS'ye geçen
    // kullanıcıya felsefe hatırlatılmıyor.
    final SubjectBreakdown otherExam = _calculate(
      <PomodoroSession>[
        _session(15, minutes: 60, subject: SubjectKeys.math),
        _session(2, minutes: 60, subject: SubjectKeys.philosophy),
      ],
      catalog: subjectsForExam('lgs'),
    );
    expect(otherExam.neglect, isNull);
  });

  test('katalog dışı ders dağılımda duruyor', () {
    // Sınav değişmiş olabilir; bu haftaki emek yine de toplamda.
    final SubjectBreakdown breakdown = _calculate(
      <PomodoroSession>[
        _session(15, minutes: 60, subject: SubjectKeys.chemistry),
      ],
      catalog: subjectsForExam('lgs'),
    );

    expect(breakdown.totalSeconds, 60 * 60);
    expect(breakdown.slices.single.key, SubjectKeys.chemistry);
  });
}
