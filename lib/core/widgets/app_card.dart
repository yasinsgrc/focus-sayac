import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Prototipte tekrar eden kart yüzeyi: `background:rgba(30,32,48,.82)` +
/// ince kenarlık + yuvarlak köşe. Ekranlar arası tekrar eden tek görsel birim.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.radius = AppRadius.card,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? colors.divider),
      ),
      child: child,
    );
  }
}
