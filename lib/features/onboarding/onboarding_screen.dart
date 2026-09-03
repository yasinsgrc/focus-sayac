import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/consent/consent_service.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';

/// Ekran 01 — karşılama + izinler. Prototip v2 satır 47-65 birebir; prototipin
/// sahte `9:41` durum çubuğu **çizilmiyor** (SPEC.md Ekran 01 kuralı).
///
/// Yalnızca ilk açılışta gösterilir: başlangıç rotası `AppSettings`in
/// `onboardingCompleted` bayrağına bakar (`app_router.dart`), bayrağı bu
/// ekranın iki çıkışı da yazar.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with TickerProviderStateMixin {
  /// SPEC.md §6.3: shimmer animasyonu **yalnızca** bu ekranın başlığında
  /// çalışır, diğer ekranlarda krom gradient statiktir.
  late final AnimationController _shimmer =
      AnimationController(vsync: this, duration: const Duration(seconds: 11))..repeat();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();

  /// İzin diyalogları ve UMP formu sırayla açılırken ikinci bir dokunuşun
  /// akışı baştan başlatmasını engelleyen kapı.
  bool _busy = false;

  @override
  void dispose() {
    _shimmer.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Ekranın iki çıkışının ortak kuyruğu. Aradaki tek fark izin isteği:
  /// "Şimdi değil" izinsiz devam eder (SPEC DoD — uygulama izinsiz de tam
  /// çalışır), ama UMP onayı **her iki** çıkışta da toplanır; onay reklamın
  /// yasal ön koşulu, bildirim izninin bir alt seçeneği değil.
  Future<void> _finish({required bool grantPermissions}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (grantPermissions) {
        await ref.read(notificationServiceProvider).requestPermissions();
      }
      await ref.read(consentServiceProvider).gatherConsent();
      // Bayrak en sona yazılıyor: akışın ortasında uygulama öldürülürse
      // onboarding bir sonraki açılışta yeniden gösterilir, yarım kalmış bir
      // izin/onay dizisiyle geri sayıma düşülmez.
      await ref.read(appSettingsDaoProvider).updateSettings(
            const AppSettingsTableCompanion(onboardingCompleted: Value<bool>(true)),
          );
      if (!mounted) return;
      context.go(RoutePaths.countdown);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: <Widget>[
          const Positioned(
            top: -140,
            left: -60,
            child: _AuroraBlob(width: 520, height: 420, color: Color(0x57FFB03A), stop: 0.62),
          ),
          const Positioned(
            bottom: -160,
            right: -100,
            child: _AuroraBlob(width: 460, height: 380, color: Color(0x4D9184D9), stop: 0.64),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _FlameBadge(spin: _spin),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    l10n.onboardingKicker,
                    style: AppTypography.kicker(fontSize: 9, color: colors.neutral600),
                  ),
                  const SizedBox(height: 12),
                  _ShimmerTitle(shimmer: _shimmer),
                  const SizedBox(height: 16),
                  Text(
                    l10n.onboardingDescription,
                    style: AppTypography.body(fontSize: 15, color: colors.neutral400, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    // Satırlar arasındaki 1px'lik boşluk bu zeminden görünüyor
                    // (prototipin `gap:1px` + kapsayıcı arka planı).
                    child: ColoredBox(
                      color: colors.divider,
                      child: Column(
                        children: <Widget>[
                          _PermissionRow(
                            icon: PhosphorIconsDuotone.bellRinging,
                            title: l10n.onboardingPermissionNotificationTitle,
                            subtitle: l10n.onboardingPermissionNotificationSubtitle,
                            tint: _PermissionTint.accent,
                          ),
                          const SizedBox(height: 1),
                          _PermissionRow(
                            icon: PhosphorIconsDuotone.alarm,
                            title: l10n.onboardingPermissionAlarmTitle,
                            subtitle: l10n.onboardingPermissionAlarmSubtitle,
                            tint: _PermissionTint.mint,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.ember),
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[colors.emberDeep, colors.emberDeep.withValues(alpha: 0)],
                        ),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _busy
                              ? null
                              : () async {
                                  await _finish(grantPermissions: true);
                                },
                          child: Stack(
                            children: <Widget>[
                              // Prototipin akan `sheen` parlamasının durağan
                              // hâli: üstten aşağı sönen beyaz gradient.
                              const Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: 23,
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: <Color>[Color(0x29FFFFFF), Colors.transparent],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      l10n.onboardingGrantAndStart,
                                      style: AppTypography.display(
                                        fontSize: 15.5,
                                        weight: FontWeight.w600,
                                        color: colors.ember,
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Icon(PhosphorIconsRegular.arrowRight, size: 17, color: colors.ember),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              await _finish(grantPermissions: false);
                            },
                      child: Text(
                        l10n.onboardingNotNow,
                        style: AppTypography.display(
                          fontSize: 13.5,
                          weight: FontWeight.w500,
                          color: colors.neutral500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Prototipin `filter:blur()` uygulanmış aurora zeminleri. Ekran 02'deki
/// karşılığıyla aynı yorum: radyal gradient zaten yumuşak, üstüne bir de
/// `ImageFilter.blur` koymak bedava değil (SPEC §6 "aynı görünen ama daha
/// ucuz").
class _AuroraBlob extends StatelessWidget {
  const _AuroraBlob({required this.width, required this.height, required this.color, required this.stop});

  final double width;
  final double height;
  final Color color;
  final double stop;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, Colors.transparent],
            stops: <double>[0, stop],
          ),
        ),
      ),
    );
  }
}

/// Prototipin krom başlığı: `--chrome` gradyanı metnin iki katı genişliğinde
/// bir shader olarak yatay kayıyor (`@keyframes shimmer`,
/// `background-position 0% → 200%`).
class _ShimmerTitle extends StatelessWidget {
  const _ShimmerTitle({required this.shimmer});

  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (BuildContext context, Widget? child) {
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: AppColors.chromeGradient,
              stops: AppColors.chromeGradientStops,
            ).createShader(
              Rect.fromLTWH(
                bounds.left - bounds.width * shimmer.value,
                bounds.top,
                bounds.width * 2,
                bounds.height,
              ),
            );
          },
          child: child,
        );
      },
      child: Text(
        AppLocalizations.of(context).onboardingTitle,
        style: AppTypography.display(
          fontSize: 42,
          weight: FontWeight.w700,
          color: Colors.white,
          height: 0.95,
        ),
      ),
    );
  }
}

/// 104px'lik meşale nişanı: sönük halkanın üstünde dönen parlak yay
/// (prototipin `border-top-color` + `spin` bileşimi), arkasında duran kor.
class _FlameBadge extends StatelessWidget {
  const _FlameBadge({required this.spin});

  final Animation<double> spin;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;

    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          // Prototipte `glow` nabız gibi atıyor (opacity .28↔.7); burada orta
          // değerinde duruyor — ekranda zaten iki animasyon var, üçüncüsü aynı
          // görüntüyü pahalıya alırdı (SPEC §6).
          IgnorePointer(
            child: Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[colors.emberDim, Colors.transparent],
                  stops: const <double>[0, 0.66],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: spin,
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size.square(104),
                painter: _FlameRingPainter(arc: colors.ember, ring: colors.ember.withValues(alpha: 0.35)),
              ),
            ),
          ),
          Icon(PhosphorIconsFill.flame, size: 56, color: colors.ember),
        ],
      ),
    );
  }
}

class _FlameRingPainter extends CustomPainter {
  const _FlameRingPainter({required this.arc, required this.ring});

  final Color arc;
  final Color ring;

  /// Prototipin `border-top-color`u tek bir kenarı boyuyor — dairede bunun
  /// karşılığı tepedeki çeyrek yay.
  static const double _arcSweep = math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect circle = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ring;
    canvas.drawOval(circle, paint);
    paint.color = arc;
    canvas.drawArc(circle, -math.pi / 2 - _arcSweep / 2, _arcSweep, false, paint);
  }

  @override
  bool shouldRepaint(_FlameRingPainter oldDelegate) => oldDelegate.arc != arc || oldDelegate.ring != ring;
}

/// [_PermissionRow]'un ikon rengi — `AppColors` `Theme`den okunduğu için
/// satırlar `const` kurulabilsin diye renk doğrudan değil, rol olarak
/// geçiriliyor.
enum _PermissionTint { accent, mint }

/// İzin kartı satırı: ne istendiğini ve **neden** istendiğini söyler; sistem
/// diyaloğu ancak bu bağlamdan sonra açılır.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _PermissionTint tint;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final Color iconColor = switch (tint) {
      _PermissionTint.accent => colors.accent300,
      _PermissionTint.mint => colors.mint,
    };

    return ColoredBox(
      color: colors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 23, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTypography.display(fontSize: 14.5, weight: FontWeight.w500, color: colors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTypography.body(fontSize: 12.5, color: colors.neutral500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
