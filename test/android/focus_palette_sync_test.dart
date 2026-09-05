import 'dart:io';
import 'dart:ui' show Brightness, Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/domain/widgets/home_widget_snapshot.dart';

/// Ana ekran widgetlari ve splash Flutter tema agacina erisemedigi icin palet
/// Android kaynaklarinda bir kez daha tanimli - `values/focus_colors.xml`
/// acik, `values-night/focus_colors.xml` koyu. Bu test iki kopyanin da Dart
/// paletinden ayrismasini yakalar.
///
/// Secilen mimarinin bilinen tek zayif noktasi buydu (bkz.
/// docs/superpowers/specs/2026-09-04-home-widgets-design.md, Riskler);
/// sessiz kalmasin diye otomatiklestirildi.
void main() {
  /// `<color name="focus_ember">#FFFFB03A</color>` satirlarini okur.
  Map<String, String> readAndroidPalette(String xmlPath) {
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

  /// XML adi -> Dart tokeni. Yeni bir token eklendiginde bu harita da buyur;
  /// eksik birakilan token asagidaki kapsam testinde yakalanir.
  Map<String, Color> expectedFor(AppColors c) => <String, Color>{
        'focus_bg': c.bg,
        'focus_text': c.text,
        'focus_ember': c.ember,
        'focus_ember_dim': c.emberDim,
        'focus_ember_deep': c.emberDeep,
        'focus_mint': c.mint,
        'focus_mint_deep': c.mintDeep,
        'focus_rose': c.rose,
        'focus_rose_deep': c.roseDeep,
        'focus_sky': c.sky,
        'focus_sky_deep': c.skyDeep,
        'focus_neutral_300': c.neutral300,
        'focus_neutral_400': c.neutral400,
        'focus_neutral_500': c.neutral500,
        'focus_neutral_600': c.neutral600,
        'focus_neutral_700': c.neutral700,
        'focus_neutral_800': c.neutral800,
        'focus_neutral_900': c.neutral900,
        'focus_accent_200': c.accent200,
        'focus_accent_300': c.accent300,
        'focus_accent_400': c.accent400,
        'focus_accent_900': c.accent900,
        'focus_surface_card': c.surfaceCard,
        'focus_divider': c.divider,
      };

  /// Android niteleyici kurali: niteleyicisiz `values/` varsayilan, yani
  /// **acik**; `values-night/` yalnizca sistem koyu moddayken kazanir.
  final Map<String, AppColors> palettes = <String, AppColors>{
    'android/app/src/main/res/values/focus_colors.xml': AppColors.light(),
    'android/app/src/main/res/values-night/focus_colors.xml': AppColors.dark(),
  };

  palettes.forEach((String xmlPath, AppColors dartPalette) {
    final String label = dartPalette.brightness == Brightness.dark ? 'dark' : 'light';

    test('$xmlPath, AppColors.$label ile birebir ayni', () {
      final Map<String, String> android = readAndroidPalette(xmlPath);

      expectedFor(dartPalette).forEach((String name, Color color) {
        expect(
          android[name],
          HomeWidgetSnapshot.toHex(color),
          reason: '$name Dart paletinden sapmis ($xmlPath)',
        );
      });
    });

    test('$xmlPath fazladan veya eksik token tasimiyor', () {
      // Tek yonlu kontrol yetmez: XMLden silinen bir token yukaridaki
      // dongude "null == null" ile sessizce gecebilirdi.
      final Map<String, String> android = readAndroidPalette(xmlPath);
      expect(android.keys.toSet(), expectedFor(dartPalette).keys.toSet());
    });
  });

  test('iki XML ayni token kumesini tasiyor', () {
    // Biri buyuyup digeri geride kalirsa `getColor` yalnizca bir temada
    // cozulup digerinde calisma zamaninda patlardi.
    final List<Set<String>> keySets = palettes.keys
        .map((String path) => readAndroidPalette(path).keys.toSet())
        .toList();
    expect(keySets[0], keySets[1]);
  });
}
