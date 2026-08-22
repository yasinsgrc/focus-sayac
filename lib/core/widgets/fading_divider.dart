import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Nocturne'ün imza çizgisi: uçlarda saydama sönümlenen ayraç (`.hr`).
/// Serbest duran çizgiler sönümlenir; kutu kenarlıkları solid kalır.
class FadingDivider extends StatelessWidget {
  const FadingDivider({super.key, this.height = 1});

  final double height;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            colors.divider.withValues(alpha: 0),
            colors.divider,
            colors.divider,
            colors.divider.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.1, 0.9, 1],
        ),
      ),
    );
  }
}
