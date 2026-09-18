import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/domain/stats/subject_breakdown.dart';
import 'package:focussayac/domain/subjects/subject_catalog.dart';
import 'package:focussayac/features/stats/widgets/subject_breakdown_card.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

import '../../support/localized_test_app.dart';

/// 17 Eylül 2026, 15:00 TSİ — pencere 11-17 eylül, öncesi 4-10 eylül.
final DateTime _nowUtc = DateTime.utc(2026, 9, 17, 12);

final List<String> _yks = subjectsForExam('yks');

int _id = 0;

PomodoroSession _focus(int day, {required int minutes, String? subject}) {
  return PomodoroSession(
    id: ++_id,
    type: SessionType.focus,
    startedAt: DateTime.utc(2026, 9, day, 12),
    plannedDurationSec: minutes * 60,
    completed: true,
    breakExtensions: 0,
    subjectKey: subject,
  );
}

/// Kartı tek başına çizer — veritabanı ve Riverpod yok, dağılım doğrudan saf
/// hesaplayıcıdan besleniyor (`monthly_heatmap_card_test.dart` kalıbı).
Future<void> _pumpCard(WidgetTester tester, List<PomodoroSession> sessions) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    localizedTestApp(
      Scaffold(
        backgroundColor: AppColors.dark().bg,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: SubjectBreakdownCard(
              breakdown: calculateSubjectBreakdown(
                sessions: sessions,
                catalog: _yks,
                nowUtc: _nowUtc,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dağılım: satırlar, süreler ve yüzdeler', (WidgetTester tester) async {
    await _pumpCard(tester, <PomodoroSession>[
      _focus(15, minutes: 60, subject: SubjectKeys.math),
      _focus(16, minutes: 30, subject: SubjectKeys.turkish),
      // Dersi belirtilmemiş seans dağılımda kendi satırında.
      _focus(12, minutes: 30),
    ]);

    expect(find.text('DERS DAĞILIMI'), findsOneWidget);
    // Başlıkta kısa biçim; uzun biçim `Semantics` etiketinde.
    expect(find.text('2sa'), findsOneWidget);

    expect(find.byKey(subjectRowKey(SubjectKeys.math)), findsOneWidget);
    expect(find.byKey(subjectRowKey(SubjectKeys.turkish)), findsOneWidget);
    expect(find.byKey(subjectRowKey(null)), findsOneWidget);

    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Belirtilmemiş'), findsOneWidget);
    expect(find.text('1sa'), findsOneWidget);
    expect(find.text('%50'), findsOneWidget);
    expect(find.text('%25'), findsNWidgets(2));

    expect(
      find.bySemanticsLabel('Bu hafta 3 derste toplam 2 saat odaklandın.'),
      findsOneWidget,
    );
  });

  testWidgets('ilk hafta: denge satırı ve ihmal satırı yok', (WidgetTester tester) async {
    await _pumpCard(tester, <PomodoroSession>[
      _focus(15, minutes: 60, subject: SubjectKeys.math),
    ]);

    expect(find.byKey(subjectRowKey(SubjectKeys.math)), findsOneWidget);
    // Önceki pencere boş: kendi sıfırıyla kıyas kurulmuyor.
    expect(find.text('GEÇEN HAFTAYA GÖRE'), findsNothing);
    expect(find.textContaining('gündür dokunmadın'), findsNothing);
  });

  testWidgets('denge ve ihmal satırları', (WidgetTester tester) async {
    await _pumpCard(tester, <PomodoroSession>[
      // Geçen hafta
      _focus(6, minutes: 120, subject: SubjectKeys.math),
      // 3 eylülden beri kimya yok → 14 gün.
      _focus(3, minutes: 60, subject: SubjectKeys.chemistry),
      // Bu hafta
      _focus(14, minutes: 60, subject: SubjectKeys.math),
      _focus(15, minutes: 90, subject: SubjectKeys.turkish),
    ]);

    expect(find.text('GEÇEN HAFTAYA GÖRE'), findsOneWidget);
    // Artan ve azalan uç aynı satırda, azalan da nötr tonda.
    expect(find.textContaining('Türkçe +1sa 30dk'), findsOneWidget);
    expect(find.textContaining('Matematik −1sa'), findsOneWidget);

    // Yönelme eki sözcüğün son ünlüsünden: `Kimya'ya`.
    expect(find.text("Kimya'ya 14 gündür dokunmadın."), findsOneWidget);
  });
}
