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
    ),
    dividerColor: colors.divider,
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
