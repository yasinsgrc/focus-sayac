import 'package:flutter/material.dart';

/// FocusSayaç hareket ölçeği — `app_spacing.dart` / `app_shadows.dart` ile aynı
/// desen. Uygulamanın hareketi **olay bazlı**: her token bir değer değiştiğinde,
/// bir dokunuşta ya da bir rota geçişinde bir kez çalışıp duran bir animasyona
/// aittir. SPEC.md §6.4'ün yasakladığı sınıf (boşta kare üreten sürekli
/// dekoratif animasyon) burada tanımlı değil.
abstract final class AppMotion {
  /// Dokunma geri bildirimi gibi "anında" hissettirmesi gereken geçişler.
  static const Duration instant = Duration(milliseconds: 120);

  /// Küçük yüzeyler (hap, rozet) için kısa geçiş.
  static const Duration fast = Duration(milliseconds: 180);

  /// Varsayılan geçiş: sayı yuvarlanması, rota geçişi.
  static const Duration base = Duration(milliseconds: 260);

  /// Büyük yüzeylerin akışı: halka oranı, renk geçişi.
  static const Duration slow = Duration(milliseconds: 420);

  /// Prototipin `animation:rise .6s` giriş süresi (`RiseIn`).
  static const Duration entrance = Duration(milliseconds: 600);

  /// Prototipin `.06s` basamak aralığı (`RiseIn` gecikme çarpanı).
  static const Duration step = Duration(milliseconds: 60);

  /// Giren öğe: hızlı başlar, yerine yumuşak oturur.
  static const Curve enter = Curves.easeOutCubic;

  /// Çıkan öğe: yavaş başlar, hızlanarak kaybolur.
  static const Curve exit = Curves.easeInCubic;

  /// Yerinde değişen değerler (sayı, oran) — iki ucu da yumuşak.
  static const Curve standard = Curves.easeInOutCubic;

  /// Vurgu: hedefi hafifçe aşıp geri gelir.
  static const Curve pop = Curves.easeOutBack;

  /// Erişilebilirlik kapısı: "hareketi azalt" açıkken süre sıfırlanır, içerik
  /// doğrudan son hâlinde çizilir. Kontrol tek yerde dursun diye çağıranlar
  /// `MediaQuery.disableAnimationsOf` yazmıyor, bu yardımcıdan geçiyor
  /// (`RiseIn` kendi içinde katmanı tamamen atladığı için istisna).
  static Duration respectingMotion(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
