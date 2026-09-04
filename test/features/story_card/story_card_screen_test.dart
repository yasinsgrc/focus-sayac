import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/core/app_links.dart';
import 'package:focussayac/core/router/app_router.dart';
import 'package:focussayac/domain/story_card/story_card_text.dart';
import 'package:focussayac/features/badges/badges_screen.dart';
import 'package:focussayac/features/story_card/story_card_screen.dart';
import 'package:focussayac/features/story_card/widgets/story_card_view.dart';
import 'package:focussayac/main.dart';
import 'package:focussayac/services/export/story_card_exporter.dart';
import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

import '../../support/localized_test_app.dart';

/// Gerekçe için bkz. `test/features/settings/settings_screen_test.dart`.
Future<void> _settle(WidgetTester tester, {int rounds = 4}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<T> _read<T>(WidgetTester tester, Future<T> Function() query) async {
  return (await tester.runAsync(query)) as T;
}

Future<AppDatabase> _newDatabase(WidgetTester tester) {
  return _read(tester, () async {
    final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.appSettingsDao.getSettings();
    return database;
  });
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _appWith(AppDatabase database, SharedPreferences prefs, Widget home) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(prefs),
      adServiceProvider.overrideWithValue(AdService.disabled()),
      notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
      onboardingCompletedAtLaunchProvider.overrideWithValue(true),
    ],
    child: home,
  );
}

Future<AppDatabase> _pumpStoryCard(WidgetTester tester) async {
  _usePhoneSurface(tester);
  await initializeDateFormatting('tr_TR');
  final AppDatabase database = await _newDatabase(tester);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    _appWith(database, prefs, localizedTestApp(const StoryCardScreen())),
  );
  await _settle(tester);
  return database;
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// PNG baytlarının gerçek piksel ölçüsü — `capturePng` çıktısı çözülüp
/// ölçülüyor, `pixelRatio` hesabına güvenilmiyor.
Future<({int width, int height})> _pngSize(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ({int width, int height}) size = (width: frame.image.width, height: frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return size;
}

/// Kartı tek başına (ekranın geri kalanı olmadan) çizer — dışa aktarım ve
/// taşma testleri yalnızca kartla ilgileniyor.
Future<GlobalKey> _pumpCard(
  WidgetTester tester, {
  required StoryCardTemplate template,
  required StoryCardText text,
}) async {
  final GlobalKey key = GlobalKey();
  await tester.pumpWidget(
    localizedTestApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: kStoryCardPreviewWidth,
            height: kStoryCardPreviewWidth * kStoryCardHeight / kStoryCardWidth,
            child: FittedBox(
              child: StoryCardView(template: template, text: text, boundaryKey: key),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

void main() {
  testWidgets('dışa aktarım tam 1080×1920 — önizleme küçültülmüş olsa da',
      (WidgetTester tester) async {
    _usePhoneSurface(tester);
    final GlobalKey key = await _pumpCard(
      tester,
      template: StoryCardTemplate.nightTorch,
      text: const StoryCardText(
        tag: 'BUGÜNÜN ODAĞI',
        big: '2:15',
        line1: 'Bugün 2 saat 15 dakika odaklandım.',
        line2: "YKS 2027'ye 132 gün kaldı",
        shareHeadline: 'Bugün 2 saat 15 dakika odaklandım.',
      ),
    );

    final Uint8List? bytes = await _read(tester, () => const StoryCardExporter().capturePng(key));
    expect(bytes, isNotNull);

    final ({int width, int height}) size = await _read(tester, () => _pngSize(bytes!));
    expect(size.width, 1080);
    expect(size.height, 1920);

    await _disposeTree(tester);
  });

  testWidgets('üç haneli gün ve uzun sınav adı taşmıyor', (WidgetTester tester) async {
    _usePhoneSurface(tester);
    // SPEC.md §9 taşma testi: en uzun olası içerik her üç şablonda da
    // kırpılmadan/patlamadan çizilmeli.
    const StoryCardText overflowing = StoryCardText(
      tag: 'ÇOK UZUN BİR SINAV ADI VE OTURUM ETİKETİ 2027 BAHAR DÖNEMİ',
      big: '999',
      line1: 'Bugün 12 saat 59 dakika odaklandım ve bu cümle bilerek çok uzun.',
      line2: "ÇOK UZUN BİR SINAV ADI VE OTURUM ETİKETİ 2027'ye 999 gün kaldı",
      shareHeadline: 'Bugün 12 saat 59 dakika odaklandım ve bu cümle bilerek çok uzun.',
    );

    for (final StoryCardTemplate template in StoryCardTemplate.values) {
      await _pumpCard(tester, template: template, text: overflowing);
      expect(tester.takeException(), isNull, reason: '$template taştı');
    }

    await _disposeTree(tester);
  });

  testWidgets('şablon seçimi selectedTemplateIndex kolonuna yazılıyor',
      (WidgetTester tester) async {
    final AppDatabase database = await _pumpStoryCard(tester);

    // Kolon varsayılanı 0 — ilk şablon seçili açılıyor.
    expect((await _read(tester, database.appSettingsDao.getSettings)).selectedTemplateIndex, 0);
    expect(find.text('BUGÜNÜN ODAĞI'), findsOneWidget);

    await tester.tap(find.text(StoryCardTemplate.streak.label(testL10n)));
    await _settle(tester);

    expect((await _read(tester, database.appSettingsDao.getSettings)).selectedTemplateIndex, 2);
    // Kart da yeni şablona geçiyor.
    expect(find.text('BUGÜNÜN ODAĞI'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('kayıtlı şablon açılışta geri yükleniyor', (WidgetTester tester) async {
    _usePhoneSurface(tester);
    await initializeDateFormatting('tr_TR');
    final AppDatabase database = await _newDatabase(tester);
    await _read(
      tester,
      () => database.appSettingsDao.updateSettings(
        const AppSettingsTableCompanion(selectedTemplateIndex: Value<int>(1)),
      ),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      _appWith(database, prefs, localizedTestApp(const StoryCardScreen())),
    );
    await _settle(tester);

    // MİNİMAL şablonu aktif sınavın adını etiket olarak gösteriyor.
    final Exam? active = await _read(tester, database.examDao.getActiveExam);
    expect(active, isNotNull);
    expect(find.text(active!.name.toUpperCase()), findsWidgets);
    expect(find.text('BUGÜNÜN ODAĞI'), findsNothing);

    await _disposeTree(tester);
  });

  testWidgets('rozet dialogundaki düğme Ekran 05\'i açıyor', (WidgetTester tester) async {
    _usePhoneSurface(tester);
    await initializeDateFormatting('tr_TR');
    final AppDatabase database = await _newDatabase(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_appWith(database, prefs, const FocusSayacApp()));
    await _settle(tester);

    await tester.tap(find.byIcon(PhosphorIconsRegular.medal));
    await _settle(tester, rounds: 8);
    // Başlık metni aranmıyor: alt çubuk artık rozetler ekranında da görünüyor
    // ve aktif sekmenin hapı da "ROZETLER" yazıyor.
    expect(find.byType(BadgesScreen), findsOneWidget);

    await tester.tap(find.text('İlk Kıvılcım'));
    await _settle(tester, rounds: 6);

    await tester.tap(find.text('BAŞARI KARTINI OLUŞTUR'));
    await _settle(tester, rounds: 8);

    expect(find.text('BAŞARI KARTI'), findsOneWidget);
    expect(find.text('1080 × 1920 PNG'), findsOneWidget);
    // Alt imza kartın içinde: Instagram paylaşım metnini yok saydığı için
    // linkin görselin kendisinde de durması gerekiyor.
    expect(find.text('focussayaç · Google Play'), findsOneWidget);

    await _disposeTree(tester);
  });

  testWidgets('alt imza üç şablonda da çiziliyor', (WidgetTester tester) async {
    _usePhoneSurface(tester);
    for (final StoryCardTemplate template in StoryCardTemplate.values) {
      await _pumpCard(
        tester,
        template: template,
        text: const StoryCardText(
          tag: 'SERİ',
          big: '6',
          line1: 'gün üst üste odaklandım.',
          line2: "Yarın 7'ye çıkıyor",
          shareHeadline: '6 gün üst üste odaklandım.',
        ),
      );
      expect(find.text('focussayaç · Google Play'), findsOneWidget, reason: '$template');
    }

    await _disposeTree(tester);
  });

  testWidgets('PAYLAŞ görselin yanında mağaza adresini de gönderiyor',
      (WidgetTester tester) async {
    _usePhoneSurface(tester);
    await initializeDateFormatting('tr_TR');
    final AppDatabase database = await _newDatabase(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final _RecordingExporter exporter = _RecordingExporter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          adServiceProvider.overrideWithValue(AdService.disabled()),
          notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
          onboardingCompletedAtLaunchProvider.overrideWithValue(true),
          storyCardExporterProvider.overrideWithValue(exporter),
        ],
        child: localizedTestApp(const StoryCardScreen()),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('PAYLAŞ'));
    await _settle(tester);

    // Varsayılan şablon GECE MEŞALESİ — cümlesi tam, sonunda mağaza adresi.
    expect(exporter.sharedText, isNotNull);
    expect(exporter.sharedText, startsWith('Bugün '));
    expect(exporter.sharedText, endsWith('focussayaç ile: $kPlayStoreUrl'));

    await _disposeTree(tester);
  });

  testWidgets('kaydetme izni reddedilirse kullanıcıya söyleniyor', (WidgetTester tester) async {
    _usePhoneSurface(tester);
    await initializeDateFormatting('tr_TR');
    final AppDatabase database = await _newDatabase(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          adServiceProvider.overrideWithValue(AdService.disabled()),
          notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
          onboardingCompletedAtLaunchProvider.overrideWithValue(true),
          storyCardExporterProvider.overrideWithValue(const _DeniedExporter()),
        ],
        child: localizedTestApp(const StoryCardScreen()),
      ),
    );
    await _settle(tester);

    await tester.tap(find.text('Kaydet'));
    await _settle(tester);

    // İzin reddi "kaydedilemedi" ile aynı şey değil — kullanıcının
    // yapabileceği bir şey var.
    expect(find.text('Galeriye kaydetmek için izin gerekiyor.'), findsOneWidget);

    await _disposeTree(tester);
  });
}

/// Eklenti kanalı olmayan koşumda gerçek galeri çağrısını taklit eder.
class _DeniedExporter extends StoryCardExporter {
  const _DeniedExporter();

  @override
  Future<StoryCardExportResult> saveToGallery(GlobalKey boundaryKey) async {
    return StoryCardExportResult.permissionDenied;
  }
}

/// Sistem paylaşım sayfasını açmadan, ekranın gönderdiği metni yakalar.
class _RecordingExporter extends StoryCardExporter {
  _RecordingExporter();

  String? sharedText;

  @override
  Future<StoryCardExportResult> share(GlobalKey boundaryKey, {required String text}) async {
    sharedText = text;
    return StoryCardExportResult.success;
  }
}
