import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/core/theme/app_motion.dart';
import 'package:focussayac/core/widgets/bottom_nav_bar.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_controller.dart';
import 'package:focussayac/features/badges/badges_screen.dart';
import 'package:focussayac/features/countdown/countdown_screen.dart';
import 'package:focussayac/features/focus_session/focus_session_screen.dart';
import 'package:focussayac/features/settings/settings_screen.dart';
import 'package:focussayac/features/stats/stats_screen.dart';
import 'package:focussayac/features/story_card/story_card_screen.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// `FocusSessionScreen` ağaca girer girmez `WakelockPlus.enable()` çağırıyor.
/// Testte gerçek eklenti kayıtlı olmadığı için pigeon kanalı cevapsız kalıyor
/// ve `PlatformException(channel-error)` fırlatıyor — çağrı `unawaited`
/// olduğundan bu, testi düşüren yakalanmamış asenkron hataya dönüşüyor.
/// Boş bir başarı cevabı (`[null]`, pigeon'un `isNullValid: true` beklediği
/// biçim) stub'lanıyor. Kanal adı pigeon'un ürettiği sabittir.
void _stubWakelockChannel() {
  const String channel = 'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    channel,
    (ByteData? message) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
  );
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channel, null),
  );
}

/// Uygulamayı gerçek router'ıyla ayağa kaldırır. `pumpAndSettle`
/// kullanılmıyor: geri sayım halkasının `repeat()` animasyonu hiç "settle"
/// olmaz (widget_test.dart'taki aynı gerekçe), bunun yerine DB tohumlama +
/// stream yayını ve bekleyen `postFrameCallback`ler için birkaç kare
/// pompalanıyor.
Future<void> _pumpApp(WidgetTester tester, {Map<String, Object> initialPrefs = const <String, Object>{}}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  _stubWakelockChannel();

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  SharedPreferences.setMockInitialValues(initialPrefs);
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
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Rota geçişinin (madde 20, `AppMotion.base`) bitmesini bekler. `pumpAndSettle`
/// kullanılamıyor: geri sayım halkasının `repeat()` animasyonu hiç durmuyor.
Future<void> _settleTransition(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Ekranların `Timer.periodic` tikleyicilerini `dispose()` ile durdurur
/// (widget_test.dart'taki drift kapatma gerekçesinin aynısı geçerli).
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('"25 DAKİKA ODAKLAN" yığına tek bir FocusSessionScreen ekler', (WidgetTester tester) async {
    await _pumpApp(tester);
    expect(find.text('25 DAKİKA ODAKLAN'), findsOneWidget);

    await tester.tap(find.text('25 DAKİKA ODAKLAN'));
    // Buton `startFocus()`ü await ediyor (DB yazımı + bildirim); ardından
    // gelen `push` bir sonraki karede işleniyor.
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Regresyon: buton `push` ederken `CountdownScreen`in "aktif seans
    // kurtarma" bloğu da faz değişimini görüp ikinci bir push planlıyordu.
    // İki kopya olduğunda seans bitişindeki tek `pop()` yalnızca üsttekini
    // kapatıyor, kullanıcı boş (PomodoroIdle → SizedBox.shrink) bir odak
    // ekranında kalıyordu.
    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);

    await _disposeTree(tester);
  });

  // Yukarıdaki regresyonun düzeltmesi kurtarma yönlendirmesini `build()`ten
  // `initState()`e taşıdı — SPEC.md DoD "Uygulama öldürülüp açıldığında aktif
  // seans kurtarılıyor" davranışının hâlâ çalıştığı burada doğrulanıyor.
  testWidgets('soğuk başlangıçta kurtarılan aktif seans odak ekranını bir kez açar', (WidgetTester tester) async {
    final String persistedPhase = jsonEncode(<String, Object?>{
      'type': 'focusRunning',
      'sessionId': 1,
      'examId': null,
      // Yeni başlamış bir seans: `tick()` onu anında tamamlayıp idle'a
      // düşürmesin diye planlanan süre tam olarak duruyor.
      'startedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'plannedDurationSec': 25 * 60,
      'cyclePosition': 1,
    });

    await _pumpApp(tester, initialPrefs: <String, Object>{kPomodoroPhasePrefsKey: persistedPhase});

    expect(find.byType(FocusSessionScreen, skipOffstage: false), findsOneWidget);

    await _disposeTree(tester);
  });

  // Regresyon: "alev" ve "madalya" yuvalarının ikisi de `AppNavTab.badges`e
  // bağlıydı — beş ikonun dördü dolu, biri aynı ekranın kopyasıydı. Yuvaların
  // ekran okuyucu adları aynı zamanda hedeflerinin tek ayırt edicisi olduğu
  // için test hem yönlendirmeyi hem etiketleri birlikte doğruluyor.
  testWidgets('alt çubuktaki "alev" yuvası başarı kartını, "madalya" rozetleri açar', (WidgetTester tester) async {
    // `addTearDown` kullanılmıyor: tutamağın bırakılıp bırakılmadığı test
    // gövdesi biter bitmez, teardown'lardan **önce** denetleniyor.
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('BAŞARI KARTI'));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(StoryCardScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(BadgesScreen, skipOffstage: false), findsNothing);

    await _disposeTree(tester);
    handle.dispose();
  });

  testWidgets('alt çubuk ikonlarının dokunma hedefi 48px yüksekliğinde', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpApp(tester);

    // Regresyon: `InkWell` `Row`un gevşek dikey sınırı altında 21px'lik ikonun
    // boyuna küçülüyordu; 64px'lik çubukta dokunulabilir şerit ikonun kendisi
    // kadardı. Materyal'in en küçük dokunma hedefi 48px.
    for (final String label in <String>['BAŞARI KARTI', 'ROZETLER', 'AYARLAR']) {
      expect(tester.getSize(find.bySemanticsLabel(label)).height, 48, reason: label);
    }

    await _disposeTree(tester);
    handle.dispose();
  });

  // Çubuk uzun süre yalnızca Ekran 02 ve 06'daydı: diğer üç sekme oraya
  // götürüyor ama geri getirmiyordu, yani gezinme tek yönlüydü.
  testWidgets('alt çubuk beş sekmenin hepsinde görünüyor', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpApp(tester);
    expect(find.byType(BottomNavBar), findsOneWidget);

    // Yığında kalan Ekran 02 kendi çubuğunu çizmeye devam ettiği için hem
    // dokunuş hem doğrulama **o anki üst ekranın içinde** yapılıyor; aksi
    // hâlde iki "ROZETLER" yuvası bulunup dokunuş hangisine gideceğini
    // bilemiyor.
    Type current = CountdownScreen;
    for (final (String, Type) tab in <(String, Type)>[
      ('BAŞARI KARTI', StoryCardScreen),
      ('ROZETLER', BadgesScreen),
      ('VERİLER', StatsScreen),
      ('AYARLAR', SettingsScreen),
    ]) {
      await tester.tap(
        find.descendant(of: find.byType(current), matching: find.bySemanticsLabel(tab.$1)),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(tab.$2), findsOneWidget, reason: tab.$1);
      expect(
        find.descendant(of: find.byType(tab.$2), matching: find.byType(BottomNavBar)),
        findsOneWidget,
        reason: tab.$1,
      );
      current = tab.$2;
    }

    await _disposeTree(tester);
    handle.dispose();
  });

  // Sekmeler `push` edilseydi her geçiş yığına bir kat eklerdi: dört sekme
  // arasında birkaç tur dolaşan kullanıcı Ekran 02'ye dönmek için sistem geri
  // tuşuna onlarca kez basmak zorunda kalırdı.
  testWidgets('sekmeler arasında dolaşmak gezinme yığınını büyütmüyor', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpApp(tester);

    Type current = CountdownScreen;
    for (final (String, Type) tab in <(String, Type)>[
      ('ROZETLER', BadgesScreen),
      ('AYARLAR', SettingsScreen),
      ('VERİLER', StatsScreen),
      ('BAŞARI KARTI', StoryCardScreen),
    ]) {
      await tester.tap(
        find.descendant(of: find.byType(current), matching: find.bySemanticsLabel(tab.$1)),
      );
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      current = tab.$2;
    }

    // Yerini bırakan rotaların çıkış animasyonu bitene kadar `skipOffstage:
    // false` onları hâlâ ağaçta görüyor; sayım ancak geçiş tamamlandıktan
    // sonra yığını yansıtıyor.
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Kökün üstünde tek bir kat kaldı: gezilen ara ekranlar yığında değil.
    expect(find.byType(StoryCardScreen, skipOffstage: false), findsOneWidget);
    for (final Type screen in <Type>[BadgesScreen, SettingsScreen, StatsScreen]) {
      expect(find.byType(screen, skipOffstage: false), findsNothing, reason: '$screen');
    }

    await _disposeTree(tester);
    handle.dispose();
  });

  // ROADMAP madde 20: sekmeler arası geçiş artık Material'ın varsayılan sayfa
  // animasyonu değil, uygulamanın kendi fade-through'u (`CustomTransitionPage`).
  testWidgets('sekme geçişinde iki ekran ara karede birlikte, sonunda yalnızca hedef', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpApp(tester);

    // Ölçüm ikinci hoptan alınıyor: Ekran 02 kök olduğu için oradan çıkış
    // `push`, yani geçiş bitince de yığında kalıyor (madde 13). "Yalnızca
    // hedef" iddiası ancak sekmeden sekmeye (`pushReplacement`) geçerli.
    await tester.tap(find.bySemanticsLabel('ROZETLER'));
    await _settleTransition(tester);

    await tester.tap(
      find.descendant(of: find.byType(BadgesScreen), matching: find.bySemanticsLabel('AYARLAR')),
    );
    await tester.pump();
    await tester.pump(AppMotion.base ~/ 2);

    expect(find.byType(BadgesScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
    final FadeTransition fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.byType(SettingsScreen), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, greaterThan(0.0));
    expect(fade.opacity.value, lessThan(1.0), reason: 'giren ekran ara karede yarı saydam');

    await _settleTransition(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(BadgesScreen, skipOffstage: false), findsNothing);

    await _disposeTree(tester);
    handle.dispose();
  });

  testWidgets('hareketi azalt açıkken geçiş yok, hedef ilk karede', (WidgetTester tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpApp(tester);
    expect(
      find.descendant(of: find.byType(BottomNavBar), matching: find.byType(Hero)),
      findsNothing,
      reason: 'hap uçmuyor, Hero hiç kurulmuyor',
    );

    await tester.tap(find.bySemanticsLabel('ROZETLER'));
    await tester.pump();

    expect(find.byType(BadgesScreen), findsOneWidget);
    final FadeTransition fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.byType(BadgesScreen), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, 1.0, reason: 'ilk karede hedef ekran son hâlinde');

    await _disposeTree(tester);
    handle.dispose();
  });

  // Beş sekmenin her biri ayrı bir rota ve çubuk her rotada sıfırdan kuruluyor;
  // hap bu yüzden `AnimatedPositioned` ile kayamıyor, `Hero` ile uçuyor.
  testWidgets('aktif hap rota geçişinde yuvadan yuvaya uçuyor', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpApp(tester);

    // "SAYAÇ" yalnızca aktif hapın etiketi olarak **metin** olarak çiziliyor;
    // pasif dört yuva ikon + ekran okuyucu adı, o yüzden bu dize hapın izi.
    expect(find.descendant(of: find.byType(CountdownScreen), matching: find.text('SAYAÇ')), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('ROZETLER'));
    await tester.pump();
    await tester.pump(AppMotion.base ~/ 2);

    // Uçuş sırasında `Hero` hem kaynağı hem hedefi yer tutucuya çeviriyor: hap
    // artık iki rotanın da içinde değil, `Overlay`de.
    expect(find.text('SAYAÇ'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(CountdownScreen), matching: find.text('SAYAÇ')),
      findsNothing,
      reason: 'hap uçarken kaynağın çubuğunda durmuyor',
    );

    await _settleTransition(tester);
    // Uçuş bitti: mekik söküldü. Kaynağın hapı kendi çubuğuna geri yerleşiyor
    // ama o rota artık opak bir rotanın altında, yani çizilmiyor — `skipOffstage`
    // açıkken hiç bulunmaması aranan şey. `skipOffstage: false` ile hâlâ orada;
    // bu satırın iddiası "ekranda değil", "ağaçta değil" değil.
    expect(find.text('SAYAÇ'), findsNothing);
    expect(
      find.descendant(of: find.byType(BottomNavBar), matching: find.text('ROZETLER')),
      findsOneWidget,
      reason: 'uçan hap hedefin yuvasına indi',
    );

    await _disposeTree(tester);
    handle.dispose();
  });
}
