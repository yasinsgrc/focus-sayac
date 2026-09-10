import 'package:flutter/material.dart';

/// FocusSayaç yazı tipi aileleri — ikisi de `assets/fonts` altında subset paketlenir.
abstract final class AppFonts {
  /// Gösterim yüzü: başlık, sayaç, kicker.
  static const String display = 'Space Grotesk';

  /// Okuma yüzü: arayüz etiketi ve gövde metni.
  static const String body = 'Inter';
}

/// Uygulamanın **tek** boyut ölçeği. `AppTypography` çağrılarında ham sayı
/// yerine buradaki sabitler kullanılır.
///
/// Ölçek neden var: tarama sırasında 107 çağrı yerinde **33 farklı** `fontSize`
/// bulundu — 20 başlık için 12 ayrı boyut (16/17/19/20/21/22/23/24/26/28/34/42),
/// etiketlerde 15.5/14.5/13.5, kicker'da 9.5/8.5/7.5. Hiçbiri bir adımın parçası
/// değildi; her ekran kendi boyutunu elle seçmişti. Aileler tutarlıyken bile
/// arayüzün "farklı fontlar" gibi okunmasının asıl sebebi buydu.
abstract final class AppTextSize {
  // --- Kicker (Space Grotesk, büyük harf) ---

  /// Yalnız grafik ekseni gibi sütun genişliğine sıkışan yerler.
  static const double kickerSm = 8;

  /// Varsayılan kicker.
  static const double kicker = 9;

  // --- Arayüz metni (Inter) ---

  /// Mikro: rozet içi sayı, küçük çip.
  static const double xs = 11;

  /// İnce yazı: ipucu, ikincil açıklama.
  static const double sm = 12;

  /// Varsayılan arayüz ve gövde boyutu.
  static const double md = 13;

  /// Vurgulu satır: birincil buton, liste satırı başlığı, alt başlık.
  static const double lg = 15;

  // --- Başlık (Space Grotesk) ---

  /// Satır içi başlık, sayaç birimi.
  static const double title = 17;

  /// Bölüm başlığı, alt sayfa başlığı.
  static const double titleLg = 20;

  /// Diyalog başlığı.
  static const double heading = 24;

  /// Ekran boş durum başlığı.
  static const double headingLg = 28;

  /// Sayfa başlığı.
  static const double hero = 34;

  /// Karşılama başlığı.
  static const double heroLg = 42;

  // --- Sayaç (Space Grotesk) ---
  //
  // Bunlar ekranın kahramanı; her biri tek bir ekrana ait olduğu için ölçeğin
  // başlık adımlarını izlemek zorunda değiller.

  /// İstatistik kutusu değeri.
  static const double counterSm = 30;

  /// "Bugün" saat/dakika sayacı.
  static const double counterMd = 38;

  /// İstatistik ekranı toplam süresi.
  static const double counterLg = 46;

  /// Odak/mola zamanlayıcısı.
  static const double counterXl = 72;

  /// Geri sayım gün rakamı.
  static const double counterHero = 100;
}

/// İki fontluk tipografi sistemi için stil üreticileri.
///
/// **Aile seçimi role bağlı, boyuta değil.** Tek eksen var:
///
/// - **Space Grotesk** → *gösterim*: [display], [counter], [kicker].
/// - **Inter** → *okuma*: [label], [body].
///
/// Bu kural, yerini aldığı "≥16px Space Grotesk / <16px Inter" eşiğinden daha
/// dayanıklı: eşik, aynı boyutta iki aile yan yana gelince (Ayarlar'da satır
/// etiketi Inter 13.5, diyalog aksiyonu Space Grotesk 13.5) hangisinin
/// seçileceğini söyleyemiyordu. Rol ekseninde böyle bir boşluk yok.
///
/// [label] ile [body] ayrımı: **satır sarabilen düzyazı** [body] (`height` 1.55),
/// **tek satırlık arayüz metni** [label] (`height` 1.12). İkisi de Inter; fark
/// satır kutusunda, ailede değil.
///
/// Boyutlar [AppTextSize] sabitlerinden gelir; çağrı yerinde ham sayı yazılmaz.
abstract final class AppTypography {
  /// Space Grotesk başlık stili. `letter-spacing: -.045em` (fontSize'a göre).
  ///
  /// Ağırlık kuralı: [AppTextSize.heading] ve üstü w700, altı w600 (varsayılan).
  static TextStyle display({
    required double fontSize,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double height = 1.12,
  }) {
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: fontSize,
      fontWeight: weight,
      letterSpacing: fontSize * -0.045,
      height: height,
      color: color,
    );
  }

  /// Space Grotesk ile çizilen sayaç rakamları — `tabularFigures` zorunlu (SPEC §2).
  static TextStyle counter({
    required double fontSize,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1,
    double letterSpacingEm = -0.045,
  }) {
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: fontSize,
      fontWeight: weight,
      letterSpacing: fontSize * letterSpacingEm,
      height: height,
      color: color,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// Büyük harf kicker/etiket. Metin çağıran tarafta uppercase edilmelidir —
  /// `KickerLabel` bunu kendisi yapar.
  ///
  /// Aile Michroma değil Space Grotesk: Michroma geniş, sci-fi bir gösterim
  /// yüzüydü ve diğer iki aileyle aynı sistemin parçası gibi okunmuyordu. Ayrıca
  /// subset'i 49 glifti — küçük harflerin tamamı, virgül, uzun tire, kesme
  /// işareti ve `Î` yoktu; kicker'a giren böyle bir karakter kelimenin ortasında
  /// sessizce sistem fontuna düşüyordu.
  ///
  /// Tracking Michroma'nın `.26em`'inden `.2em`'e indi: `.26` o yüzün zaten
  /// geniş gövdesi için ölçülmüştü, Space Grotesk'in dar kapitallerinde aynı
  /// değer harfleri dağıtıyor.
  static TextStyle kicker({
    required double fontSize,
    Color? color,
    double letterSpacingEm = 0.2,
    FontWeight weight = FontWeight.w500,
  }) {
    return TextStyle(
      fontFamily: AppFonts.display,
      fontSize: fontSize,
      fontWeight: weight,
      letterSpacing: fontSize * letterSpacingEm,
      color: color,
    );
  }

  /// Tek satırlık arayüz metni — buton etiketi, liste satırı başlığı, sağdaki
  /// değer, sayaç yanındaki birim.
  ///
  /// Aile [body] ile aynı (Inter) ama satır kutusu [display]'inkiyle birebir:
  /// `height` 1.12, yani bu rol devralınırken hiçbir yerde dikey kayma olmuyor.
  /// [body]'nin 1.55'i paragraf içindir; tek satırda butonu gereksiz şişirirdi.
  ///
  /// [display]'in `fontSize * -0.045` tracking'i **taşınmıyor**: o sıkışma
  /// Space Grotesk'in geniş gövdesini toparlamak için var, Inter bu boyutlarda
  /// nötr tracking'de okunuyor.
  static TextStyle label({
    required double fontSize,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double height = 1.12,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontSize: fontSize,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  /// Inter gövde metni — satır sarabilen düzyazı.
  static TextStyle body({
    required double fontSize,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.55,
  }) {
    return TextStyle(
      fontFamily: AppFonts.body,
      fontSize: fontSize,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }
}
