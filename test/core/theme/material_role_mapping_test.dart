import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/core/theme/app_theme.dart';

/// Uygulamanın kendi widget'ları paleti `AppColors`tan okuyor. Ama ekranda
/// Material'ın **kendi** çizdiği parçalar da var: Ekran 11'in tarih/saat
/// seçicisi, diyalog/alt sayfa perdeleri, rengi verilmeden kurulan bir
/// `Divider`. Onlar `AppColors`ı değil `ColorScheme`i ve tema alt bloklarını
/// okuyor.
///
/// `ColorScheme`in tehlikeli yanı sessiz olması: verilmeyen her rol en yakın
/// zorunlu role düşüyor ve düşüş çoğunlukla `onSurface`te bitiyor. Faz 17'den
/// sonra seçicinin kenarlığı bu yüzden tam kontrastlı yazı rengiyle, yüzeyi de
/// sayfa zeminiyle aynı renkte çiziliyordu — hiçbir test düşmeden. Bu dosya o
/// sessizliği bozuyor: bir rol tekrar boş bırakılırsa burada düşer.
void main() {
  final Map<String, ThemeData> themes = <String, ThemeData>{
    'koyu': buildAppTheme(),
    'açık': buildAppLightTheme(),
  };

  themes.forEach((String label, ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    final AppColors colors = theme.extension<AppColors>()!;

    group('$label tema', () {
      test('kenarlık ve ikincil metin rolleri nötr rampaya bağlı', () {
        // Üçü de verilmediğinde `onSurface`e düşüyordu; seçicinin kutu
        // kenarlıkları o zaman yazı rengiyle aynı güçte çiziliyordu.
        expect(scheme.outline, colors.neutral700);
        expect(scheme.outlineVariant, colors.neutral800);
        expect(scheme.onSurfaceVariant, colors.neutral400);
        expect(scheme.outline, isNot(scheme.onSurface));
        expect(scheme.outlineVariant, isNot(scheme.onSurface));
        expect(scheme.onSurfaceVariant, isNot(scheme.onSurface));
      });

      test('Material yüzeyleri sayfa zemininden ayrı bir düzlemde', () {
        // `surfaceContainerHigh` tarih/saat seçicisinin gövdesi. `surface`e
        // düştüğünde diyalog, perdenin üstünde kendi düzlemi olmadan duruyordu.
        expect(scheme.surfaceContainerHigh, colors.surfaceDialog);
        expect(scheme.surfaceContainerHighest, colors.surfaceSunken);
        expect(scheme.surfaceContainerHigh, isNot(scheme.surface));
      });

      test('kapsayıcı rolleri rolün kendi koyu/açık ikilisinden', () {
        expect(scheme.primaryContainer, colors.emberDeep);
        expect(scheme.onPrimaryContainer, colors.ember);
        expect(scheme.tertiary, colors.mint);
        expect(scheme.tertiaryContainer, colors.mintDeep);
        expect(scheme.onTertiaryContainer, colors.mint);
      });

      test('yükselti tinti kapalı', () {
        // Verilmezse `primary`ye düşüyor ve Material'ın yükseltilmiş her
        // yüzeyi ember'a çalıyor; bu tasarımda yükselti yüzey opaklığıyla
        // anlatılıyor.
        expect(scheme.surfaceTint, Colors.transparent);
      });

      test('perde rengi tek kaynaktan: scrim tokenı', () {
        // Karar çağrı yerlerine bırakıldığında alt sayfa atlanmış ve
        // Material'ın varsayılan `black54`'üyle açılıyordu.
        expect(theme.dialogTheme.barrierColor, colors.scrim);
        expect(theme.bottomSheetTheme.modalBarrierColor, colors.scrim);
        expect(scheme.scrim, colors.scrim);
      });

      test('ayraç M3 yolunda da tema ayracını kullanıyor', () {
        // `dividerColor` yalnızca M2 yolunda okunuyor; M3'te `Divider`
        // `DividerTheme` → `outlineVariant` sırasını izliyor.
        expect(theme.dividerTheme.color, colors.divider);
      });
    });
  });
}
