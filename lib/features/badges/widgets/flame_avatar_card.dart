import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/flame_widget.dart';
import '../../../domain/flame/flame_providers.dart';
import '../../../domain/flame/flame_tier.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Ekran 04'ün kahraman kartı — kalıcı kimlik. Rozet ızgarası "ne başardım"
/// diyor, bu kart "ben kimim" diyor.
///
/// Alev burada **titremiyor**: ekran seans dışı bir yüzey ve sonsuz tekrarlı
/// bir tikleyici hem pili hem `pumpAndSettle` kullanan ekran testlerini
/// yakardı. Durağan portre kimlik için zaten daha doğru.
class FlameAvatarCard extends ConsumerWidget {
  const FlameAvatarCard({super.key});

  /// Kartın alev kutusu — odak ekranından (98) büyük, çünkü burada alev
  /// sayfanın kahramanı, sayaç metninin yanındaki dekor değil.
  static const double boxHeight = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FlameTierStatus status = ref.watch(flameTierProvider);

    // En üst kademede hedef yok; sayaç kullanıcının kendi toplamını gösterir
    // ("400 / 400 sa" donmuş bir sayı olurdu).
    final int target = status.nextTier?.thresholdHours ?? status.cumulativeHours;

    return Semantics(
      container: true,
      label: l10n.flameAvatarSemantics(
        status.tier.name(l10n),
        status.tier.index,
        status.cumulativeHours,
        target,
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: colors.surfaceCardSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.flameTierKicker,
                style: AppTypography.kicker(
                    fontSize: AppTextSize.kicker, color: colors.neutral600),
              ),
              const SizedBox(height: 10),
              Center(
                child: FlameWidget(
                  tier: status.tier,
                  boxHeight: boxHeight,
                  flickering: false,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                status.tier.name(l10n),
                style: AppTypography.display(
                    fontSize: AppTextSize.titleLg, color: colors.text),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          children: <Widget>[
                            DecoratedBox(decoration: BoxDecoration(color: colors.fillSubtle)),
                            FractionallySizedBox(
                              widthFactor: status.ratioInTier,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[colors.emberDim, colors.ember],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.flameHoursCounter(status.cumulativeHours, target),
                    style: AppTypography.label(
                      fontSize: AppTextSize.sm,
                      weight: FontWeight.w600,
                      color: colors.neutral400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status.isTopTier
                    ? l10n.flameTopTier
                    : l10n.flameNextTierHours(status.hoursRemaining!),
                style: AppTypography.body(
                    fontSize: AppTextSize.sm, color: colors.neutral500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
