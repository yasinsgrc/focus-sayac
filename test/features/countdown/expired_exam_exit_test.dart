import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';
import 'package:focussayac/services/storage/tables.dart';

/// Uygulamayı, tarihi geçmiş ama hâlâ `isActive` olan bir sınavla ayağa
/// kaldırır — kullanıcının sınav gününü geride bıraktığı durum. İlk `write`
/// await edildiği için `onCreate` (ayar satırı + sınav tohumlaması) bu
/// noktada tamamlanmış olur.
Future<void> _pumpWithExpiredActiveExam(WidgetTester tester) async {
  // no_active_exam_test.dart ile aynı gerekçe: test ortamında gerçek yazı
  // tipleri yüklenmediğinden alt sayfanın başlık satırı 390px'te sahte bir
  // taşma bildiriyor. Test edilen davranış genişlikten bağımsız.
  tester.view.physicalSize = const Size(700, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  await database.update(database.exams).write(const ExamsCompanion(isActive: Value<bool>(false)));

  final Exam seeded = (await database.select(database.exams).get()).first;
  await (database.update(database.exams)..where((Exams e) => e.id.equals(seeded.id))).write(
    ExamsCompanion(
      dateUtc: Value<DateTime>(DateTime.now().toUtc().subtract(const Duration(days: 3))),
      isActive: const Value<bool>(true),
    ),
  );

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWithValue(AdService.disabled()),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
        // Faz 10: test edilen akış Ekran 02'den başlıyor — onboarding'i
        // tamamlamış kullanıcının açılışı.
        onboardingCompletedAtLaunchProvider.overrideWithValue(true),
      ],
      child: const FocusSayacApp(),
    ),
  );
  await _settle(tester);
}

/// `pumpAndSettle` kullanılamıyor (geri sayım halkasının `repeat()`
/// animasyonu hiç durmaz) — DB yazımı, stream yayını, `postFrameCallback`
/// ve alt sayfa geçiş animasyonu için sabit sayıda kare pompalanıyor.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ekranların `Timer.periodic` tikleyicilerini durdurur (widget_test.dart'taki
/// gerekçenin aynısı geçerli).
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  // Regresyon: "YENİ SINAV SEÇ" yalnızca geri sayıma dönüp alt sayfayı
  // açıyordu. Kullanıcı alt sayfayı sınav seçmeden kapattığında geçmiş
  // tarihli sınav hâlâ aktif olduğu için ekran "0 GÜN KALDI" gösteren bir
  // sayaçta kalıyordu; `CountdownScreen`in süre kontrolü `activeExamProvider`
  // yeni bir değer yayınlamadığı için orada yeniden tetiklenmiyor.
  testWidgets('süresi geçmiş sınavdan çıkıldığında sayaç boş duruma düşer', (WidgetTester tester) async {
    await _pumpWithExpiredActiveExam(tester);

    expect(find.text('SINAVIN GEÇTİ'), findsOneWidget);

    await tester.tap(find.text('YENİ SINAV SEÇ'));
    await _settle(tester);

    // Geri sayıma dönüldü ve sınav seçme alt sayfası açıldı.
    expect(find.text('Kendi sınavımı ekle'), findsOneWidget);

    // Kullanıcı hiçbir sınav seçmeden alt sayfayı kapatıyor (perdeye dokunma).
    await tester.tapAt(const Offset(350, 40));
    await _settle(tester);

    expect(find.text('HEDEF SEÇİLMEDİ'), findsOneWidget);
    expect(find.text('GÜN KALDI'), findsNothing);

    await _disposeTree(tester);
  });
}
