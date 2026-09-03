import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppNavTab { countdown, badges, stats, settings }

/// Prototipin ekranlar arası ortak yüzen alt gezinme çubuğu (Ekran 02/06 —
/// Ekran 04/07'de prototipte bu çubuk yok). Rozetler ekranı Faz 7'de,
/// ayarlar ekranı Faz 12'de bağlandı; istatistik ekranı (Ekran 06, Faz 9)
/// henüz yapılmadığından o sekme görsel olarak prototipteki gibi durur ama
/// dokunma hedefine bağlanmaz — hedef ekran yokken sahte bir rota eklemek
/// "prototipte olmayan özellik ekleme" riski taşır; gerçek rota geldiğinde
/// `onSelect` genişletilecek.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({required this.active, super.key, this.onSelect});

  final AppNavTab active;
  final ValueChanged<AppNavTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
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
          Expanded(
            flex: 16,
            child: _ActiveTabPill(colors: colors),
          ),
          _NavIcon(
            icon: PhosphorIconsRegular.flame,
            selected: active == AppNavTab.badges,
            colors: colors,
            onTap: onSelect == null ? null : () => onSelect!(AppNavTab.badges),
          ),
          _NavIcon(
            icon: PhosphorIconsRegular.medal,
            selected: active == AppNavTab.badges,
            colors: colors,
            onTap: onSelect == null ? null : () => onSelect!(AppNavTab.badges),
          ),
          _NavIcon(
            icon: PhosphorIconsRegular.chartBar,
            selected: active == AppNavTab.stats,
            colors: colors,
            onTap: onSelect == null ? null : () => onSelect!(AppNavTab.stats),
          ),
          _NavIcon(
            icon: PhosphorIconsRegular.gear,
            selected: active == AppNavTab.settings,
            colors: colors,
            onTap: onSelect == null ? null : () => onSelect!(AppNavTab.settings),
          ),
        ],
      ),
    );
  }
}

class _ActiveTabPill extends StatelessWidget {
  const _ActiveTabPill({required this.colors});

  final AppColors colors;

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
          colors: <Color>[colors.accent400.withValues(alpha: 0.55), colors.accent900],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(PhosphorIconsFill.timer, size: 19, color: Color(0xFFF5F4FF)),
          const SizedBox(width: 7),
          Text('SAYAÇ', style: AppTypography.display(fontSize: 12, weight: FontWeight.w600, color: const Color(0xFFF5F4FF))),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, required this.selected, required this.colors, required this.onTap});

  final IconData icon;
  final bool selected;
  final AppColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Icon(icon, size: 21, color: colors.neutral600),
      ),
    );
  }
}
