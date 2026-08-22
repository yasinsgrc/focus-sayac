import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Michroma ile yazılan, otomatik büyük harfe çevrilen etiket/kicker metni.
/// Örn. "ODAK 3/4", "İZİN VER VE BAŞLA".
class KickerLabel extends StatelessWidget {
  const KickerLabel(
    this.text, {
    required this.color,
    super.key,
    this.fontSize = 9.5,
  });

  final String text;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.kicker(fontSize: fontSize, color: color),
    );
  }
}
