import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_pill_button.dart';
import '../../domain/badges/badge_definition.dart';
import '../../domain/badges/badge_providers.dart';
import '../../services/storage/app_database.dart';

/// Ekran 04 — rozetler. Prototip satır 181-212 birebir. Bu ekranda alt
/// gezinme çubuğu yok (prototipte de yok, yalnızca Ekran 02/06'da var —
/// Faz 4 kararı); geri dönüş sistem geri tuşu/kaydırmasıyla olur, prototip
/// burada da ayrı bir geri butonu göstermiyor.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AsyncValue<List<UserBadge>> unlockedAsync = ref.watch(unlockedBadgesProvider);
    final Set<String> unlockedKeys =
        (unlockedAsync.value ?? const <UserBadge>[]).map((UserBadge b) => b.badgeKey).toSet();
    final int unlockedCount = unlockedKeys.length;

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -120,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 520,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[colors.mint.withValues(alpha: 0.24), Colors.transparent],
                    stops: const <double>[0, 0.62],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: 8),
                  Text('ROZETLER', style: AppTypography.display(fontSize: 34, weight: FontWeight.w700, color: colors.text)),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            height: 4,
                            child: Stack(
                              children: <Widget>[
                                const DecoratedBox(decoration: BoxDecoration(color: Color(0x17FFFFFF))),
                                FractionallySizedBox(
                                  widthFactor: (unlockedCount / kBadgeCatalog.length).clamp(0, 1),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: <Color>[colors.mint, colors.ember, colors.mint]),
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
                        '$unlockedCount/${kBadgeCatalog.length}',
                        style: AppTypography.display(fontSize: 12, weight: FontWeight.w600, color: colors.neutral400)
                            .copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: SingleChildScrollView(
                      child: LayoutBuilder(
                        builder: (BuildContext context, BoxConstraints constraints) {
                          final double cardWidth = (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              for (final BadgeDefinition definition in kBadgeCatalog)
                                SizedBox(
                                  width: cardWidth,
                                  child: _BadgeCard(
                                    definition: definition,
                                    unlocked: unlockedKeys.contains(definition.key),
                                    onTap: () => showBadgeUnlockDialog(
                                      context,
                                      definition: definition,
                                      unlocked: unlockedKeys.contains(definition.key),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.definition, required this.unlocked, required this.onTap});

  final BadgeDefinition definition;
  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final Color tint = definition.tint.resolve(colors);
    final Color iconBg = unlocked ? tint.withValues(alpha: 0.32) : const Color(0x0DFFFFFF);
    final Color iconColor = unlocked ? tint : colors.neutral700;
    final Color titleColor = unlocked ? colors.text : colors.neutral600;
    final Color cardBg = unlocked ? const Color(0xDB1E2030) : const Color(0xCC12131C);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x12FFFFFF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg)),
                    Icon(definition.icon, size: 24, color: iconColor),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(definition.name, style: AppTypography.display(fontSize: 14.5, weight: FontWeight.w600, color: titleColor)),
              const SizedBox(height: 12),
              Text(definition.rule, style: AppTypography.body(fontSize: 11.5, color: colors.neutral600, height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prototip satır 200-210 — rozete tıklayınca açılan detay/açılış dialogu.
/// Kilitli bir rozete tıklamak da bu dialogu açar ("Nasıl açılır: ..." metni).
Future<void> showBadgeUnlockDialog(
  BuildContext context, {
  required BadgeDefinition definition,
  required bool unlocked,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xAD04050A),
    builder: (BuildContext context) => _BadgeUnlockDialog(definition: definition, unlocked: unlocked),
  );
}

class _BadgeUnlockDialog extends StatelessWidget {
  const _BadgeUnlockDialog({required this.definition, required this.unlocked});

  final BadgeDefinition definition;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final Color tint = definition.tint.resolve(colors);
    final Color unlockColor = unlocked ? tint : colors.neutral500;
    final Color glow = unlocked ? tint.withValues(alpha: 0.34) : colors.neutral500.withValues(alpha: 0.24);
    final String ruleText = unlocked ? 'Açıldı · ${definition.rule}' : 'Nasıl açılır: ${definition.rule}';

    return Dialog(
      insetPadding: const EdgeInsets.all(30),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(26, 34, 26, 24),
        decoration: BoxDecoration(
          color: const Color(0xF51A1C2A),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0x1AFFFFFF)),
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
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: unlockColor)),
                    child: const SizedBox(width: 112, height: 112),
                  ),
                  Icon(definition.icon, size: 52, color: unlockColor),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              definition.name,
              textAlign: TextAlign.center,
              style: AppTypography.display(fontSize: 24, weight: FontWeight.w700, color: colors.text),
            ),
            const SizedBox(height: 10),
            Text(
              ruleText,
              textAlign: TextAlign.center,
              style: AppTypography.body(fontSize: 13.5, color: colors.neutral400, height: 1.55),
            ),
            const SizedBox(height: 26),
            AppPillButton(
              label: 'BAŞARI KARTINI OLUŞTUR',
              roleColor: unlockColor,
              roleDeepColor: glow,
              // Ekran 05 (başarı kartı) henüz yok (Faz 8) — Faz 4'ün alt
              // gezinme çubuğu emsaliyle aynı çözüm: görsel birebir,
              // `onPressed: null` var olmayan bir rotaya gitmeyi engeller.
              onPressed: null,
              weight: FontWeight.w600,
            ),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Kapat', style: AppTypography.display(fontSize: 13, weight: FontWeight.w500, color: colors.neutral500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
