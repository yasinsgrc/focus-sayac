import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_pill_button.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Seri eşiği kutlaması (`kStreakMilestones`) — seans tamamlanışında, mola
/// gövdesinin üstünde bir kez açılır.
///
/// Neden rozet dialogunun kendisi değil: rozetin bir adı, bir ikonu ve bir
/// kataloğu var; serinin yalnızca bir sayısı. Rozet dialogunu uydurma bir "seri
/// rozeti" ile beslemek, Ekran 04'ün merdiveninde olmayan bir ödül göstermek
/// olurdu. Görsel dil yine aynı: halo + daire + rol rengi + aynı birincil
/// aksiyon.
///
/// Kutlamanın tek işi **paylaşımı o anda önermek**: başarı kartı ayrı bir
/// ekranda duruyor ve kullanıcının onu gidip aramasını beklemek, tek organik
/// büyüme kanalını kullanılmaz bırakıyordu.
Future<void> showStreakCelebrationDialog(
  BuildContext context, {
  required int days,
  required VoidCallback onOpenStoryCard,
}) {
  // Perde rengi `dialogTheme.barrierColor`dan geliyor (bkz. `app_theme.dart`).
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _StreakCelebrationDialog(days: days, onOpenStoryCard: onOpenStoryCard),
  );
}

/// Kutlamadaki tek seferlik halo — test bu anahtarla arıyor.
@visibleForTesting
const Key kStreakCelebrationHaloKey = Key('streak_celebration_halo');

class _StreakCelebrationDialog extends StatelessWidget {
  const _StreakCelebrationDialog({required this.days, required this.onOpenStoryCard});

  final int days;
  final VoidCallback onOpenStoryCard;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // Seri her zaman köz rolünde (Ekran 02'nin alevi, alt çubuğun "BAŞARI" hapı
    // ve hikâye kartının SERİ şablonu da aynı rengi taşıyor).
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
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: tint)),
                      child: const SizedBox(width: 112, height: 112),
                    ),
                    Icon(PhosphorIconsFill.flame, size: 52, color: tint),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.streakCelebrationKicker,
                style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
              ),
              const SizedBox(height: 6),
              // Ekran okuyucuda "30 GÜN" başlığı ile gövde üst üste aynı sayıyı
              // okuyordu; başlık sözlü karşılığıyla değiştiriliyor (Ekran 04'ün
              // rozet sayacıyla aynı yaklaşım).
              Semantics(
                label: l10n.streakCelebrationSemantics(days),
                excludeSemantics: true,
                child: Text(
                  l10n.streakCelebrationTitle(days),
                  textAlign: TextAlign.center,
                  style: AppTypography.display(
                    fontSize: AppTextSize.heading,
                    weight: FontWeight.w700,
                    color: colors.text,
                  ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.streakCelebrationBody(days),
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
                // (rozet dialogunun aynı kuralı).
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

/// Rozet dialogundaki halonun ikizi: **tek seferlik** sönen parlama (0.45 → 0).
/// Nabız gibi atmıyor — sürekli dekoratif animasyon SPEC.md §6.4'ün yasakladığı
/// sınıfa girer ve dialog süresiz açık kalabilir. Bir kez sönüp bittiği için
/// `pumpAndSettle` de takılmıyor.
class _CelebrationHalo extends StatelessWidget {
  const _CelebrationHalo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final Duration duration = AppMotion.respectingMotion(context, AppMotion.entrance);
    if (duration == Duration.zero) return const SizedBox.shrink();

    return IgnorePointer(
      key: kStreakCelebrationHaloKey,
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

/// Kartın girişi: 0.92 → 1.0, hedefi hafifçe aşan `pop` eğrisiyle. Rozet
/// dialogundaki `_ScaleIn`in ikizi — o özel (`_`) olduğu için paylaşılamıyor ve
/// iki kutlamanın aynı yaylanmayla gelmesi bilinçli.
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
