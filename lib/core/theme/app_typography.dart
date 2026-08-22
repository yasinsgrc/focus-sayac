import 'package:flutter/material.dart';

/// FocusSayaç yazı tipi aileleri — üçü de `assets/fonts` altında subset paketlenir.
abstract final class AppFonts {
  /// Başlıklar, `letter-spacing: -.045em`.
  static const String display = 'Space Grotesk';

  /// Kicker/etiket, yalnız büyük harf + rakam, `letter-spacing: .26em`.
  static const String mono = 'Michroma';

  /// Gövde metni.
  static const String body = 'Inter';
}

/// Prototipin üç fontluk tipografi sistemi için stil üreticileri.
///
/// Her ekranın kendine özgü boyutları vardır (bkz. ilgili faz); bu sınıf yalnız
/// aile/letter-spacing/tabular-figures kurallarını merkezileştirir.
abstract final class AppTypography {
  /// Space Grotesk başlık/sayaç stili. `letter-spacing: -.045em` (fontSize'a göre).
  static TextStyle display({
    required double fontSize,
    FontWeight weight = FontWeight.w500,
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

  /// Michroma kicker/etiket stili. Metin çağıran tarafta uppercase edilmelidir.
  static TextStyle kicker({
    required double fontSize,
    Color? color,
    double letterSpacingEm = 0.26,
  }) {
    return TextStyle(
      fontFamily: AppFonts.mono,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: fontSize * letterSpacingEm,
      color: color,
    );
  }

  /// Inter gövde metni.
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
