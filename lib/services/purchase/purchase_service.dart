import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../storage/app_database.dart';
import '../storage/daos/app_settings_dao.dart';
import '../storage/storage_providers.dart';

/// SPEC.md §7.3'ün tek ürünü: kalıcı reklamsız sürüm (tüketilebilir değil).
const String kProLifetimeProductId = 'pro_lifetime';

final Provider<PurchaseService> purchaseServiceProvider = Provider<PurchaseService>((Ref ref) {
  final PurchaseService service = PurchaseService(
    appSettingsDao: ref.watch(appSettingsDaoProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// SPEC.md §7.3: `pro_lifetime` akışı **tam kodlanır, UI pasif kalır**.
/// "Bir sonraki sürümde tek satır değişiklikle açılır" gereği bu sınıfın
/// eksiksiz olmasını istiyor: ürün sorgusu, satın alma, mağaza tarafından
/// başlatılan/geri yüklenen işlemler ve `completePurchase`.
///
/// v1'de **hiçbir çağıranı yok** (ayarlardaki satır pasif). Açılacağı sürümde
/// `main.dart` [start]'ı, ayarlardaki satır da [buyProLifetime]'ı çağırır;
/// premium bayrağını yazan yol zaten burada ve testlidir.
class PurchaseService {
  PurchaseService({
    required AppSettingsDao appSettingsDao,
    InAppPurchase? inAppPurchase,
  })  : _appSettingsDao = appSettingsDao,
        _iap = inAppPurchase ?? InAppPurchase.instance;

  final AppSettingsDao _appSettingsDao;
  final InAppPurchase _iap;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Akışa abone olur. Mağaza tarafından başlatılan ve önceki oturumdan
  /// tamamlanmamış işlemler de buradan geldiği için, satın alma açıldığında
  /// uygulama başlangıcında çağrılmalıdır (eklentinin kendi uyarısı).
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _iap.purchaseStream.listen(
      handlePurchaseUpdates,
      // Akış hatası satın almayı bozmaz, yalnızca o güncellemeyi kaybettirir;
      // kullanıcıya gösterilecek bir şey yok (sonucu bir sonraki güncelleme
      // ya da `restorePurchases` yine getirir).
      onError: (Object error, StackTrace stackTrace) {},
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Mağaza kullanılabilir değilse (cihazda Play yok, ülke desteklemiyor)
  /// `null`.
  Future<ProductDetails?> loadProLifetimeProduct() async {
    final bool? available = await _guarded(_iap.isAvailable);
    if (available != true) return null;
    final ProductDetailsResponse? response =
        await _guarded(() => _iap.queryProductDetails(<String>{kProLifetimeProductId}));
    if (response == null) return null;
    for (final ProductDetails product in response.productDetails) {
      if (product.id == kProLifetimeProductId) return product;
    }
    return null;
  }

  /// Satın alma **isteğinin** gönderilip gönderilmediğini döndürür; sonucu
  /// [handlePurchaseUpdates] getirir (eklentinin sözleşmesi).
  Future<bool> buyProLifetime() async {
    final ProductDetails? product = await loadProLifetimeProduct();
    if (product == null) return false;
    final bool? started = await _guarded(
      () => _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product)),
    );
    return started ?? false;
  }

  /// Cihaz değiştiren kullanıcının hakkını geri verir. Sonuç yine
  /// [handlePurchaseUpdates]'e `PurchaseStatus.restored` olarak düşer.
  Future<void> restorePurchases() async {
    await _guarded(_iap.restorePurchases);
  }

  @visibleForTesting
  Future<void> handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.productID != kProLifetimeProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantPremium();
        case PurchaseStatus.pending:
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          break;
      }
      // Hata/iptal dahil, tamamlanmayı bekleyen her işlem kapatılıyor: açık
      // bırakılan işlem her açılışta yeniden yayınlanır ve aynı ürünün ikinci
      // satın alma denemesini "beklemede" hatasıyla bloklar (eklenti uyarısı).
      if (purchase.pendingCompletePurchase) {
        await _guarded(() => _iap.completePurchase(purchase));
      }
    }
  }

  Future<void> _grantPremium() async {
    final AppSettingsTableData settings = await _appSettingsDao.getSettings();
    if (settings.isPremium) return;
    await _appSettingsDao.updateSettings(
      const AppSettingsTableCompanion(isPremium: Value<bool>(true)),
    );
  }

  /// `AppReviewService._guarded` ile aynı gerekçe: mağaza kanalı olmayan
  /// koşumlarda (testler, mağazasız cihaz) sessizce "satın alma yok"a düşer.
  Future<T?> _guarded<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on InAppPurchaseException {
      return null;
    }
  }
}
