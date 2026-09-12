import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_pill_button.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/rolling_number.dart';
import '../../domain/badges/badge_definition.dart';
import '../../domain/badges/badge_providers.dart';
import '../../domain/badges/badge_rules.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/storage/app_database.dart';
import 'widgets/badge_progress_ring_painter.dart';
import 'widgets/flame_avatar_card.dart';

/// Ekran 04 — rozetler. Prototip satır 181-212 birebir. Prototipte bu ekranda
/// alt gezinme çubuğu yoktu (yalnızca Ekran 02/06'da vardı — Faz 4 kararı) ama
/// o zaman ekran çıkmaza giriyordu: jest navigasyonu kapalı cihazlarda geri
/// dönmenin yolu kalmıyordu. Artık çubuk beş ekranın hepsinde olduğu için
/// çıkış yolu o; ayrı bir geri oku taşınmıyor.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AsyncValue<List<UserBadge>> unlockedAsync = ref.watch(unlockedBadgesProvider);
    final Map<String, BadgeProgress> progressByKey = ref.watch(badgeProgressProvider);
    // Kart durumu DB kaydının **ve** kuralın birleşimi. DB satırı seans
    // bittiğinde düşüyor (`BadgeUnlockService`), oysa merdivenin alt
    // basamakları eski kullanıcılarda güncellemeden önce zaten hak edilmiş
    // olabiliyor: o kartlar kilitli kalsaydı "61/10" gibi bir sayaç ve dolup
    // taşmış bir halka gösterirlerdi. Açılış anı (bildirim, halo) yine DB
    // tarafında — burası yalnızca ekranın doğruyu söylemesi.
    final Set<String> unlockedKeys = <String>{
      for (final UserBadge badge in unlockedAsync.value ?? const <UserBadge>[]) badge.badgeKey,
      for (final MapEntry<String, BadgeProgress> entry in progressByKey.entries)
        if (entry.value.earned) entry.key,
    };
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
                  RiseIn(
                    child: Text(
                      AppLocalizations.of(context).badgesTitle,
                      style: AppTypography.display(
                          fontSize: AppTextSize.hero, weight: FontWeight.w700, color: colors.text),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RiseIn(
                    delay: RiseIn.step,
                    child: Row(
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
                                    widthFactor: (unlockedCount / kBadgeCatalog.length).clamp(0, 1),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: <Color>[colors.mint, colors.ember, colors.mint],
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
                        RollingNumber(
                          value: unlockedCount,
                          text: '$unlockedCount/${kBadgeCatalog.length}',
                          // `tabularFigures` artık `RollingNumber`ın garantisi.
                          style: AppTypography.label(
                            fontSize: AppTextSize.sm,
                            weight: FontWeight.w600,
                            color: colors.neutral400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  RiseIn(
                    delay: RiseIn.step * 2,
                    child: const FlameAvatarCard(),
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
                              // Prototipte kartlar tek tek beliriyor; başlık,
                              // ilerleme çubuğu ve kahraman kart ilk üç basamağı
                              // aldığı için ızgara dördüncüden devam ediyor.
                              for (final (int index, BadgeDefinition definition) in kBadgeCatalog.indexed)
                                SizedBox(
                                  width: cardWidth,
                                  child: RiseIn(
                                    delay: RiseIn.step * (index + 3),
                                    child: _BadgeCard(
                                      definition: definition,
                                      progress: progressByKey[definition.key],
                                      unlocked: unlockedKeys.contains(definition.key),
                                      onTap: () => showBadgeUnlockDialog(
                                        context,
                                        definition: definition,
                                        unlocked: unlockedKeys.contains(definition.key),
                                        progress: progressByKey[definition.key],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  // Yüzen çubuğun altında kalmasın diye son kartın altındaki
                  // boşluk çubuğun kapladığı alan kadar.
                  const SizedBox(height: kBottomNavReservedSpace),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: BottomNavBar(
              active: AppNavTab.badges,
              onSelect: (AppNavTab tab) => navigateToNavTab(context, tab, current: AppNavTab.badges),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.definition,
    required this.progress,
    required this.unlocked,
    required this.onTap,
  });

  final BadgeDefinition definition;

  /// Kilitli kartın halkası ve sayacı. `null` olduğunda kart eski hâline
  /// dönüyor (yalnızca kural metni) — ilerleme bilinmiyorsa uydurulmuyor.
  final BadgeProgress? progress;

  final bool unlocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color tint = definition.tint.resolve(colors);
    // Açılmış rozette halka anlamsız (yol bitti), hedefi 1 olanlarda ise
    // "0/1" ilerleme değil kuralın tekrarı olurdu. Yerel değişken `bool` bayrak
    // yerine `BadgeProgress?`: `bool` üzerinden tip yükseltme yapılmıyor.
    final BadgeProgress? progress = this.progress;
    final BadgeProgress? shownProgress =
        !unlocked && progress != null && progress.isCountable ? progress : null;
    final Color iconBg = unlocked ? tint.withValues(alpha: 0.32) : colors.fillFaint;
    final Color iconColor = unlocked ? tint : colors.neutral700;
    final Color titleColor = unlocked ? colors.text : colors.neutral600;
    // Kilitli kart açılmış olandan bir düzlem geride duruyor: koyu temada
    // zeminden biraz daha karanlık, açık temada biraz daha gri.
    final Color cardBg = unlocked ? colors.surfaceCardStrong : colors.surfaceSunken.withValues(alpha: 0.8);

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
            border: Border.all(color: colors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Halkalı da halkasız da 56: kilitli ve açılmış kartlar aynı
              // yükseklikte kalsın, ızgara satırları kaymasın.
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (shownProgress != null)
                      CustomPaint(
                        size: const Size.square(56),
                        painter: BadgeProgressRingPainter(
                          ratio: shownProgress.ratio,
                          trackColor: colors.fillSubtle,
                          // Halka kilitli kartın tek renkli öğesi: ödülün
                          // rengini ikon soluklaşmışken o taşıyor.
                          progressColor: tint,
                        ),
                      ),
                    // `DecoratedBox` çocuksuz kalırsa `Stack`in gevşek
                    // kısıtlarında sıfır boyuta iniyor; daire ölçüsünü
                    // diyalogdaki gibi `SizedBox` veriyor.
                    DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: iconBg),
                      child: const SizedBox(width: 48, height: 48),
                    ),
                    Icon(definition.icon, size: 24, color: iconColor),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                definition.name(l10n),
                style: AppTypography.label(
                    fontSize: AppTextSize.lg, weight: FontWeight.w600, color: titleColor),
              ),
              const SizedBox(height: 12),
              Text(
                definition.rule(l10n),
                style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.neutral600, height: 1.45),
              ),
              if (shownProgress != null) ...<Widget>[
                const SizedBox(height: 10),
                _BadgeProgressCounter(definition: definition, progress: shownProgress, color: tint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "61/100" — kilitli rozetin ne kadarının bittiği. Birim yazılmıyor: hemen
/// üstündeki kural metni ("Kümülatif 100 saat odak") zaten söylüyor.
///
/// Ekran okuyucuda eğik çizgi bölme gibi okunduğu için etiket sözlü karşılığıyla
/// değiştiriliyor (Ekran 02'nin seri rozetiyle aynı yaklaşım).
class _BadgeProgressCounter extends StatelessWidget {
  const _BadgeProgressCounter({
    required this.definition,
    required this.progress,
    required this.color,
  });

  final BadgeDefinition definition;
  final BadgeProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.badgeProgressSemantics(definition.name(l10n), progress.current, progress.target),
      excludeSemantics: true,
      child: Text(
        l10n.badgeProgressCounter(progress.current, progress.target),
        style: AppTypography.label(
          fontSize: AppTextSize.xs,
          weight: FontWeight.w600,
          color: color,
        ).copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
      ),
    );
  }
}

/// Rozet açılışındaki tek seferlik halo — testler bu anahtarla arıyor; ağaçta
/// başka bir işaretçisi yok (kilitli rozette hiç çizilmiyor).
@visibleForTesting
const Key kBadgeUnlockHaloKey = Key('badge_unlock_halo');

/// Prototip satır 200-210 — rozete tıklayınca açılan detay/açılış dialogu.
/// Kilitli bir rozete tıklamak da bu dialogu açar ("Nasıl açılır: ..." metni).
/// [onOpenStoryCard] verilmezse "BAŞARI KARTINI OLUŞTUR" Ekran 04'ten gelmiş
/// gibi davranır (alt çubuğun sekme kuralı). Dialog artık **Ekran 03/09'dan da**
/// açılıyor — rozet tam açıldığı anda, kutlama yerinde. O bağlamda aktif bir
/// sekme yok, o yüzden gezinme kararı çağırana bırakılıyor.
Future<void> showBadgeUnlockDialog(
  BuildContext context, {
  required BadgeDefinition definition,
  required bool unlocked,
  BadgeProgress? progress,
  VoidCallback? onOpenStoryCard,
}) {
  // Perde rengi `dialogTheme.barrierColor`dan geliyor (bkz. `app_theme.dart`).
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => _BadgeUnlockDialog(
      definition: definition,
      unlocked: unlocked,
      progress: progress,
      onOpenStoryCard: onOpenStoryCard,
    ),
  );
}

class _BadgeUnlockDialog extends StatelessWidget {
  const _BadgeUnlockDialog({
    required this.definition,
    required this.unlocked,
    this.progress,
    this.onOpenStoryCard,
  });

  final BadgeDefinition definition;
  final bool unlocked;

  /// `null` ise Ekran 04'ün sekme geçişi kullanılır — bkz.
  /// [showBadgeUnlockDialog].
  final VoidCallback? onOpenStoryCard;

  /// Kilitli rozetin sayacı. Kartta görünen sayının diyalogda kaybolması,
  /// "daha fazlasını öğren" diye açılan ekranın daha azını göstermesi olurdu.
  final BadgeProgress? progress;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color tint = definition.tint.resolve(colors);
    final BadgeProgress? progress = this.progress;
    final BadgeProgress? shownProgress =
        !unlocked && progress != null && progress.isCountable ? progress : null;
    final Color unlockColor = unlocked ? tint : colors.neutral500;
    final Color glow = unlocked ? tint.withValues(alpha: 0.34) : colors.neutral500.withValues(alpha: 0.24);
    final String ruleText = unlocked
        ? l10n.badgeUnlockedRule(definition.rule(l10n))
        : l10n.badgeLockedRule(definition.rule(l10n));

    return Dialog(
      insetPadding: const EdgeInsets.all(30),
      backgroundColor: Colors.transparent,
      // Kart yerine oturarak geliyor (ROADMAP madde 19): rozet açılışı
      // uygulamanın en duygusal anlarından biri, dialog bugüne kadar hiçbir
      // şey söylemeden beliriyordu.
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
                    // Tek seferlik halo yalnızca açılmış rozette: kilitli
                    // kartın dialogu bir bilgi ekranı, kutlanacak bir şey yok.
                    if (unlocked) _UnlockHalo(color: tint),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: unlockColor),
                      ),
                      child: const SizedBox(width: 112, height: 112),
                    ),
                    Icon(definition.icon, size: 52, color: unlockColor),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                definition.name(l10n),
                textAlign: TextAlign.center,
                style: AppTypography.display(
                    fontSize: AppTextSize.heading, weight: FontWeight.w700, color: colors.text),
              ),
              const SizedBox(height: 10),
              Text(
                ruleText,
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral400),
              ),
              if (shownProgress != null) ...<Widget>[
                const SizedBox(height: 12),
                _BadgeProgressCounter(definition: definition, progress: shownProgress, color: tint),
              ],
              const SizedBox(height: 26),
              AppPillButton(
                label: l10n.badgeCreateStoryCard,
                roleColor: unlockColor,
                roleDeepColor: glow,
                // Dialog önce kapanıyor: açık kalsaydı Ekran 05'ten geri
                // dönüldüğünde kullanıcıyı yine kendi üstünde bulurdu.
                //
                // Geçiş `navigateToNavTab` üzerinden: düz `push` yığını
                // sayaç→rozetler→başarı kartı diye üç kata çıkarıyordu, oysa
                // `bottom_nav_bar.dart`taki kural sekmelerin kökün **tek** kat
                // üstünde durması. Çubuktan gelen geçişle aynı yolu kullanmak
                // ikisini de tek kuralda tutuyor.
                onPressed: () {
                  final VoidCallback? openStoryCard = onOpenStoryCard;
                  Navigator.of(context).pop();
                  if (openStoryCard != null) {
                    openStoryCard();
                    return;
                  }
                  navigateToNavTab(context, AppNavTab.storyCard, current: AppNavTab.badges);
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

/// Dialog kartının girişi: 0.92 → 1.0, hedefi hafifçe aşan `pop` eğrisiyle.
/// Bir kez çalışıp duruyor (SPEC.md §6.4) — "hareketi azalt" açıkken ilk kare
/// zaten son hâli çiziyor, çünkü sıfır süreli `TweenAnimationBuilder` daha
/// kurulurken bitişe atlıyor.
class _ScaleIn extends StatelessWidget {
  const _ScaleIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.92, end: 1),
      duration: AppMotion.respectingMotion(context, AppMotion.base),
      curve: AppMotion.pop,
      builder: (BuildContext context, double scale, Widget? child) => Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}

/// Rozet ikonunun arkasında **tek seferlik** sönen halo (0.45 → 0).
///
/// Nabız gibi atmıyor: sürekli bir dekoratif animasyon SPEC.md §6.4'ün
/// yasakladığı sınıfa girer ve dialog süresiz açık kalabilir. Bir kez sönüp
/// bittiği için `pumpAndSettle` de takılmıyor.
class _UnlockHalo extends StatelessWidget {
  const _UnlockHalo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final Duration duration = AppMotion.respectingMotion(context, AppMotion.entrance);
    if (duration == Duration.zero) return const SizedBox.shrink();

    return IgnorePointer(
      key: kBadgeUnlockHaloKey,
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
