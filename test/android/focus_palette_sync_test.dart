import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/domain/widgets/home_widget_snapshot.dart';

/// Ana ekran widgetlari Flutter tema agacina erisemedigi icin palet
/// `android/app/src/main/res/values/focus_colors.xml` icinde bir kez daha
/// tanimli. Bu test iki kopyanin ayrismasini yakalar.
///
/// Secilen mimarinin bilinen tek zayif noktasi buydu (bkz.
/// docs/superpowers/specs/2026-09-04-home-widgets-design.md, Riskler);
/// sessiz kalmasin diye otomatiklestirildi.
void main() {
  const String xmlPath = 'android/app/src/main/res/values/focus_colors.xml';

  /// `<color name="focus_ember">#FFFFB03A</color>` satirlarini okur.
  Map<String, String> readAndroidPalette() {
    final File file = File(xmlPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$xmlPath bulunamadi - widget paleti kaldirilmis olabilir',
    );

    final RegExp pattern =
        RegExp(r'<color\s+name="([^"]+)"\s*>\s*(#[0-9A-Fa-f]{8})\s*</color>');
    final Map<String, String> result = <String, String>{};
    for (final RegExpMatch match in pattern.allMatches(file.readAsStringSync())) {
      result[match.group(1)!] = match.group(2)!.toUpperCase();
    }
    return result;
  }

  final AppColors dark = AppColors.dark();

  /// XML adi -> Dart tokeni. Yeni bir token eklendiginde bu harita da
  /// buyur; eksik birakilan token asagidaki kapsam testinde yakalanir.
  final Map<String, Color> expected = <String, Color>{
    'focus_bg': dark.bg,
    'focus_text': dark.text,
    'focus_ember': dark.ember,
    'focus_ember_dim': dark.emberDim,
    'focus_ember_deep': dark.emberDeep,
    'focus_mint': dark.mint,
    'focus_mint_deep': dark.mintDeep,
    'focus_rose': dark.rose,
    'focus_rose_deep': dark.roseDeep,
    'focus_sky': dark.sky,
    'focus_sky_deep': dark.skyDeep,
    'focus_neutral_300': dark.neutral300,
    'focus_neutral_400': dark.neutral400,
    'focus_neutral_500': dark.neutral500,
    'focus_neutral_600': dark.neutral600,
    'focus_neutral_700': dark.neutral700,
    'focus_neutral_800': dark.neutral800,
    'focus_neutral_900': dark.neutral900,
    'focus_accent_200': dark.accent200,
    'focus_accent_300': dark.accent300,
    'focus_accent_400': dark.accent400,
    'focus_accent_900': dark.accent900,
    'focus_surface_card': dark.surfaceCard,
    'focus_divider': dark.divider,
  };

  test('Android paleti AppColors.dark ile birebir ayni', () {
    final Map<String, String> android = readAndroidPalette();

    expected.forEach((String name, Color color) {
      expect(
        android[name],
        HomeWidgetSnapshot.toHex(color),
        reason: '$name Dart paletinden sapmis',
      );
    });
  });

  test('XML fazladan veya eksik token tasimiyor', () {
    // Tek yonlu kontrol yetmez: XMLden silinen bir token yukaridaki
    // dongude "null == null" ile sessizce gecebilirdi.
    final Map<String, String> android = readAndroidPalette();
    expect(android.keys.toSet(), expected.keys.toSet());
  });
}
