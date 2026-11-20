import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:focussayac/services/ads/ad_service.dart';
import 'package:focussayac/services/purchase/purchase_service.dart';
import 'package:focussayac/services/storage/app_database.dart';

/// `InAppPurchase`ın testte kontrol edilebilir hâli. Eklentinin kanalını
/// taklit etmek yerine sınıfı `implements` ediyoruz: satın alma sonucu
/// **akıştan** geliyor ve testin doğrulaması gereken şey bu akışın
/// `isPremium`e nasıl çevrildiği.
class _FakeInAppPurchase implements InAppPurchase {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseDetails> completedPurchases = <PurchaseDetails>[];
  final List<ProductDetails> products = <ProductDetails>[
    ProductDetails(
      id: kProLifetimeProductId,
      title: 'Reklamsız',
      description: 'Kalıcı reklamsız sürüm',
      price: '₺149,00',
      rawPrice: 149,
      currencyCode: 'TRY',
    ),
  ];

  bool available = true;
  bool restoreCalled = false;

  /// Hesapta önceden satın alınmış işlemler; `restorePurchases` bunları
  /// akışa `restored` olarak yayınlar (Play'in davranışı).
  final List<PurchaseDetails> owned = <PurchaseDetails>[];
  PurchaseParam? boughtParam;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    return ProductDetailsResponse(
      productDetails: products.where((ProductDetails p) => identifiers.contains(p.id)).toList(),
      notFoundIDs: identifiers
          .where((String id) => !products.any((ProductDetails p) => p.id == id))
          .toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    boughtParam = purchaseParam;
    return true;
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) {
    // `pro_lifetime` tüketilebilir değil; çağrılması testin kendisi için hata.
    throw UnsupportedError('pro_lifetime tüketilebilir bir ürün değil');
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalled = true;
    if (owned.isNotEmpty) controller.add(List<PurchaseDetails>.of(owned));
  }

  @override
  Future<String> countryCode() async => 'TR';

  Future<void> close() => controller.close();

  /// `getPlatformAddition` mağazaya özel eklentileri döndürüyor ve testte hiç
  /// çağrılmıyor; imzasındaki tür `in_app_purchase`ten dışa aktarılmadığı
  /// için elle yazmak yalnızca bu tür uğruna bir paket bağımlılığı eklemek
  /// olurdu. Eksik üyeleri Dart'ın `noSuchMethod` iletimi karşılıyor.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails _purchase(String productId, PurchaseStatus status, {bool pendingComplete = true}) {
  final PurchaseDetails details = PurchaseDetails(
    purchaseID: 'test-purchase',
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'test',
    ),
    transactionDate: '1772582400000',
    status: status,
  );
  details.pendingCompletePurchase = pendingComplete;
  return details;
}

void main() {
  // `AppDatabase.forTesting` tohumlama sırasında `assets/data/exam_dates.json`
  // okuyor; asset paketi ancak binding kurulduktan sonra erişilebilir.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late _FakeInAppPurchase iap;
  late PurchaseService service;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.appSettingsDao.getSettings();
    iap = _FakeInAppPurchase();
    service = PurchaseService(appSettingsDao: database.appSettingsDao, inAppPurchase: iap);
  });

  tearDown(() async {
    await service.dispose();
    await iap.close();
    await database.close();
  });

  Future<bool> isPremium() async => (await database.appSettingsDao.getSettings()).isPremium;

  test('satın alınan pro_lifetime premium yazıyor ve işlemi kapatıyor', () async {
    await service.handlePurchaseUpdates(<PurchaseDetails>[
      _purchase(kProLifetimeProductId, PurchaseStatus.purchased),
    ]);

    expect(await isPremium(), isTrue);
    expect(iap.completedPurchases, hasLength(1));
  });

  // Cihaz değiştiren kullanıcı: `restored` da hakkı geri vermek zorunda.
  test('geri yüklenen pro_lifetime premium yazıyor', () async {
    await service.handlePurchaseUpdates(<PurchaseDetails>[
      _purchase(kProLifetimeProductId, PurchaseStatus.restored),
    ]);

    expect(await isPremium(), isTrue);
  });

  test('beklemedeki işlem premium yazmıyor ve kapatılmıyor', () async {
    await service.handlePurchaseUpdates(<PurchaseDetails>[
      _purchase(kProLifetimeProductId, PurchaseStatus.pending, pendingComplete: false),
    ]);

    expect(await isPremium(), isFalse);
    expect(iap.completedPurchases, isEmpty);
  });

  // Hata/iptal premium vermez ama işlem açık bırakılmaz: açık kalan işlem
  // ikinci satın alma denemesini bloklardı.
  test('hatalı işlem premium yazmıyor, yine de kapatılıyor', () async {
    await service.handlePurchaseUpdates(<PurchaseDetails>[
      _purchase(kProLifetimeProductId, PurchaseStatus.error),
    ]);

    expect(await isPremium(), isFalse);
    expect(iap.completedPurchases, hasLength(1));
  });

  test('başka bir ürünün satın alınması premium yazmıyor', () async {
    await service.handlePurchaseUpdates(<PurchaseDetails>[
      _purchase('some_other_product', PurchaseStatus.purchased),
    ]);

    expect(await isPremium(), isFalse);
    expect(iap.completedPurchases, isEmpty);
  });

  test('start() akışı dinliyor: mağazadan gelen güncelleme premium yazıyor', () async {
    await service.start();
    iap.controller
        .add(<PurchaseDetails>[_purchase(kProLifetimeProductId, PurchaseStatus.purchased)]);
    // Yayın akışı asenkron; dinleyicinin ve DB yazımının tamamlanması için
    // birkaç mikro-görev turu bekleniyor.
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(await isPremium(), isTrue);
  });

  test('buyProLifetime doğru ürünle satın almayı başlatıyor', () async {
    expect(await service.buyProLifetime(), isTrue);
    expect(iap.boughtParam?.productDetails.id, kProLifetimeProductId);
  });

  test('mağaza kullanılamıyorsa satın alma başlamıyor', () async {
    iap.available = false;

    expect(await service.loadProLifetimeProduct(), isNull);
    expect(await service.buyProLifetime(), isFalse);
    expect(iap.boughtParam, isNull);
  });

  test('restorePurchases mağazaya iletiliyor', () async {
    await service.restorePurchases();

    expect(iap.restoreCalled, isTrue);
  });

  Future<void> drainStream() async {
    for (int i = 0; i < 8; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('restorePurchases sonrası restored durumu premium veriyor', () async {
    iap.owned.add(_purchase(kProLifetimeProductId, PurchaseStatus.restored));
    await service.start();

    await service.restorePurchases();
    await drainStream();

    expect(await isPremium(), isTrue);
    expect(iap.completedPurchases, hasLength(1));
  });

  test('hesapta satın alma yoksa geri yükleme premium vermiyor', () async {
    await service.start();

    await service.restorePurchases();
    await drainStream();

    expect(await isPremium(), isFalse);
  });

  // SPEC.md §7.3: satın almanın yazdığı bayrak reklam kapısını kapatıyor —
  // banner da geçiş reklamı da `AdService.canRequestAds`ten geçiyor.
  test('satın alma sonrası AdService hiçbir reklam istemiyor', () async {
    final AdService adService = AdService(
      readIsPremium: () async => (await database.appSettingsDao.getSettings()).isPremium,
      readConsentAllowsAds: () async => true,
    );
    expect(await adService.canRequestAds(), isTrue);

    await service.handlePurchaseUpdates(<PurchaseDetails>[
      _purchase(kProLifetimeProductId, PurchaseStatus.purchased),
    ]);

    expect(await adService.canRequestAds(), isFalse);
  });
}
