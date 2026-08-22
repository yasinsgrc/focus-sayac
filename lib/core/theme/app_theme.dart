import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// FocusSayaç tek teması: prototip yalnız koyu zeminde tasarlandı, açık tema yok.
ThemeData buildAppTheme() {
  final AppColors colors = AppColors.dark();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: colors.bg,
    canvasColor: colors.bg,
    fontFamily: AppFonts.body,
    colorScheme: ColorScheme.dark(
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
    extensions: <ThemeExtension<dynamic>>[colors],
  );
}
