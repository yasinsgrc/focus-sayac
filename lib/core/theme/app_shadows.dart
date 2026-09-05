import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Prototipin `--shadow-*` tokenları. CSS `box-shadow`'un ilk katmanı (1px kenarlık)
/// burada `Border` yerine `BoxShadow` olarak tutulur çünkü prototipte ikisi tek
/// gölge zincirinde birlikte tanımlı.
abstract final class AppShadows {
  static List<BoxShadow> md(AppColors colors) => <BoxShadow>[
        BoxShadow(color: colors.neutral700, spreadRadius: 1),
        BoxShadow(
          // Koyu zeminde %55'lik siyah gölge derinlik veriyor; açık zeminde
          // aynı sertlik kirli bir leke gibi duruyor, bu yüzden belirgin
          // şekilde yumuşatılıyor.
          color: Color.fromRGBO(0, 0, 0, colors.brightness == Brightness.dark ? 0.55 : 0.14),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
