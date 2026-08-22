import 'package:flutter/material.dart';

/// FocusSayaç renk tokenları — prototipteki `:root` değişkenlerinden birebir.
/// Widget'larda ham `Color(0x...)` veya `Colors.*` kullanmak yerine
/// `Theme.of(context).extension<AppColors>()!` üzerinden erişilir.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
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
    required this.divider,
  });

  factory AppColors.dark() => const AppColors(
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
        divider: Color(0x14FFFFFF),
      );

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

  final Color surfaceCard;
  final Color divider;

  /// Prototipin `--chrome` gradyanı: krom tipografi için `ShaderMask` ile kullanılır.
  static const List<Color> chromeGradient = <Color>[
    Color(0xFFF6F7FF),
    Color(0xFFB5ABFC),
    Color(0xFF63B4FF),
    Color(0xFFFFB03A),
    Color(0xFFFFFFFF),
  ];
  static const List<double> chromeGradientStops = <double>[0, 0.34, 0.52, 0.78, 1];

  @override
  AppColors copyWith({
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
    Color? divider,
  }) {
    return AppColors(
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
      divider: divider ?? this.divider,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
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
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
