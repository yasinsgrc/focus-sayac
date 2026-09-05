import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/core/theme/app_colors.dart';

/// Açık tema paleti (Faz 17) elle yazıldı; koyu setin aksine arkasında
/// prototip yok, yani "gözle iyi duruyor" dışında bir çıpası olmazdı.
/// Bu test o çıpayı koyuyor: zeminin üstünde metin olarak kullanılan her
/// token WCAG 2.1 AA eşiğini geçmek zorunda.
///
/// Koyu palet bilinçli olarak kapsam dışı — onun tek doğruluk kaynağı
/// prototip (`test/prototype/prototype_palette_test.dart`); buraya da
/// bağlanırsa aynı değer iki farklı otoriteye cevap vermek zorunda kalırdı.
void main() {
  /// WCAG 2.1 bağıl parlaklık (sRGB → doğrusal).
  double relativeLuminance(Color c) {
    double channel(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final double la = relativeLuminance(a);
    final double lb = relativeLuminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  final AppColors light = AppColors.light();

  /// AA normal metin eşiği. Buradaki tokenların hepsi bir yerde **okunacak
  /// yazı** ya da anlam taşıyan ikon olarak zeminin üstüne basılıyor.
  const double kBodyThreshold = 4.5;

  final Map<String, Color> bodyTokens = <String, Color>{
    'text': light.text,
    'ember': light.ember,
    'mint': light.mint,
    'rose': light.rose,
    'sky': light.sky,
    'accent400': light.accent400,
    'neutral300': light.neutral300,
    'neutral400': light.neutral400,
    'neutral500': light.neutral500,
  };

  bodyTokens.forEach((String name, Color color) {
    test('$name açık zeminde AA metin eşiğini geçiyor', () {
      final double ratio = contrast(color, light.bg);
      expect(
        ratio,
        greaterThanOrEqualTo(kBodyThreshold),
        reason: '$name / bg kontrastı ${ratio.toStringAsFixed(2)}:1 — '
            'AA normal metin için en az $kBodyThreshold gerekiyor',
      );
    });
  });

  /// `neutral600` yalnızca kicker/bölüm etiketlerinde kullanılıyor; oradaki
  /// hedef AA'nın 3:1'lik "büyük metin / metin dışı" eşiği. Yine de sıfır
  /// kontrole bırakılmıyor, çünkü paletin en soluk okunabilir tonu bu.
  test('neutral600 en azından 3:1 taşıyor', () {
    final double ratio = contrast(light.neutral600, light.bg);
    expect(ratio, greaterThanOrEqualTo(3.0), reason: 'neutral600 / bg = ${ratio.toStringAsFixed(2)}:1');
  });

  test('açık ve koyu palet gerçekten zıt yönde', () {
    // Rampanın ters çevrildiğini doğrular: `neutral300` koyuda zeminden
    // **açık**, açıkta zeminden **koyu** olmalı. Ters çevirmeyi atlayan bir
    // düzenleme burada düşer.
    final AppColors dark = AppColors.dark();
    expect(relativeLuminance(dark.neutral300), greaterThan(relativeLuminance(dark.bg)));
    expect(relativeLuminance(light.neutral300), lessThan(relativeLuminance(light.bg)));
  });
}
