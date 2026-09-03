import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppNavTab { countdown, badges, stats, settings }

/// Prototipin ekranlar arası ortak yüzen alt gezinme çubuğu. Yalnızca
/// Ekran 02 ve Ekran 06'da görünür (Ekran 04/07'de prototipte de yok) —
/// bu yüzden "hap" biçimindeki aktif yuva tanımı yalnızca bu iki sekme için
/// var; diğer iki yuva her zaman düz ikon çizer.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({required this.active, super.key, this.onSelect});

  final AppNavTab active;
  final ValueChanged<AppNavTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Prototip v2 satır 108-115 / 277-283: 5 yuva, aktif olan `flex:1.6`,
    // diğerleri `flex:1`. "Alev" ve "madalya" yuvalarının ayrı ekranı yok,
    // ikisi de rozetlere gider (Faz 4 kararı).
    final List<_NavSlot> slots = <_NavSlot>[
      _NavSlot(
        tab: AppNavTab.countdown,
        icon: PhosphorIconsRegular.timer,
        pill: _PillStyle(
          label: l10n.navCountdown,
          icon: PhosphorIconsFill.timer,
          gradient: <Color>[colors.accent400.withValues(alpha: 0.55), colors.accent900],
          foreground: const Color(0xFFF5F4FF),
        ),
      ),
      const _NavSlot(tab: AppNavTab.badges, icon: PhosphorIconsRegular.flame),
      const _NavSlot(tab: AppNavTab.badges, icon: PhosphorIconsRegular.medal),
      _NavSlot(
        tab: AppNavTab.stats,
        icon: PhosphorIconsRegular.chartBar,
        pill: _PillStyle(
          label: l10n.navStats,
          icon: PhosphorIconsFill.chartBar,
          gradient: <Color>[const Color(0xFF1D466E), colors.skyDeep],
          foreground: const Color(0xFFD7ECFF),
        ),
      ),
      const _NavSlot(tab: AppNavTab.settings, icon: PhosphorIconsRegular.gear),
    ];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xC7181A28),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: <Widget>[
          for (final _NavSlot slot in slots)
            if (slot.pill != null && slot.tab == active)
              Expanded(flex: 16, child: _ActiveTabPill(style: slot.pill!))
            else
              Expanded(
                flex: 10,
                child: _NavIcon(
                  icon: slot.icon,
                  colors: colors,
                  onTap: onSelect == null ? null : () => onSelect!(slot.tab),
                ),
              ),
        ],
      ),
    );
  }
}

class _NavSlot {
  const _NavSlot({required this.tab, required this.icon, this.pill});

  final AppNavTab tab;
  final IconData icon;

  /// `null` ise bu yuva aktifken de düz ikon çizilir — o sekmenin ekranında
  /// gezinme çubuğu hiç görünmediği için hap görünümüne ihtiyacı yok.
  final _PillStyle? pill;
}

class _PillStyle {
  const _PillStyle({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final Color foreground;
}

class _ActiveTabPill extends StatelessWidget {
  const _ActiveTabPill({required this.style});

  final _PillStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.gradient,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      // Hapın genişliği çubuğun beşte birinden pay alıyor; dar ekranlarda
      // "VERİLER" etiketi bu paya sığmayabiliyor. Kırpmak yerine küçültmek
      // prototipe daha yakın — ikon ve etiket her zaman tam görünür.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(style.icon, size: 19, color: style.foreground),
            const SizedBox(width: 7),
            Text(
              style.label,
              style: AppTypography.display(fontSize: 12, weight: FontWeight.w600, color: style.foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.colors, required this.onTap});

  final IconData icon;
  final AppColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Icon(icon, size: 21, color: colors.neutral600),
    );
  }
}
