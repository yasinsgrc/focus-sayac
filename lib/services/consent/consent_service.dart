import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// SPEC.md §7 reklam akışının izin kapısı. `main.dart` gerçek
/// [ConsentService] örneğiyle geçersiz kılar; testler
/// [ConsentService.disabled] ile — `notificationServiceProvider` ile aynı DI
/// kalıbı (SPEC §1 "singleton servisler yasak", Faz 6 kararı).
final Provider<ConsentService> consentServiceProvider = Provider<ConsentService>((Ref ref) {
  throw UnimplementedError('consentServiceProvider main.dart içinde override edilmeli.');
});

/// UMP (User Messaging Platform) onay akışı — SPEC.md Ekran 01: "UMP Consent
/// akışı burada, **ilk reklam isteğinden önce**". Yasal zorunluluk olduğu için
/// reklamlar (Faz 11) gelmeden önce, onboarding'in bitişinde çalışır.
///
/// [ConsentService.disabled] tüm çağrıları no-op yapar
/// (`NotificationService.disabled` ve `AppDatabase.forTesting` ile aynı
/// kalıp). Sahte bir `ConsentInformation` enjekte etmek yerine servisin
/// tamamının kapatılabilir olması gerekiyor: eklenti
/// `requestConsentInfoUpdate` içindeki kanal çağrısını **kendi** async
/// gövdesinde yapıp yalnızca `PlatformException`ı yakalıyor, kanalın hiç
/// olmadığı koşumlarda (widget testleri) atılan `MissingPluginException`
/// dışarıdan yakalanamıyor.
class ConsentService {
  ConsentService() : _consentInformation = ConsentInformation.instance;

  ConsentService.disabled() : _consentInformation = null;

  final ConsentInformation? _consentInformation;

  /// Onay bilgisini tazeler ve gerekiyorsa UMP formunu gösterir. Akışın
  /// herhangi bir adımı başarısız olursa **sessizce** geçilir: onay
  /// alınamadığında doğru davranış kullanıcıyı onboarding'de kilitlemek değil,
  /// reklamsız devam etmektir — reklam isteğinin koşulu [canRequestAds],
  /// onay durumu UMP SDK'sında saklı kalır.
  Future<void> gatherConsent() async {
    final ConsentInformation? consentInformation = _consentInformation;
    if (consentInformation == null) return;
    // `requestConsentInfoUpdate` geri-çağrı tabanlı; iki dinleyicisinden biri
    // her koşulda çağrıldığı için `Completer` ile beklenebilir hâle
    // getiriliyor. Hata dalı da `complete` ediyor — çağıran için "onay
    // tazelenemedi" ile "tazelendi, form gerekmiyor" aynı sonuca çıkıyor.
    final Completer<void> updated = Completer<void>();
    consentInformation.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      updated.complete,
      (FormError error) => updated.complete(),
    );
    await updated.future;
    await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {});
  }

  /// SPEC.md §7'nin yasal kapısı: UMP'ye göre reklam isteği atılabilir mi
  /// (`AdService.canRequestAds` bunu her istekten önce sorar). Onay durumu
  /// UMP SDK'sında saklı olduğu için burada önbelleğe alınmıyor — kullanıcı
  /// formu sonradan değiştirirse cevap kendiliğinden güncel kalıyor.
  ///
  /// Servis kapalıyken (testler) ve kanal hata verdiğinde `false`: bilinmeyen
  /// onay durumunda doğru davranış reklam **istememektir**.
  Future<bool> canRequestAds() async {
    final ConsentInformation? consentInformation = _consentInformation;
    if (consentInformation == null) return false;
    try {
      return await consentInformation.canRequestAds();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
