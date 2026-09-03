import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

void main() {
  testWidgets('App boots and renders Ekran 02 (geri sayım)', (WidgetTester tester) async {
    // Varsayılan test yüzeyi (~800×600) prototipin telefon boyundaki (390×844)
    // ekranı için dikey taşmaya yol açıyor — gerçek cihaz boyutunu taklit ediyoruz.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await initializeDateFormatting('tr_TR');
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());

    // Faz 5: `CountdownScreen` artık `pomodoroControllerProvider`ı okuyor
    // (aktif seans kurtarma yönlendirmesi için), o da `PomodoroController`
    // üzerinden `sharedPreferencesProvider`a bağlı — bu yüzden Faz 4'te
    // gerekmeyen bu override artık gerekli.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          // Faz 11: Ekran 02'nin banner yuvası `adServiceProvider`ı okuyor.
          adServiceProvider.overrideWithValue(AdService.disabled()),
          // Faz 10: başlangıç rotası `onboardingCompleted` bayrağına bakıyor.
          // Bu test onboarding'i geçmiş kullanıcının açılışını doğruluyor;
          // ilk açılış Ekran 01'e düşer (onboarding_test.dart).
          onboardingCompletedAtLaunchProvider.overrideWithValue(true),
        ],
        child: const FocusSayacApp(),
      ),
    );
    // `pumpAndSettle` kullanılmıyor: halkanın sonsuz-tekrarlı dönüş animasyonu
    // (`AnimationController.repeat()`) hiçbir zaman "settle" olmaz. Bunun
    // yerine DB tohumlama + stream yayınının gerçek zamanlı tamamlanması için
    // birkaç kare pompalanıyor.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('GÜN KALDI'), findsOneWidget);
    expect(find.text('25 DAKİKA ODAKLAN'), findsOneWidget);

    // Ekranın `Timer.periodic` saniye tikleyicisini `dispose()` ile
    // durdurmadan test bitmesin diye ağacı boşaltıyoruz. `database.close()`
    // kasıtlı olarak çağrılmıyor: `ProviderScope` kaldırılınca Riverpod
    // `StreamProvider`ların drift `.watch()` aboneliklerini iptal ediyor,
    // ama `NativeDatabase.memory()` üstünde `close()` bu abonelik
    // kapanışıyla yarışıp asla tamamlanmayan bir `Future` döndürüyor
    // (gözlemlenen davranış — testin `FakeAsync` saati ilerletilmediği
    // sürece drift'in temizlik `Timer(Duration.zero, ...)`'ı hiç ateşlenmiyor).
    // Bellek-içi test DB'si zaten process'le birlikte yok oluyor — kapatmamak
    // zararsız. Bertaraf sırasında oluşan o sıfır-süreli temizlik zamanlayıcısını
    // boşaltmak için bir kare daha pompalıyoruz.
    await tester.pumpWidget(const SizedBox.shrink());
    // Artık ekranın kendi sonsuz-tekrarlı animasyonu ağaçtan kalktı; geri
    // kalan yalnızca drift'in kademeli abonelik-kapatma sıfır-süreli
    // zamanlayıcıları (StreamProvider başına biri) — `pumpAndSettle` bunları
    // güvenle tüketir.
    await tester.pumpAndSettle();
  });
}
