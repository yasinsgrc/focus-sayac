import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Koyu tema — prototipin tasarlandığı zemin, uygulamanın varsayılanı.
ThemeData buildAppTheme() => _themeFrom(AppColors.dark());

/// Açık tema. Prototipte karşılığı yok; [AppColors.light] tokenlarının
/// anlamsal eşlemesi üzerine kuruluyor (Faz 17).
ThemeData buildAppLightTheme() => _themeFrom(AppColors.light());

/// İki tema da aynı iskeleti paylaşıyor — fark yalnız hangi [AppColors]
/// setinin verildiği. Tipografi, yuvarlaklık ve boşluklar temadan bağımsız.
ThemeData _themeFrom(AppColors colors) {
  final bool isDark = colors.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: colors.brightness,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    fontFamily: AppFonts.body,
    colorScheme: ColorScheme(
      brightness: colors.brightness,
      surface: colors.bg,
      onSurface: colors.text,
      primary: colors.ember,
      onPrimary: colors.emberDeep,
      secondary: colors.accent400,
      onSecondary: colors.accent900,
      error: colors.rose,
      onError: colors.roseDeep,
      // Buradan aşağısı uygulamanın kendi widget'larında kullanılmıyor: hepsi
      // Material'ın hazır bileşenlerinin (Ekran 11'in tarih/saat seçicisi,
      // metin seçimi, `Divider`) okuduğu roller. Verilmedikleri sürece
      // `ColorScheme` onları en yakın zorunlu role düşürüyor ve düşüşün vardığı
      // yer çoğunlukla `onSurface` oluyordu — yani seçicinin kenarlığı ve
      // ikincil metni **tam kontrastlı yazı rengiyle** çiziliyor, yüzeyi de
      // sayfa zeminine eşitlendiği için perdenin üstünde ayrı bir düzlem olarak
      // durmuyordu. Roller uygulamanın tokenlarına bağlanınca iki tema da
      // Material'ın ekranlarını kendi diliyle çiziyor.
      primaryContainer: colors.emberDeep,
      onPrimaryContainer: colors.ember,
      secondaryContainer: colors.accent900,
      onSecondaryContainer: colors.accent200,
      tertiary: colors.mint,
      onTertiary: colors.mintDeep,
      tertiaryContainer: colors.mintDeep,
      onTertiaryContainer: colors.mint,
      errorContainer: colors.roseDeep,
      onErrorContainer: colors.rose,
      onSurfaceVariant: colors.neutral400,
      outline: colors.neutral700,
      outlineVariant: colors.neutral800,
      // Diyalog gövdesi en yüksek basamak; onun üstünde duran alanlar (saat
      // seçicinin saat/dakika kutuları) `surfaceSunken` ile "kuyu" gibi
      // duruyor — koyuda diyalogdan biraz karanlık, açıkta biraz gri.
      surfaceContainerHigh: colors.surfaceDialog,
      surfaceContainerHighest: colors.surfaceSunken,
      scrim: colors.scrim,
      // M3 yükseltilmiş her yüzeye birincil renkten bir tint bindiriyor. Bu
      // tasarımda yükselti tintle değil yüzey opaklığıyla anlatılıyor
      // (`AppColors`'ın yüzey basamakları); tint açık kalsaydı Material'ın
      // kendi yüzeyleri ember'a çalardı.
      surfaceTint: Colors.transparent,
    ),
    // `dividerColor` yalnızca Material 2 yolunda okunuyor; M3'te `Divider`
    // `DividerTheme` → `colorScheme.outlineVariant` sırasını izliyor. Ayraç bu
    // yüzden burada da veriliyor, yoksa rengi verilmeden kurulan bir `Divider`
    // nötr rampanın koyu bir basamağıyla çizilirdi.
    dividerColor: colors.divider,
    dividerTheme: DividerThemeData(color: colors.divider, thickness: 1, space: 1),
    // Perde rengi tek yerde: üç diyalog ve alt sayfa aynı karartmayı
    // paylaşıyor. Karar çağrı yerlerine bırakıldığında alt sayfa (Ekran 02'nin
    // sınav seçicisi) atlanmış, Material'ın varsayılan `black54`'üyle
    // açılıyordu — uygulamanın kendi perdesinden hem daha koyu hem başka
    // tondaydı.
    dialogTheme: DialogThemeData(barrierColor: colors.scrim),
    bottomSheetTheme: BottomSheetThemeData(modalBarrierColor: colors.scrim),
    textTheme: TextTheme(
      displayLarge: AppTypography.display(fontSize: 42, color: colors.text),
      headlineMedium: AppTypography.display(fontSize: 32, color: colors.text),
      headlineSmall: AppTypography.display(fontSize: 25, color: colors.text),
      titleLarge: AppTypography.display(fontSize: 20, color: colors.text),
      titleMedium: AppTypography.display(fontSize: 16, color: colors.text),
      titleSmall: AppTypography.kicker(fontSize: 13, color: colors.text),
      bodyLarge: AppTypography.body(fontSize: 15, color: colors.text),
      bodyMedium: AppTypography.body(fontSize: 14, color: colors.text),
      bodySmall: AppTypography.body(fontSize: 13, color: colors.neutral400),
      labelSmall: AppTypography.kicker(fontSize: 10, color: colors.neutral600),
    ),
    // Durum çubuğu ikonları zeminin tersi olmalı. Ekranların hiçbirinde
    // `AppBar` yok ama `AppBarTheme.systemOverlayStyle` uygulama genelindeki
    // varsayılanı da belirliyor; açıkça verilmezse açık temada beyaz ikonlar
    // beyaz zemine basılıyor.
    appBarTheme: AppBarTheme(
      systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    extensions: <ThemeExtension<dynamic>>[colors],
  );
}
