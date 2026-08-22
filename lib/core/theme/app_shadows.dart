import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Prototipin `--shadow-*` tokenları. CSS `box-shadow`'un ilk katmanı (1px kenarlık)
/// burada `Border` yerine `BoxShadow` olarak tutulur çünkü prototipte ikisi tek
/// gölge zincirinde birlikte tanımlı.
abstract final class AppShadows {
  static List<BoxShadow> md(AppColors colors) => <BoxShadow>[
        BoxShadow(color: colors.neutral700, spreadRadius: 1),
        const BoxShadow(
          color: Color(0x8C000000),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ];
}
