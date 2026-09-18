import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_pill_button.dart';
import '../../../core/widgets/flame_widget.dart';
import '../../../domain/flame/flame_tier.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Kademe atlama kutlaması (`kFlameTierLadder`, ROADMAP madde 34) — seans
/// tamamlanışında, mola gövdesinin üstünde bir kez açılır.
///
/// Ödülün kendisi burada **çiziliyor**: dairenin içindeki alev, yeni kademenin
/// alevi. Seri kutlamasındaki gibi bir ikon koymak, kademenin tek görünür
/// karşılığını (alevin büyümesi) kutlamanın dışında bırakırdı — kullanıcı
/// büyümüş alevi ancak Ekran 04'e kendi girerse görürdü, ki maddenin şikâyeti
/// tam buydu.
///
/// Alev **titremiyor**: dialog süresiz açık kalabiliyor ve sürekli dekoratif
/// animasyon SPEC.md §6.4'ün yasakladığı sınıfa girer (`FlameAvatarCard` ile
/// aynı gerekçe; `pumpAndSettle` de bu sayede takılmıyor).
Future<void> showFlameTierCelebrationDialog(
  BuildContext context, {
  required FlameTier tier,
  required VoidCallback onOpenStoryCard,
}) {
  // Perde rengi `dialogTheme.barrierColor`dan geliyor (bkz. `app_theme.dart`).
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _FlameTierCelebrationDialog(tier: tier, onOpenStoryCard: onOpenStoryCard),
  );
}

/// Kutlamadaki tek seferlik halo — test bu anahtarla arıyor.
@visibleForTesting
const Key kFlameTierCelebrationHaloKey = Key('flame_tier_celebration_halo');

/// Dairenin içindeki alev kutusu. 112'lik dairenin içinde K10 tam doluyor
/// (12px pay kalıyor), K2 aynı oranla küçük kalıyor — ölçek farkı merdivenin
/// kendisi, kırpılacak bir kusur değil.
const double _kFlameBoxHeight = 88;

class _FlameTierCelebrationDialog extends StatelessWidget {
  const _FlameTierCelebrationDialog({required this.tier, required this.onOpenStoryCard});

  final FlameTier tier;
  final VoidCallback onOpenStoryCard;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Meşale her zaman köz rolünde (Ekran 02'nin alevi, Ekran 04'ün kahraman
    // kartı ve seri kutlaması da aynı rengi taşıyor).
    final Color tint = colors.ember;
    final Color glow = tint.withValues(alpha: 0.34);

    return Dialog(
      insetPadding: const EdgeInsets.all(30),
      backgroundColor: Colors.transparent,
      child: _ScaleIn(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(26, 34, 26, 24),
          decoration: BoxDecoration(
            color: colors.surfaceDialog,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    _CelebrationHalo(color: tint),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[glow, glow.withValues(alpha: 0)],
                          stops: const <double>[0, 0.66],
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration:
                          BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tint)),
                      child: const SizedBox(width: 112, height: 112),
                    ),
                    FlameWidget(tier: tier, boxHeight: _kFlameBoxHeight, flickering: false),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Üst satır ile başlık ekran okuyucuda tek düğüm: ayrı ayrı
              // okununca "KADEME 4" ve "Fener" kopuk iki parça oluyordu (seri
              // kutlamasının aynı düzeltmesi).
              Semantics(
                container: true,
                label: l10n.flameTierCelebrationSemantics(tier.index, tier.name(l10n)),
                excludeSemantics: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.flameTierCelebrationKicker(tier.index),
                      style: AppTypography.kicker(
                          fontSize: AppTextSize.kicker, color: colors.neutral600),
                    ),
                    const SizedBox(height: 6),
                    // Kademe adı **büyük harfe çevrilmiyor**: Dart'ın
                    // `toUpperCase`i yerelden bağımsız çalışıyor ve "Şenlik
                    // Ateşi" → "ŞENLIK ATEŞI" ile noktasız İ'yi bozuyor.
                    // Kicker'ın büyük harfleri ARB'de yazılı, orada sorun yok.
                    Text(
                      tier.name(l10n),
                      textAlign: TextAlign.center,
                      style: AppTypography.display(
                        fontSize: AppTextSize.heading,
                        weight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.flameTierCelebrationBody(tier.thresholdHours),
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral400),
              ),
              const SizedBox(height: 26),
              AppPillButton(
                label: l10n.badgeCreateStoryCard,
                roleColor: tint,
                roleDeepColor: colors.emberDeep,
                // Dialog önce kapanıyor: açık kalsaydı başarı kartından geri
                // dönen kullanıcı kendini yine kutlamanın üstünde bulurdu
                // (rozet ve seri dialoglarının aynı kuralı).
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenStoryCard();
                },
                weight: FontWeight.w600,
              ),
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l10n.commonClose,
                    style: AppTypography.label(
                        fontSize: AppTextSize.md, weight: FontWeight.w500, color: colors.neutral500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seri kutlamasındaki halonun ikizi: **tek seferlik** sönen parlama
/// (0.45 → 0). Üçüncü kopya bilinçli — iki kardeşi de (`badge_unlock_dialog`,
/// `streak_celebration_dialog`) kendi dosyasında özel (`_`) ve üç kutlamanın
/// aynı parlamayla gelmesi görsel dilin kendisi.
class _CelebrationHalo extends StatelessWidget {
  const _CelebrationHalo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final Duration duration = AppMotion.respectingMotion(context, AppMotion.entrance);
    if (duration == Duration.zero) return const SizedBox.shrink();

    return IgnorePointer(
      key: kFlameTierCelebrationHaloKey,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.45, end: 0),
        duration: duration,
        curve: AppMotion.exit,
        builder: (BuildContext context, double opacity, Widget? _) => DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[color.withValues(alpha: opacity), color.withValues(alpha: 0)],
              stops: const <double>[0.28, 1],
            ),
          ),
          child: const SizedBox(width: 112, height: 112),
        ),
      ),
    );
  }
}

/// Kartın girişi: 0.92 → 1.0, hedefi hafifçe aşan `pop` eğrisiyle — seri
/// kutlamasıyla birebir aynı yaylanma.
class _ScaleIn extends StatelessWidget {
  const _ScaleIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1),
      duration: AppMotion.respectingMotion(context, AppMotion.base),
      curve: AppMotion.pop,
      builder: (BuildContext context, double scale, Widget? child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
