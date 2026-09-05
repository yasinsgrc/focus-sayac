import 'package:flutter/material.dart';

/// FocusSayaç renk tokenları. Koyu set prototipteki `:root` değişkenlerinden
/// birebir; açık set onun anlamsal aynası (SPEC dışı, Faz 17 kararı).
/// Widget'larda ham `Color(0x...)` veya `Colors.*` kullanmak yerine
/// `Theme.of(context).extension<AppColors>()!` üzerinden erişilir.
///
/// **Anlamsal eşleme kuralı:** açık varyant "aynı rengin açığı" değil, aynı
/// *rolün* açık zemindeki karşılığıdır. Nötr rampa bu yüzden ters çevrilir —
/// `neutral300` koyuda en açık ikincil metin, açıkta en koyu ikincil metindir.
/// Böylece 90 küsur çağrı yerinin hiçbiri değişmeden iki temada da doğru
/// kontrastı tutturur.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.bg,
    required this.text,
    required this.ember,
    required this.emberDim,
    required this.emberDeep,
    required this.mint,
    required this.mintDeep,
    required this.rose,
    required this.roseDeep,
    required this.sky,
    required this.skyDeep,
    required this.neutral300,
    required this.neutral400,
    required this.neutral500,
    required this.neutral600,
    required this.neutral700,
    required this.neutral800,
    required this.neutral900,
    required this.accent200,
    required this.accent300,
    required this.accent400,
    required this.accent900,
    required this.surfaceCard,
    required this.surfaceCardSoft,
    required this.surfaceCardStrong,
    required this.surfaceSheet,
    required this.surfaceDialog,
    required this.surfaceSunken,
    required this.surfaceNav,
    required this.divider,
    required this.hairline,
    required this.borderSubtle,
    required this.borderStrong,
    required this.fillFaint,
    required this.fillSubtle,
    required this.fillMedium,
    required this.fillStrong,
    required this.scrim,
    required this.glowViolet,
    required this.chromeGradient,
  });

  factory AppColors.dark() => const AppColors(
        brightness: Brightness.dark,
        bg: Color(0xFF0B0C14),
        text: Color(0xFFF6F7FF),
        ember: Color(0xFFFFB03A),
        emberDim: Color(0xFF8A4F14),
        emberDeep: Color(0xFF33200C),
        mint: Color(0xFF4FE0B4),
        mintDeep: Color(0xFF0D3A31),
        rose: Color(0xFFFF6A86),
        roseDeep: Color(0xFF3D1420),
        sky: Color(0xFF63B4FF),
        skyDeep: Color(0xFF10283F),
        neutral300: Color(0xFFCFD3E5),
        neutral400: Color(0xFFB2B6CA),
        neutral500: Color(0xFF9397AB),
        neutral600: Color(0xFF75798C),
        neutral700: Color(0xFF595D6C),
        neutral800: Color(0xFF3F424D),
        neutral900: Color(0xFF292B31),
        accent200: Color(0xFFE7E5FE),
        accent300: Color(0xFFD2CEFD),
        accent400: Color(0xFFB5ABFC),
        accent900: Color(0xFF2B2741),
        surfaceCard: Color(0xD11E2030),
        surfaceCardSoft: Color(0xB81E2030),
        surfaceCardStrong: Color(0xDB1E2030),
        surfaceSheet: Color(0xF5181A28),
        surfaceDialog: Color(0xF61A1C2A),
        surfaceSunken: Color(0xFF12131C),
        surfaceNav: Color(0xC7181A28),
        divider: Color(0x14FFFFFF),
        hairline: Color(0x12FFFFFF),
        borderSubtle: Color(0x1AFFFFFF),
        borderStrong: Color(0x24FFFFFF),
        fillFaint: Color(0x0DFFFFFF),
        fillSubtle: Color(0x17FFFFFF),
        fillMedium: Color(0x1FFFFFFF),
        fillStrong: Color(0x33FFFFFF),
        scrim: Color(0xAD04050A),
        glowViolet: Color(0xFF9184D9),
        chromeGradient: <Color>[
          Color(0xFFF6F7FF),
          Color(0xFFB5ABFC),
          Color(0xFF63B4FF),
          Color(0xFFFFB03A),
          Color(0xFFFFFFFF),
        ],
      );

  /// Açık tema. Vurgu renkleri koyu setin "aynısı" değil, açık zeminde
  /// WCAG AA (>=4.5:1 metin) tutturan koyulaştırılmış karşılıkları — ham
  /// `#FFB03A` beyaz üzerinde 1.8:1 ile okunamaz durumda kalıyordu.
  /// Oranları `test/core/theme/light_palette_contrast_test.dart` sabitliyor;
  /// bir tokenı açmaya kalkan değişiklik orada düşer.
  /// Dekoratif ember (alev, geri sayım halkası) kendi gradyan duraklarını
  /// taşıdığı için parlak kalır; koyulaşan yalnızca anlamsal `ember` tokenı.
  factory AppColors.light() => const AppColors(
        brightness: Brightness.light,
        bg: Color(0xFFF4F5FA),
        text: Color(0xFF14161F),
        ember: Color(0xFFA35D00),
        emberDim: Color(0xFFFFD79A),
        emberDeep: Color(0xFFFFF1D9),
        mint: Color(0xFF0B7A5E),
        mintDeep: Color(0xFFD8F7EC),
        rose: Color(0xFFC82848),
        roseDeep: Color(0xFFFDE1E7),
        sky: Color(0xFF1E6FC0),
        skyDeep: Color(0xFFDCEBFA),
        // Ters rampa: koyudaki "en açık nötr" burada "en koyu nötr".
        neutral300: Color(0xFF3A3E4E),
        neutral400: Color(0xFF4E5264),
        neutral500: Color(0xFF63677A),
        neutral600: Color(0xFF7C8093),
        neutral700: Color(0xFF9BA0B2),
        neutral800: Color(0xFFC4C8D6),
        neutral900: Color(0xFFE2E5EE),
        accent200: Color(0xFF2E2856),
        accent300: Color(0xFF4A3FA0),
        accent400: Color(0xFF5A4BD0),
        accent900: Color(0xFFEAE7FD),
        surfaceCard: Color(0xD1FFFFFF),
        surfaceCardSoft: Color(0xB8FFFFFF),
        surfaceCardStrong: Color(0xDBFFFFFF),
        surfaceSheet: Color(0xF7FFFFFF),
        surfaceDialog: Color(0xF9FFFFFF),
        // Koyuda `surfaceSunken` zeminden bir tık **açık** (yükselti), açıkta
        // aynı "ayrı düzlem" hissi bir tık **koyu** olmakla veriliyor.
        surfaceSunken: Color(0xFFE9EBF3),
        surfaceNav: Color(0xD6FFFFFF),
        divider: Color(0x14000000),
        hairline: Color(0x12000000),
        borderSubtle: Color(0x1A000000),
        borderStrong: Color(0x24000000),
        fillFaint: Color(0x0D000000),
        fillSubtle: Color(0x14000000),
        fillMedium: Color(0x18000000),
        // Siyah bindirme açık zeminde beyazın koyu zemindekinden daha güçlü
        // okunuyor; `fillStrong` bu yüzden 0x33 yerine 0x26.
        fillStrong: Color(0x26000000),
        scrim: Color(0x66151726),
        glowViolet: Color(0xFF6E5FD0),
        chromeGradient: <Color>[
          Color(0xFF1A1C2A),
          Color(0xFF5A4BD0),
          Color(0xFF1E6FC0),
          Color(0xFFA35D00),
          Color(0xFF14161F),
        ],
      );

  /// Hangi setin yürürlükte olduğunu soran nadir çağrı yerleri için
  /// (ör. gölge sertliği, `SystemUiOverlayStyle`).
  final Brightness brightness;

  /// `ember` = ateş, seri, aktif odak.
  final Color ember;
  final Color emberDim;
  final Color emberDeep;

  /// `mint` = tamamlanan iş, başarı.
  final Color mint;
  final Color mintDeep;

  /// `rose` = iptal, risk, uyarı.
  final Color rose;
  final Color roseDeep;

  /// `sky` = veri, istatistik.
  final Color sky;
  final Color skyDeep;

  final Color bg;
  final Color text;

  final Color neutral300;
  final Color neutral400;
  final Color neutral500;
  final Color neutral600;
  final Color neutral700;
  final Color neutral800;
  final Color neutral900;

  /// `accent` (mor) = ikincil vurgu, izin/bilgi.
  final Color accent200;
  final Color accent300;
  final Color accent400;
  final Color accent900;

  /// Yüzey basamakları — hepsi zeminin üstünde yarı saydam bir düzlem.
  /// Opaklık arttıkça öğe kullanıcıya "yaklaşır":
  /// `Soft` (kart) < `Card` < `Strong` (liste satırı) < `Nav`/`Sheet` < `Dialog`.
  final Color surfaceCard;
  final Color surfaceCardSoft;
  final Color surfaceCardStrong;
  final Color surfaceSheet;
  final Color surfaceDialog;

  /// Ayrı düzlemde duran, pasif/kilitli öğe zemini (kilitli rozet kutusu).
  final Color surfaceSunken;
  final Color surfaceNav;

  /// Çizgiler ve dolgular — ikisi de nötr bir bindirme, ayrımları güçlerinde.
  /// `divider`/`hairline` çizgi, `fill*` ise alan kaplar. Merdiven kapalı bir
  /// küme: çağrı yerlerindeki eski ham alfalar (0x0A, 0x0F, 0x29, 0x2E) en
  /// yakın basamağa yuvarlandı — aradaki fark 255'te 10'un altında ve gözle
  /// ayırt edilmiyor, karşılığında iki temada da tek kaynak var.
  final Color divider;
  final Color hairline;
  final Color borderSubtle;
  final Color borderStrong;
  final Color fillFaint;
  final Color fillSubtle;
  final Color fillMedium;
  final Color fillStrong;

  /// Diyalog/alt sayfa arkasındaki karartma.
  final Color scrim;

  /// Geri sayım ve onboarding'deki mor hâle (prototipin `#9184D9`'u).
  final Color glowViolet;

  /// Prototipin `--chrome` gradyanı: krom tipografi için `ShaderMask` ile
  /// kullanılır. Açık temada duraklar koyulaşır, yoksa beyaz zeminde kaybolur.
  final List<Color> chromeGradient;

  /// Duraklar iki temada da aynı — yalnız renkler değişiyor.
  static const List<double> chromeGradientStops = <double>[0, 0.34, 0.52, 0.78, 1];

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? bg,
    Color? text,
    Color? ember,
    Color? emberDim,
    Color? emberDeep,
    Color? mint,
    Color? mintDeep,
    Color? rose,
    Color? roseDeep,
    Color? sky,
    Color? skyDeep,
    Color? neutral300,
    Color? neutral400,
    Color? neutral500,
    Color? neutral600,
    Color? neutral700,
    Color? neutral800,
    Color? neutral900,
    Color? accent200,
    Color? accent300,
    Color? accent400,
    Color? accent900,
    Color? surfaceCard,
    Color? surfaceCardSoft,
    Color? surfaceCardStrong,
    Color? surfaceSheet,
    Color? surfaceDialog,
    Color? surfaceSunken,
    Color? surfaceNav,
    Color? divider,
    Color? hairline,
    Color? borderSubtle,
    Color? borderStrong,
    Color? fillFaint,
    Color? fillSubtle,
    Color? fillMedium,
    Color? fillStrong,
    Color? scrim,
    Color? glowViolet,
    List<Color>? chromeGradient,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      text: text ?? this.text,
      ember: ember ?? this.ember,
      emberDim: emberDim ?? this.emberDim,
      emberDeep: emberDeep ?? this.emberDeep,
      mint: mint ?? this.mint,
      mintDeep: mintDeep ?? this.mintDeep,
      rose: rose ?? this.rose,
      roseDeep: roseDeep ?? this.roseDeep,
      sky: sky ?? this.sky,
      skyDeep: skyDeep ?? this.skyDeep,
      neutral300: neutral300 ?? this.neutral300,
      neutral400: neutral400 ?? this.neutral400,
      neutral500: neutral500 ?? this.neutral500,
      neutral600: neutral600 ?? this.neutral600,
      neutral700: neutral700 ?? this.neutral700,
      neutral800: neutral800 ?? this.neutral800,
      neutral900: neutral900 ?? this.neutral900,
      accent200: accent200 ?? this.accent200,
      accent300: accent300 ?? this.accent300,
      accent400: accent400 ?? this.accent400,
      accent900: accent900 ?? this.accent900,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      surfaceCardSoft: surfaceCardSoft ?? this.surfaceCardSoft,
      surfaceCardStrong: surfaceCardStrong ?? this.surfaceCardStrong,
      surfaceSheet: surfaceSheet ?? this.surfaceSheet,
      surfaceDialog: surfaceDialog ?? this.surfaceDialog,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceNav: surfaceNav ?? this.surfaceNav,
      divider: divider ?? this.divider,
      hairline: hairline ?? this.hairline,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderStrong: borderStrong ?? this.borderStrong,
      fillFaint: fillFaint ?? this.fillFaint,
      fillSubtle: fillSubtle ?? this.fillSubtle,
      fillMedium: fillMedium ?? this.fillMedium,
      fillStrong: fillStrong ?? this.fillStrong,
      scrim: scrim ?? this.scrim,
      glowViolet: glowViolet ?? this.glowViolet,
      chromeGradient: chromeGradient ?? this.chromeGradient,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      // Ara karelerde tek bir "yarı aydınlık" yok; eşik geçilince değişiyor.
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      text: Color.lerp(text, other.text, t)!,
      ember: Color.lerp(ember, other.ember, t)!,
      emberDim: Color.lerp(emberDim, other.emberDim, t)!,
      emberDeep: Color.lerp(emberDeep, other.emberDeep, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      mintDeep: Color.lerp(mintDeep, other.mintDeep, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      roseDeep: Color.lerp(roseDeep, other.roseDeep, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      skyDeep: Color.lerp(skyDeep, other.skyDeep, t)!,
      neutral300: Color.lerp(neutral300, other.neutral300, t)!,
      neutral400: Color.lerp(neutral400, other.neutral400, t)!,
      neutral500: Color.lerp(neutral500, other.neutral500, t)!,
      neutral600: Color.lerp(neutral600, other.neutral600, t)!,
      neutral700: Color.lerp(neutral700, other.neutral700, t)!,
      neutral800: Color.lerp(neutral800, other.neutral800, t)!,
      neutral900: Color.lerp(neutral900, other.neutral900, t)!,
      accent200: Color.lerp(accent200, other.accent200, t)!,
      accent300: Color.lerp(accent300, other.accent300, t)!,
      accent400: Color.lerp(accent400, other.accent400, t)!,
      accent900: Color.lerp(accent900, other.accent900, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceCardSoft: Color.lerp(surfaceCardSoft, other.surfaceCardSoft, t)!,
      surfaceCardStrong: Color.lerp(surfaceCardStrong, other.surfaceCardStrong, t)!,
      surfaceSheet: Color.lerp(surfaceSheet, other.surfaceSheet, t)!,
      surfaceDialog: Color.lerp(surfaceDialog, other.surfaceDialog, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surfaceNav: Color.lerp(surfaceNav, other.surfaceNav, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      fillFaint: Color.lerp(fillFaint, other.fillFaint, t)!,
      fillSubtle: Color.lerp(fillSubtle, other.fillSubtle, t)!,
      fillMedium: Color.lerp(fillMedium, other.fillMedium, t)!,
      fillStrong: Color.lerp(fillStrong, other.fillStrong, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      glowViolet: Color.lerp(glowViolet, other.glowViolet, t)!,
      chromeGradient: <Color>[
        for (int i = 0; i < chromeGradient.length; i++)
          Color.lerp(chromeGradient[i], other.chromeGradient[i], t)!,
      ],
    );
  }
}
