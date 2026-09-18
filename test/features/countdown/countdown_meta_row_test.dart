import 'dart:async';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/core/time/app_day.dart';
import 'package:focussayac/domain/exams/exam_providers.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/features/countdown/widgets/countdown_ring_painter.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

const int _examId = 7;

int _id = 0;

/// Sınav 12 gün ileride (son düzlük eşiğinin içinde). `+6 saat`: `daysTo` tam
/// günleri sayıyor, testin koştuğu saat gün sınırını kaydırmasın diye pay.
final DateTime _examUtc = DateTime.now().toUtc().add(const Duration(days: 12, hours: 6));

Exam get _exam => Exam(
      id: _examId,
      name: 'ALES',
      dateUtc: _examUtc,
      timeOfDay: '10:00',
      accentRole: ExamAccentRole.ember,
      isPreset: false,
      isActive: true,
      source: ExamSourceType.user,
    );

/// Bu sınav için tamamlanmış, **dünden önceki** seanslar — bugünün kartındaki
/// sayıları kımıldatmasınlar diye geçmişte.
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

/// Meta satırının kapağının **dört köşesi** de en içteki dolu yayın içinde mi?
/// Asıl iddia bu: eski kapak (284) halkanın yatay çapından geliyordu, oysa
/// satır merkezin ~75px altında duruyor ve orada dairenin kirişi çok daha dar
/// — satırın iki ucu izin altına giriyordu (ROADMAP madde 32, kanıt
/// `.verify/v28_metarow_zoom.png`).
///
/// Köşe uzaklığı ölçülüyor, sabit genişlik **değil**: satırın dikey ofseti yazı
/// ölçülerinden geliyor, yani kahraman sayı ya da kicker büyürse satır aşağı
/// kayar, kiriş daralır ve kapak sessizce yeniden taşardı. Bu iddia o
/// değişikliği yakalar.
///
/// Metnin kendi genişliği burada ölçülemez: `flutter test` gerçek fontları
/// yüklemiyor, her glif aynı kutu. Metnin küçülmeden sığdığının kanıtı
/// emülatörde (ROADMAP madde 32).
void _expectCapInsideRing(WidgetTester tester, String durum) {
  final Rect ring = tester.getRect(find.byWidgetPredicate(
      (Widget widget) => widget is CustomPaint && widget.painter is CountdownRingPainter));
  final Rect cap = tester.getRect(find.byKey(kCountdownMetaRowKey));
  final Offset center = ring.center;

  final Map<String, Offset> koseler = <String, Offset>{
    'sol üst': cap.topLeft,
    'sağ üst': cap.topRight,
    'sol alt': cap.bottomLeft,
    'sağ alt': cap.bottomRight,
  };
  koseler.forEach((String ad, Offset kose) {
    final double uzaklik = (kose - center).distance;
    expect(
      uzaklik,
      lessThan(CountdownRingPainter.innerContentRadius),
      reason: '$durum: kapağın $ad köşesi merkezden ${uzaklik.toStringAsFixed(1)}px, '
          'en içteki yay ${CountdownRingPainter.innerContentRadius}px\'te başlıyor',
    );
  });

  // Kapak dar tutularak değil, kirişe göre hesaplanarak sığıyor: o yükseklikteki
  // kirişin çoğunu kullanıyor olmalı. Aksi hâlde "hiç kesişmiyor" iddiası kapağı
  // 10px'e indirerek de sağlanabilirdi.
  //
  // Pay neden %80: `FittedBox` en boy oranını koruyor, yani metni küçülttüğünde
  // kutunun **yüksekliği** de düşüyor, `Column` kısalıyor ve ortalanmış satır
  // yukarı kayıyor — kiriş genişliyor. Küçültmenin miktarı yüklü fonta bağlı
  // (bu koşumda test fontu, cihazda Inter), o yüzden üst sınır sıkı
  // tutulamıyor. Gerçek fontla oran %98 (176 / 180).
  final double dy = math.max((cap.top - center.dy).abs(), (cap.bottom - center.dy).abs());
  const double r = CountdownRingPainter.innerContentRadius;
  final double kiris = 2 * math.sqrt(r * r - dy * dy);
  expect(cap.width, greaterThan(kiris * 0.8),
      reason: '$durum: kapak ${cap.width}px, o yükseklikteki kiriş '
          '${kiris.toStringAsFixed(1)}px — satır gereksiz yere küçülüyor');
}

void main() {
  // Tek test, iki yayın: aynı isolate'te ikinci bir `testWidgets` açmak drift
  // göçünü yarım bırakıyor (`countdown_glow_test.dart`'ta belgelenen tuzak).
  testWidgets('halka içindeki meta satırı halkanın izine girmiyor', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await initializeDateFormatting('tr_TR');
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Yayın (`broadcast`) denetleyicisi **değil**: Riverpod akışa ilk kareden
    // sonra abone oluyor ve yayın denetleyicisi dinleyicisiz eklenen olayı
    // düşürüyor (`streak_protection_badge_test.dart`'taki tuzak).
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
    // 22 × 25 dk = 9 sa 10 dk → son düzlük açık, satır üç parça.
    examController.add(_exam);
    sessionController.add(_focusSessions(22));
    await _settle(tester);

    final DateTime yerel = toIstanbulWallClock(_examUtc);
    final String kisaTarih = DateFormat('d MMM', 'tr').format(yerel);
    final String tamTarih = DateFormat('d MMMM y', 'tr').format(yerel);

    // Son düzlükte tarih kısalıyor: üçüncü parça eklenince tam tarih kirişe
    // sığmıyor, kısaltmada kaybolan tek bilgi (yıl) on iki gün kalmış bir
    // sınavda zaten okunmuyor.
    expect(find.text(kisaTarih), findsOneWidget);
    expect(find.text(tamTarih), findsNothing);
    _expectCapInsideRing(tester, 'son düzlük');

    // Emek eşiğin altına düşünce ekran geri sayıma dönüyor: satır iki parça,
    // tarih tam. Bu durum madde 32'den **önce** de doğruydu, bozulmamalı.
    sessionController.add(_focusSessions(1));
    await _settle(tester);

    expect(find.text(tamTarih), findsOneWidget);
    expect(find.text(kisaTarih), findsNothing);
    _expectCapInsideRing(tester, 'normal');

    // Denetleyiciler burada **kapatılmıyor**: `close()` ancak `done` olayı
    // aboneye ulaşınca tamamlanıyor, testin sahte zaman kipinde ise o olay
    // pompalanmadan gelmiyor (`streak_protection_badge_test.dart`).
    // Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
