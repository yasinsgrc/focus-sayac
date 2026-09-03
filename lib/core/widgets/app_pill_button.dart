import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Prototipte tekrar eden hap buton: `border:1px solid <role>` +
/// `background:linear-gradient(<role-deep>, transparent)` + `color:<role>`.
/// Örn. "ODAĞA DÖN" (ember), "DEVAM ET" (mint).
class AppPillButton extends StatelessWidget {
  const AppPillButton({
    required this.label,
    required this.roleColor,
    required this.roleDeepColor,
    required this.onPressed,
    super.key,
    this.icon,
    this.height = 54,
    this.weight = FontWeight.w600,
  });

  final String label;
  final Color roleColor;
  final Color roleDeepColor;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: roleColor),
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[roleDeepColor, roleDeepColor.withValues(alpha: 0)],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            // Uzun etiketler (ör. "BAŞARI KARTINI OLUŞTUR") dar ekranda ya da
            // büyük yazı tipi ölçeğinde butona sığmıyor; kırpmak yerine
            // küçültülüyor — `scaleDown` yalnızca taşma varsa devreye giriyor.
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (icon != null) ...<Widget>[
                        Icon(icon, size: 14, color: roleColor),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: AppTypography.display(
                          fontSize: 13.5,
                          weight: weight,
                          color: roleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
