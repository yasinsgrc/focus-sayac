import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/exams/exam_providers.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

import '../../support/rolling_number_finder.dart';

const int _examId = 7;

int _id = 0;

/// Sınav, verilen gün sayısı kadar ileride. `+6 saat`: `daysTo` tam günleri
/// sayıyor, testin çalıştığı saat gün sınırını kaydırmasın diye pay bırakıldı.
Exam _examInDays(int days) {
  return Exam(
    id: _examId,
    name: 'ALES',
    dateUtc: DateTime.now().toUtc().add(Duration(days: days, hours: 6)),
    timeOfDay: '10:00',
    accentRole: ExamAccentRole.ember,
    isPreset: false,
    isActive: true,
    source: ExamSourceType.user,
  );
}

/// Bu sınav için tamamlanmış, **dünden önceki** odak seansları — bugünün
/// kartındaki sayıları kımıldatmasınlar diye geçmişte.
List<PomodoroSession> _focusSessions(int count) {
  return List<PomodoroSession>.generate(count, (int i) {
    return PomodoroSession(
      id: ++_id,
      examId: _examId,
      type: SessionType.focus,
      startedAt: DateTime.now().toUtc().subtract(Duration(days: 1 + (i % 20))),
      plannedDurationSec: 25 * 60,
      completed: true,
      breakExtensions: 0,
    );
  });
}

/// `pumpAndSettle` yok: halkanın `repeat()` animasyonu hiç durmuyor
/// (`countdown_glow_test.dart`'taki gerekçe).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ekran 02'yi sahte sınav ve sahte seans akışıyla kaldırır. İkisi de
/// denetleyici üzerinden veriliyor: tek pompalamada hem sınavın tarihini hem
/// biriken emeği değiştirip üç durumu da aynı ağaçta ölçebilelim diye.
///
/// Yayın (`broadcast`) denetleyicisi **değil**: Riverpod akışa ilk kareden
/// sonra abone oluyor ve yayın denetleyicisi dinleyicisiz eklenen olayı
/// düşürüyor (`streak_protection_badge_test.dart`'taki aynı tuzak).
Future<
    ({
      StreamController<Exam?> exams,
      StreamController<List<PomodoroSession>> sessions,
    })> _pumpCountdown(
  WidgetTester tester, {
  required Exam exam,
  required List<PomodoroSession> sessions,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final StreamController<Exam?> examController = StreamController<Exam?>();
  final StreamController<List<PomodoroSession>> sessionController =
      StreamController<List<PomodoroSession>>();
  addTearDown(examController.close);
  addTearDown(sessionController.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(AdService.disabled()),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
        activeExamProvider.overrideWith((Ref ref) => examController.stream),
        allSessionsProvider.overrideWith((Ref ref) => sessionController.stream),
      ],
      child: const FocusSayacApp(),
    ),
  );
  examController.add(exam);
  sessionController.add(sessions);
  await _settle(tester);
  return (exams: examController, sessions: sessionController);
}

void main() {
  // Tek test, üç yayın: aynı isolate'te ikinci bir `testWidgets` açmak drift
  // göçünü yarım bırakıyor (`countdown_glow_test.dart`'ta belgelenen tuzak).
  testWidgets('son düzlükte kahraman sayı geri sayım değil biriken emek oluyor',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    // 22 × 25 dk = 550 dk = 9 sa 10 dk → kahraman "9". Dakikalar aşağı
    // yuvarlanıyor: halkanın içinde tek bir sayı var, "9 sa 10 dk" değil.
    final ({
      StreamController<Exam?> exams,
      StreamController<List<PomodoroSession>> sessions,
    }) controllers = await _pumpCountdown(
      tester,
      exam: _examInDays(12),
      sessions: _focusSessions(22),
    );

    expect(findRollingNumber('9'), findsOneWidget);
    expect(find.text('SAAT ODAKLANDIN'), findsOneWidget);
    expect(find.text('GÜN KALDI'), findsNothing);
    // Kalan gün kahramanlığı bıraktı ama **kaybolmadı** — bir satır aşağıda.
    expect(findRollingNumber('12 GÜN'), findsOneWidget);

    // Emek eşiğin (1 saat) altına düşerse ekran geri sayıma dönüyor: aksi
    // hâlde son düzlükte "0 SAAT ODAKLANDIN" yazardı, yani tersine çevirmenin
    // amaçladığının tam tersi.
    controllers.sessions.add(_focusSessions(1));
    await _settle(tester);

    expect(find.text('GÜN KALDI'), findsOneWidget);
    expect(find.text('SAAT ODAKLANDIN'), findsNothing);
    expect(findRollingNumber('12'), findsOneWidget);
    expect(findRollingNumber('12 GÜN'), findsNothing);

    // Eşiğin dışında (31 gün) emek yeterli olsa da geri sayım kahraman kalıyor.
    controllers.exams.add(_examInDays(31));
    controllers.sessions.add(_focusSessions(22));
    await _settle(tester);

    expect(find.text('GÜN KALDI'), findsOneWidget);
    expect(findRollingNumber('31'), findsOneWidget);

    semantics.dispose();
    // Denetleyiciler burada **kapatılmıyor**: `close()` ancak `done` olayı
    // aboneye ulaşınca tamamlanıyor, testin sahte zaman kipinde ise o olay
    // pompalanmadan gelmiyor (`streak_protection_badge_test.dart`).
    // Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
