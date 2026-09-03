import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/main.dart';
import 'package:focussayac/services/notifications/notification_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_providers.dart';

/// Ekran 02'yi, hiçbir sınavın aktif olmadığı bir veritabanıyla ayağa
/// kaldırır. `write` await edildiği için `onCreate` (varsayılan ayarlar +
/// sınav tohumlaması; tohumlama bir satırı aktif işaretler) bu noktada
/// tamamlanmış olur; hemen ardından tüm satırların bayrağı düşürülüyor —
/// aktif sınavı silinmiş / hiç seçmemiş kullanıcının gördüğü durum.
Future<void> _pumpWithoutActiveExam(WidgetTester tester) async {
  // Diğer testler gerçek telefon boyunu (390×844) taklit ediyor; burada
  // yüzey daha geniş: test ortamında gerçek yazı tipleri yüklenmediği için
  // her karakter font boyu kadar kare çiziliyor ve alt sayfanın başlık
  // satırı ("SINAV SEÇ" + "RESMÎ TAKVİMDEN DOĞRULA") 390px'te sahte bir
  // taşma bildiriyor. Test edilen davranış genişlikten bağımsız.
  tester.view.physicalSize = const Size(700, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase.forTesting(NativeDatabase.memory());
  await database.update(database.exams).write(const ExamsCompanion(isActive: Value<bool>(false)));

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(NotificationService.disabled()),
      ],
      child: const FocusSayacApp(),
    ),
  );
  // `pumpAndSettle` kullanılmıyor (widget_test.dart'taki gerekçe) — DB
  // tohumlama + stream yayını için birkaç kare pompalanıyor.
  await tester.pump();
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ekranın `Timer.periodic` tikleyicisini durdurur (widget_test.dart'taki
/// drift kapatma gerekçesinin aynısı geçerli: `database.close()` çağrılmıyor).
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  // Regresyon: `exam == null` dalı `SizedBox.shrink()` döndürüyordu; ekranda
  // yalnızca alt gezinme çubuğu kalıyor, sekmelerinin hiçbiri sınav seçimine
  // gitmediği için kullanıcı geri sayıma dönemiyordu.
  testWidgets('aktif sınav yokken boş durum ve sınav seçme çıkışı gösterilir', (WidgetTester tester) async {
    await _pumpWithoutActiveExam(tester);

    expect(find.text('HEDEF SEÇİLMEDİ'), findsOneWidget);
    expect(find.text('GÜN KALDI'), findsNothing);

    await tester.tap(find.text('SINAV SEÇ'));
    await tester.pump();
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Alt sayfa açıldı: hem hazır sınav listesi hem "kendi sınavımı ekle"
    // çıkışı buradan erişilebilir.
    expect(find.text('Kendi sınavımı ekle'), findsOneWidget);

    await _disposeTree(tester);
  });
}
