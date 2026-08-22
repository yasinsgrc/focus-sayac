import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_pill_button.dart';
import '../../domain/pomodoro/pomodoro_controller.dart';
import '../../domain/pomodoro/pomodoro_math.dart';
import '../../domain/pomodoro/pomodoro_phase.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import 'widgets/flame_widget.dart';
import 'widgets/session_ring_painter.dart';

/// Ekran 03 (odak) + Ekran 09 (mola) + Ekran 10 (iptal onayı). Faz 2
/// `DECISIONS.md`'nin kararı gereği tek rota/ekran: `PomodoroPhase`e göre
/// odak ya da mola gövdesi çizilir, iptal onayı bir dialog'dur — ayrı rota
/// değil. Prototip satır 137-401.
class FocusSessionScreen extends ConsumerStatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  ConsumerState<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends ConsumerState<FocusSessionScreen> with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime _nowUtc = DateTime.now().toUtc();
  bool _leftForIdle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // SPEC §6 kural 4 / Ekran 03 ipucu satırı "Ekran açık kalır" — odak ve
    // mola aynı ekranda (Faz 5 kararı) olduğu için wakelock, bu widget
    // ağaçtayken (idle'a dönene kadar) açık kalır.
    unawaited(WakelockPlus.enable());
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(ref.read(pomodoroControllerProvider.notifier).tick());
      if (mounted) setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // SPEC §5.1: "uygulama arka plandayken durur, öne gelince yeniden
    // hesaplanır" — kalan süre her zaman formülden okunduğu için doğruluk
    // zaten garanti, burada yalnızca gereksiz arka plan tikleme durduruluyor.
    if (state == AppLifecycleState.resumed) {
      setState(() => _nowUtc = DateTime.now().toUtc());
      _startTicker();
    } else if (state == AppLifecycleState.paused) {
      _ticker?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final PomodoroPhase phase = ref.watch(pomodoroControllerProvider);

    ref.listen<PomodoroPhase>(pomodoroControllerProvider, (PomodoroPhase? previous, PomodoroPhase next) {
      if (next is PomodoroIdle && !_leftForIdle) {
        _leftForIdle = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.canPop()) {
            context.pop();
          } else if (mounted) {
            context.go(RoutePaths.countdown);
          }
        });
      }
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: switch (phase) {
        PomodoroIdle _ => const SizedBox.shrink(),
        final PomodoroFocusRunning r => _FocusBody(
            phase: r,
            remaining: phaseRemaining(startedAtUtc: r.startedAtUtc, plannedDurationSec: r.plannedDurationSec, nowUtc: _nowUtc),
            progress: phaseProgress(startedAtUtc: r.startedAtUtc, plannedDurationSec: r.plannedDurationSec, nowUtc: _nowUtc),
            running: true,
          ),
        final PomodoroFocusPaused p => _FocusBody(
            phase: p,
            remaining: p.remainingAtPause,
            progress: phaseProgress(
              startedAtUtc: p.startedAtUtc,
              plannedDurationSec: p.plannedDurationSec,
              nowUtc: p.startedAtUtc.add(Duration(seconds: p.plannedDurationSec) - p.remainingAtPause),
            ),
            running: false,
          ),
        final PomodoroBreakRunning b => _BreakBody(
            phase: b,
            remaining: phaseRemaining(startedAtUtc: b.startedAtUtc, plannedDurationSec: b.plannedDurationSec, nowUtc: _nowUtc),
          ),
      },
    );
  }
}

/// Ekran 03 — prototip satır 137-180.
class _FocusBody extends ConsumerWidget {
  const _FocusBody({required this.phase, required this.remaining, required this.progress, required this.running});

  /// [PomodoroFocusRunning] ya da [PomodoroFocusPaused].
  final PomodoroPhase phase;
  final Duration remaining;
  final double progress;
  final bool running;

  int get _cyclePosition => switch (phase) {
        final PomodoroFocusRunning r => r.cyclePosition,
        final PomodoroFocusPaused p => p.cyclePosition,
        _ => 1,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final Color clockColor = running ? colors.text : colors.neutral500;
    final Color phaseColor = running ? colors.ember : colors.rose;
    final Color hintIconColor = running ? colors.mint : colors.rose;
    final String phaseLabel = running ? 'odak sürüyor' : 'duraklatıldı';
    final String hintLine =
        running ? 'Ekran açık kalır · bitişte bildirim kurulu' : 'Meşale soldu — devam etmek için oynat';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 6, 26, 30),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: colors.emberDeep, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: colors.ember, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('ODAK $_cyclePosition/4', style: AppTypography.kicker(fontSize: 9, color: colors.ember)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(PhosphorIconsRegular.eyeSlash, size: 14, color: colors.neutral600),
                    const SizedBox(width: 6),
                    Text('reklam gizli', style: AppTypography.body(fontSize: 11.5, color: colors.neutral600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 330,
              height: 330,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(330, 330),
                      painter: running
                          ? const SessionRingPainter(
                              progress: 1,
                              gradientColors: <Color>[Color(0xFF8A4F14), Color(0xFFFFB03A), Color(0xFFFFF1D0)],
                              gradientStops: <double>[0, 0.62, 1],
                            )
                          : const SessionRingPainter(progress: 1, solidColor: Color(0xFF595D6C)),
                    ),
                  ),
                  RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          height: 106,
                          child: Align(alignment: Alignment.bottomCenter, child: FlameWidget(running: running, progress: progress)),
                        ),
                        const SizedBox(height: 6),
                        Text(formatClock(remaining), style: AppTypography.counter(fontSize: 72, color: clockColor, height: 1)),
                        const SizedBox(height: 6),
                        Text(phaseLabel, style: AppTypography.kicker(fontSize: 9, color: phaseColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _RingIconButton(
                  icon: PhosphorIconsRegular.x,
                  color: colors.neutral500,
                  onTap: () => _confirmCancel(context, ref, phase),
                ),
                const SizedBox(width: 22),
                _PlayPauseButton(
                  running: running,
                  colors: colors,
                  onTap: () => ref.read(pomodoroControllerProvider.notifier).togglePause(),
                ),
                const SizedBox(width: 22),
                _RingIconButton(icon: PhosphorIconsRegular.skipForward, color: colors.neutral500, onTap: null),
              ],
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xB31E2030),
                borderRadius: BorderRadius.circular(20),
                border: const Border.fromBorderSide(BorderSide(color: Color(0x12FFFFFF))),
              ),
              child: Row(
                children: <Widget>[
                  Icon(PhosphorIconsDuotone.deviceMobileSlash, size: 21, color: hintIconColor),
                  const SizedBox(width: 12),
                  Expanded(child: Text(hintLine, style: AppTypography.body(fontSize: 12.5, color: colors.neutral400))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, PomodoroPhase phase) {
    final (DateTime startedAtUtc, int plannedDurationSec, Duration currentRemaining) = switch (phase) {
      final PomodoroFocusRunning r => (
          r.startedAtUtc,
          r.plannedDurationSec,
          phaseRemaining(startedAtUtc: r.startedAtUtc, plannedDurationSec: r.plannedDurationSec, nowUtc: DateTime.now().toUtc()),
        ),
      final PomodoroFocusPaused p => (p.startedAtUtc, p.plannedDurationSec, p.remainingAtPause),
      _ => (DateTime.now().toUtc(), 0, Duration.zero),
    };
    final Duration elapsed = Duration(seconds: plannedDurationSec) - currentRemaining;
    final TodayFocusStats stats = ref.read(todayFocusStatsProvider);
    final int streak = ref.read(streakProvider);
    final bool showStreakRisk = stats.completedCount == 0 && streak >= 1;

    showDialog<void>(
      context: context,
      barrierColor: const Color(0xA8040509),
      builder: (BuildContext dialogContext) {
        return _CancelConfirmDialog(
          elapsed: elapsed,
          remaining: currentRemaining,
          streak: streak,
          showStreakRisk: showStreakRisk,
          onConfirmCancel: () {
            Navigator.of(dialogContext).pop();
            unawaited(ref.read(pomodoroControllerProvider.notifier).cancelFocusSession());
          },
        );
      },
    );
  }
}

class _RingIconButton extends StatelessWidget {
  const _RingIconButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x1FFFFFFF))),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.running, required this.colors, required this.onTap});

  final bool running;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.ember),
          gradient: const RadialGradient(
            center: Alignment(0, -0.68),
            colors: <Color>[Color(0xFFB06A1C), Color(0xFF2A1A08)],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(
              running ? PhosphorIconsFill.pause : PhosphorIconsFill.play,
              size: 36,
              color: const Color(0xFFFFF6E6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ekran 09 — prototip satır 335-378.
class _BreakBody extends ConsumerWidget {
  const _BreakBody({required this.phase, required this.remaining});

  final PomodoroBreakRunning phase;
  final Duration remaining;

  static const List<_BreakTip> _tips = <_BreakTip>[
    _BreakTip(icon: PhosphorIconsRegular.eye, colorRole: _TipColorRole.mint, text: 'Ekrana bakma — 20 saniye uzağa odaklan'),
    _BreakTip(icon: PhosphorIconsRegular.drop, colorRole: _TipColorRole.sky, text: 'Bir bardak su iç'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final String breakLabel = phase.isLong ? 'UZUN MOLA' : 'KISA MOLA';
    final bool canExtend = phase.extensionsUsed < kMaxBreakExtensions;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 6, 26, 30),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: colors.mintDeep, borderRadius: BorderRadius.circular(999)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: colors.mint, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(breakLabel, style: AppTypography.kicker(fontSize: 9, color: colors.mint)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(PhosphorIconsRegular.checkCircle, size: 14, color: colors.mint),
                    const SizedBox(width: 6),
                    Text('${phase.cyclePosition}. pomodoro bitti', style: AppTypography.body(fontSize: 11.5, color: colors.neutral500)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 330,
              height: 330,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  const RepaintBoundary(
                    child: CustomPaint(
                      size: Size(330, 330),
                      painter: SessionRingPainter(
                        progress: 1,
                        gradientColors: <Color>[Color(0xFF0D3A31), Color(0xFF4FE0B4), Color(0xFFD6FFF2)],
                        gradientStops: <double>[0, 0.7, 1],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(PhosphorIconsDuotone.coffee, size: 64, color: colors.mint),
                      const SizedBox(height: 2),
                      Text(formatClock(remaining), style: AppTypography.counter(fontSize: 72, color: const Color(0xFFE7FFF8), height: 1)),
                      const SizedBox(height: 6),
                      Text('mola sürüyor', style: AppTypography.kicker(fontSize: 9, color: colors.mint)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xB81E2030),
                borderRadius: BorderRadius.circular(24),
                border: const Border.fromBorderSide(BorderSide(color: Color(0x12FFFFFF))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('molada dene', style: AppTypography.kicker(fontSize: 8, color: colors.neutral600)),
                  const SizedBox(height: 10),
                  for (final _BreakTip tip in _tips)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(tip.icon, size: 16, color: tip.colorRole == _TipColorRole.mint ? colors.mint : colors.sky),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tip.text, style: AppTypography.body(fontSize: 13, color: colors.neutral300))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: AppPillButton(
                    label: '5 dk ekle',
                    icon: PhosphorIconsRegular.plus,
                    roleColor: canExtend ? colors.neutral300 : colors.neutral700,
                    roleDeepColor: Colors.transparent,
                    onPressed: canExtend ? () => ref.read(pomodoroControllerProvider.notifier).extendBreak() : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: AppPillButton(
                    label: 'ODAĞA DÖN',
                    icon: PhosphorIconsFill.play,
                    roleColor: colors.ember,
                    roleDeepColor: colors.emberDeep,
                    onPressed: () => ref.read(pomodoroControllerProvider.notifier).endBreakEarly(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Center(
                child: Text('interstitial · 3 pomodoroda 1', style: AppTypography.kicker(fontSize: 8, color: colors.neutral700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TipColorRole { mint, sky }

class _BreakTip {
  const _BreakTip({required this.icon, required this.colorRole, required this.text});

  final IconData icon;
  final _TipColorRole colorRole;
  final String text;
}

/// Ekran 10 — prototip satır 379-401.
class _CancelConfirmDialog extends StatelessWidget {
  const _CancelConfirmDialog({
    required this.elapsed,
    required this.remaining,
    required this.streak,
    required this.showStreakRisk,
    required this.onConfirmCancel,
  });

  final Duration elapsed;
  final Duration remaining;
  final int streak;
  final bool showStreakRisk;
  final VoidCallback onConfirmCancel;

  static String _words(Duration d) {
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '$minutes dakika $seconds saniye';
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final String bodyText = showStreakRisk
        ? '${_words(elapsed)} odaklandın. Şimdi bırakırsan bu seans kaydedilmez ve $streak günlük serin risk altına girer.'
        : '${_words(elapsed)} odaklandın. Şimdi bırakırsan bu seans kaydedilmez.';

    return Dialog(
      backgroundColor: const Color(0xF71A1C2A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: Color(0x47FF6A86)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // phosphor_flutter ^2.1.0'da "flame-slash" ikonu yok (yalnızca
            // "flame" mevcut) — prototipin `ph-duotone ph-flame-slash`
            // ikonuna en yakın karşılık, aynı "seri kesiliyor" anlamını rose
            // renkle taşıyor (Faz 5 kararı).
            Icon(PhosphorIconsDuotone.flame, size: 46, color: colors.rose),
            const SizedBox(height: 18),
            Text('SERİYİ KIRIYORSUN', style: AppTypography.display(fontSize: 23, weight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 10),
            Text(bodyText, textAlign: TextAlign.center, style: AppTypography.body(fontSize: 13.5, color: colors.neutral400)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: <Widget>[
                  Icon(PhosphorIconsRegular.clockCountdown, size: 19, color: colors.mint),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      '${_words(remaining)} kaldı — molaya kadar dayanabilirsin.',
                      style: AppTypography.body(fontSize: 12.5, color: colors.neutral300),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppPillButton(
              label: 'DEVAM ET',
              roleColor: colors.mint,
              roleDeepColor: colors.mintDeep,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x59FF6A86)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onConfirmCancel,
                    child: Center(
                      child: Text('Seansı iptal et', style: AppTypography.display(fontSize: 13.5, weight: FontWeight.w500, color: colors.rose)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
