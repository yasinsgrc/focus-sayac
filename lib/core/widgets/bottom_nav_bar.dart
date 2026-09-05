import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../l10n/gen/app_localizations.dart';
import '../router/route_paths.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum AppNavTab { countdown, storyCard, badges, stats, settings }

/// Yüzen çubuğun ekranın altında kapladığı alan: 64px yükseklik + 18px alt
/// konum + nefes payı. Çubuğu gösteren ekranlar içeriklerinin altında bu
/// kadar boşluk bırakır, yoksa son öğe çubuğun altında kalıyor.
const double kBottomNavReservedSpace = 96;

/// Bir sekme seçimini rota işlemine çevirir. Beş ekran da aynı çubuğu
/// gösterdiği için kural tek yerde duruyor: Ekran 02 (geri sayım) yığının
/// kökü, diğer sekmeler onun üstünde **tek** bir kat. Kökte değilken
/// `pushReplacement` kullanılması sekmeler arasında dolaşırken yığının
/// sınırsız büyümesini — ve sistem geri tuşunun onlarca kez basılmasını
/// gerektirmesini — engelliyor.
void navigateToNavTab(BuildContext context, AppNavTab tab, {required AppNavTab current}) {
  // Aktif sekme hap olarak çizilir; yine de dokunulabilir olduğu için
  // kendi üstüne ikinci bir kopya açmaması burada garanti ediliyor.
  if (tab == current) return;
  if (tab == AppNavTab.countdown) {
    context.go(RoutePaths.countdown);
    return;
  }
  final String path = switch (tab) {
    // Yukarıda erken dönülüyor; `switch` yine de her dalı istiyor.
    AppNavTab.countdown => RoutePaths.countdown,
    AppNavTab.storyCard => RoutePaths.storyCard,
    AppNavTab.badges => RoutePaths.badges,
    AppNavTab.stats => RoutePaths.stats,
    AppNavTab.settings => RoutePaths.settings,
  };
  if (current == AppNavTab.countdown) {
    context.push(path);
  } else {
    context.pushReplacement(path);
  }
}

/// Ekranlar arası ortak yüzen alt gezinme çubuğu. Prototipte yalnızca
/// Ekran 02 ve Ekran 06'da vardı; o iki ekran diğer üçüne götürüp geri
/// getirmediği için gezinme tek yönlü kalıyordu. Artık beş sekmenin
/// hepsinde görünüyor, dolayısıyla her yuvanın aktif hâli için bir "hap"
/// tanımı var.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({required this.active, super.key, this.onSelect});

  final AppNavTab active;
  final ValueChanged<AppNavTab>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Prototip v2 satır 108-115 / 277-283: 5 yuva, aktif olan `flex:1.6`,
    // diğerleri `flex:1`. Prototipin ikon dizilimi (timer/flame/medal/chart/gear)
    // birebir korunuyor; her yuvanın **ayrı** bir hedefi var — "alev" ve
    // "madalya" bir dönem ikisi de rozetlere gidiyordu, bkz. `label` yorumu.
    final List<_NavSlot> slots = <_NavSlot>[
      _NavSlot(
        tab: AppNavTab.countdown,
        icon: PhosphorIconsRegular.timer,
        label: l10n.navCountdown,
        pill: _PillStyle.forRole(
          colors: colors,
          label: l10n.navCountdown,
          icon: PhosphorIconsFill.timer,
          role: colors.accent400,
          deep: colors.accent900,
          darkStart: colors.accent400.withValues(alpha: 0.55),
          darkForeground: const Color(0xFFF5F4FF),
        ),
      ),
      // "Alev" = seri. Ekran 05 (başarı kartı) serinin paylaşılabilir yüzü ve
      // tek girişi rozet dialogundaki düğmeydi; yuva hem tekrarı bitiriyor
      // hem o ekranı yüzeye çıkarıyor. Hapın etiketi başlığın kendisi değil
      // (`BAŞARI KARTI` beşte birlik paya sığmayıp okunmaz boyuta iniyordu),
      // ARB'deki kısa `navStoryCard`.
      _NavSlot(
        tab: AppNavTab.storyCard,
        icon: PhosphorIconsRegular.flame,
        label: l10n.storyCardTitle,
        pill: _PillStyle.forRole(
          colors: colors,
          label: l10n.navStoryCard,
          icon: PhosphorIconsFill.flame,
          role: colors.ember,
          deep: colors.emberDeep,
          darkStart: colors.ember.withValues(alpha: 0.5),
          darkForeground: const Color(0xFFFFE7C4),
        ),
      ),
      _NavSlot(
        tab: AppNavTab.badges,
        icon: PhosphorIconsRegular.medal,
        label: l10n.badgesTitle,
        pill: _PillStyle.forRole(
          colors: colors,
          label: l10n.badgesTitle,
          icon: PhosphorIconsFill.medal,
          role: colors.mint,
          deep: colors.mintDeep,
          darkStart: colors.mint.withValues(alpha: 0.45),
          darkForeground: const Color(0xFFD6FFF2),
        ),
      ),
      _NavSlot(
        tab: AppNavTab.stats,
        icon: PhosphorIconsRegular.chartBar,
        label: l10n.navStats,
        pill: _PillStyle.forRole(
          colors: colors,
          label: l10n.navStats,
          icon: PhosphorIconsFill.chartBar,
          role: colors.sky,
          deep: colors.skyDeep,
          // Tek opak başlangıç: diğer dördünün aksine prototipte burada
          // saydam bir sky değil, kendi mavisi yazılıydı.
          darkStart: const Color(0xFF1D466E),
          darkForeground: const Color(0xFFD7ECFF),
        ),
      ),
      // Ayarların bir renk rolü yok (ateş/veri/başarı gibi bir anlamı da);
      // hapı bu yüzden nötr — vurgu değil yalnızca "buradasın" işareti.
      _NavSlot(
        tab: AppNavTab.settings,
        icon: PhosphorIconsRegular.gear,
        label: l10n.settingsTitle,
        pill: _PillStyle(
          label: l10n.settingsTitle,
          icon: PhosphorIconsFill.gear,
          gradient: <Color>[colors.neutral800, colors.neutral900],
          foreground: colors.neutral300,
        ),
      ),
    ];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceNav,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.divider),
      ),
      // Dokunma geri bildirimi çubuğun **kendi** zemininde çizilsin diye
      // saydam bir `Material`: onsuz dalga Scaffold'un materyaline düşüyor ve
      // çubuğun opak arka planının altında kalıp hiç görünmüyordu.
      child: Material(
        type: MaterialType.transparency,
        child: Row(
          children: <Widget>[
            for (final _NavSlot slot in slots)
              if (slot.tab == active)
                Expanded(flex: 16, child: _ActiveTabPill(style: slot.pill))
              else
                Expanded(
                  flex: 10,
                  child: _NavIcon(
                    icon: slot.icon,
                    label: slot.label,
                    colors: colors,
                    onTap: onSelect == null ? null : () => onSelect!(slot.tab),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _NavSlot {
  const _NavSlot({required this.tab, required this.icon, required this.label, required this.pill});

  final AppNavTab tab;
  final IconData icon;

  /// Ekran okuyucunun okuduğu ad. Yuvalar prototipte etiketsiz (yalnızca ikon)
  /// olduğu için görsel bir karşılığı yok; metinler gittikleri ekranın kendi
  /// başlığından geliyor, yeni dize uydurulmuyor.
  final String label;

  /// Yuva aktifken çizilen hap. Beş sekmenin de kendi ekranı çubuğu
  /// gösterdiği için her yuvanın hapı var; opsiyonel değil.
  final _PillStyle pill;
}

class _PillStyle {
  const _PillStyle({required this.label, required this.icon, required this.gradient, required this.foreground});

  /// Renk rolü olan dört hap (sayaç/kart/rozet/veriler) için temaya duyarlı
  /// kurulum.
  ///
  /// Koyu temada hap, rol renginin **koyu** bir gradyanı; yazı o rolün açık
  /// tonu — prototipteki değerler [darkStart] ve [darkForeground] ile birebir
  /// korunuyor. Açık temada aynı gradyan neredeyse beyaza bittiği için o açık
  /// yazı kayboluyordu: gradyan seyreltiliyor (0.22) ve yazı rolün kendi koyu
  /// tonuna ([role]) düşüyor. Ayarlar hapının renk rolü olmadığı için bu
  /// fabrikayı kullanmıyor — nötr rampa zaten ters çevrildiğinden iki temada
  /// da doğru çalışıyor.
  factory _PillStyle.forRole({
    required AppColors colors,
    required String label,
    required IconData icon,
    required Color role,
    required Color deep,
    required Color darkStart,
    required Color darkForeground,
  }) {
    final bool isDark = colors.brightness == Brightness.dark;
    return _PillStyle(
      label: label,
      icon: icon,
      gradient: <Color>[isDark ? darkStart : role.withValues(alpha: 0.22), deep],
      foreground: isDark ? darkForeground : role,
    );
  }

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
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.gradient),
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
  const _NavIcon({required this.icon, required this.label, required this.colors, required this.onTap});

  final IconData icon;
  final String label;
  final AppColors colors;
  final VoidCallback? onTap;

  /// Materyal'in en küçük dokunma hedefi. `Row` çapraz eksende gevşek sınır
  /// verdiği için `InkWell` daha önce 21px'lik ikonun boyuna küçülüyordu:
  /// 64px'lik çubuğun ortasında yalnızca 21px'lik bir şerit dokunuyordu.
  static const double _minTapHeight = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        // Genişlik `Expanded`ten sıkı geliyor; yalnızca yükseklik açıkça
        // veriliyor. İkon boyutu (21px) prototipteki gibi kalıyor, büyüyen tek
        // şey görünmeyen dokunma alanı.
        child: SizedBox(
          height: _minTapHeight,
          child: Icon(icon, size: 21, color: colors.neutral600),
        ),
      ),
    );
  }
}
