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
import '../../domain/pomodoro/break_tips.dart';
import '../../domain/pomodoro/pomodoro_controller.dart';
import '../../domain/pomodoro/pomodoro_math.dart';
import '../../domain/pomodoro/pomodoro_phase.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import '../../domain/settings/settings_providers.dart';
import '../../l10n/gen/app_localizations.dart';
import 'widgets/flame_widget.dart';
import 'widgets/session_ring_painter.dart';

/// Odak halkasının gradyanı. Koyu temada prototipin `fdg`'si birebir: karanlık
/// közden aleve, en açık durak neredeyse beyaz. Açık temada o sıra halkanın
/// ucunu zemine karıştırıyor — bu yüzden ters çevriliyor, açık ember'dan koyu
/// ember'a gidiyor ve halka beyaz zeminde de baştan sona görünür kalıyor.
List<Color> _focusRingGradient(AppColors colors) => colors.brightness == Brightness.dark
    ? const <Color>[Color(0xFF8A4F14), Color(0xFFFFB03A), Color(0xFFFFF1D0)]
    : <Color>[colors.emberDim, const Color(0xFFF0A32E), colors.ember];

/// Mola halkasının gradyanı — [_focusRingGradient] ile aynı gerekçe, nane
/// rolünde (prototipin `mdg`'si).
List<Color> _breakRingGradient(AppColors colors) => colors.brightness == Brightness.dark
    ? const <Color>[Color(0xFF0D3A31), Color(0xFF4FE0B4), Color(0xFFD6FFF2)]
    : <Color>[colors.mintDeep, const Color(0xFF3FC79E), colors.mint];

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
    // Tikleyici arka planda iptal ediliyor ve soğuk başlangıçta hiç çalışmamış
    // oluyor; periyodik tikin ilk atışını 1 saniye beklemek yerine burada hemen
    // bir yakalama tiki atılıyor ki aradaki sürede dolan fazlar (odak, gerekirse
    // mola da) `tick()` içinde gerçek bitiş anlarıyla kapansın.
    unawaited(ref.read(pomodoroControllerProvider.notifier).tick());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(ref.read(pomodoroControllerProvider.notifier).tick());
      if (mounted) setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // SPEC §5.1: "uygulama arka plandayken durur, öne gelince yeniden
    // hesaplanır" — kalan süre her zaman formülden okunduğu için görüntü
    // doğruluğu garanti. Faz *tamamlanması* ise tike bağlı olduğundan
    // `_startTicker()` öne gelir gelmez bir yakalama tiki atıyor; arka planda
    // dolan odak/mola orada gerçek bitiş anlarıyla kapanıyor.
    //
    // `resumed` dışındaki her durumda tikleyici duruyor: iOS `paused`e geçmeden
    // önce (uygulama değiştirici, gelen arama, denetim merkezi) `inactive`te
    // uzun süre kalabiliyor, `hidden` ise pencere gizlendiğinde geliyor. Tek
    // koşulu `paused`e bağlamak bu durumlarda tikleyicinin boşuna çalışmasına
    // yol açıyordu.
    switch (state) {
      case AppLifecycleState.resumed:
        setState(() => _nowUtc = DateTime.now().toUtc());
        _startTicker();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
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

    return PopScope<Object?>(
      // Seans sürerken sistem geri tuşu bu ekranı kapatmıyor: kapandığında
      // Ekran 02'nin aktif seans kurtarma yönlendirmesi yalnızca `initState`te
      // çalıştığı için (Faz 5 kararı) süren seansa dönüş yolu kalmıyordu.
      // Odak fazında geri, "X" ile aynı iptal onayını (Ekran 10) açar; molada
      // Ekran 09'un kendi "ODAĞA DÖN" çıkışı olduğu için geri bir şey yapmaz.
      canPop: phase is PomodoroIdle,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (phase is PomodoroFocusRunning || phase is PomodoroFocusPaused) {
          _confirmCancel(context, ref, phase);
        }
      },
      child: Scaffold(
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
              progress: phaseProgress(startedAtUtc: b.startedAtUtc, plannedDurationSec: b.plannedDurationSec, nowUtc: _nowUtc),
            ),
        },
      ),
    );
  }
}

/// Ekran 10 (iptal onayı) — hem Ekran 03'ün "X" düğmesinden hem de sistem
/// geri tuşundan açıldığı için gövde dışında, dosya düzeyinde duruyor.
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
  final AppLocalizations l10n = AppLocalizations.of(context);

  showDialog<void>(
    context: context,
    barrierColor: Theme.of(context).extension<AppColors>()!.scrim,
    builder: (BuildContext dialogContext) {
      return _CancelConfirmDialog(
        l10n: l10n,
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
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color clockColor = running ? colors.text : colors.neutral500;
    final Color phaseColor = running ? colors.ember : colors.rose;
    final Color hintIconColor = running ? colors.mint : colors.rose;
    final String phaseLabel = running ? l10n.focusRunning : l10n.focusPaused;
    // İpucu satırı bir *bilgi*, kalıcı bir durum göstergesi değil: metin
    // gerçeğe bağlanıyor ve birkaç saniye sonra sönüyor (bkz.
    // [_FocusHintLine]). "bitişte bildirim kurulu" cümlesi koşulsuz yazıldığı
    // sürece yanlış olabiliyordu — `NotificationService._allowedPreferences`
    // ana anahtar (Ekran 07 "Bildirimler") kapalıyken hiçbir bildirim kurmuyor.
    final bool notificationsEnabled = ref.watch(appSettingsProvider).value?.notificationsEnabled ?? true;
    final String hintLine = switch ((running, notificationsEnabled)) {
      (false, _) => l10n.focusHintPaused,
      (true, true) => l10n.focusHintRunning,
      (true, false) => l10n.focusHintRunningNoNotification,
    };

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
                      Text(l10n.focusCycleBadge(_cyclePosition), style: AppTypography.kicker(fontSize: 9, color: colors.ember)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(PhosphorIconsRegular.eyeSlash, size: 14, color: colors.neutral600),
                    const SizedBox(width: 6),
                    Text(l10n.focusAdHidden, style: AppTypography.body(fontSize: 11.5, color: colors.neutral600)),
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
                          ? SessionRingPainter(
                              progress: progress,
                              colors: colors,
                              gradientColors: _focusRingGradient(colors),
                              gradientStops: const <double>[0, 0.62, 1],
                            )
                          : SessionRingPainter(
                              progress: progress,
                              colors: colors,
                              solidColor: colors.neutral700,
                            ),
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
                // Prototipin üçüncü düğmesi ("skip-forward") kaldırıldı; yeri
                // aynı genişlikte boş bırakılıyor ki oynat/duraklat düğmesi
                // halkanın merkezinde kalsın (ROADMAP madde 5 kararı,
                // gerekçesi `DECISIONS.md`).
                const SizedBox(width: 22 + 58),
              ],
            ),
            const Spacer(),
            _FocusHintLine(text: hintLine, iconColor: hintIconColor),
          ],
        ),
      ),
    );
  }

}

/// Ekran 03'ün alt ipucu kutusu. Prototipteki gibi hep ekranda durmuyor:
/// göründükten [_visibleFor] sonra sönüyor ve metin değiştiğinde (duraklat →
/// devam, ya da ayarlardan bildirimler kapatıldığında) yeniden beliriyor.
/// Gerekçe: satır bir kerelik bir *bilgi* — seans boyunca sabit durması hem
/// meşale/sayaç kompozisyonundan dikkat çalıyor hem de okunduktan sonra
/// bilgi taşımıyor.
///
/// Sönerken kutu ağaçtan **çıkarılmıyor**, yalnızca saydamlaşıyor: aynı
/// yüksekliği koruması, üstündeki oynat/duraklat düğmesinin ekranda yer
/// değiştirmemesini garanti ediyor.
class _FocusHintLine extends StatefulWidget {
  const _FocusHintLine({required this.text, required this.iconColor});

  final String text;
  final Color iconColor;

  @override
  State<_FocusHintLine> createState() => _FocusHintLineState();
}

class _FocusHintLineState extends State<_FocusHintLine> {
  static const Duration _visibleFor = Duration(seconds: 6);
  static const Duration _fadeDuration = Duration(milliseconds: 450);

  Timer? _hideTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _restartHideTimer();
  }

  @override
  void didUpdateWidget(_FocusHintLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _restartHideTimer();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _visible = true;
    _hideTimer = Timer(_visibleFor, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;

    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: _fadeDuration,
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surfaceCardSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.fromBorderSide(BorderSide(color: colors.hairline)),
        ),
        child: Row(
          children: <Widget>[
            Icon(PhosphorIconsDuotone.deviceMobileSlash, size: 21, color: widget.iconColor),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.text, style: AppTypography.body(fontSize: 12.5, color: colors.neutral400))),
          ],
        ),
      ),
    );
  }
}

class _RingIconButton extends StatelessWidget {
  const _RingIconButton({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      width: 58,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: colors.fillMedium)),
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
          // Dolu birincil düğme; kontrastını kendi içinde taşıyor, o yüzden
          // zeminden bağımsız. Yine de koyu setin közü açık zeminde ekranda
          // bir "delik" gibi duruyordu: açık temada aynı ışık düşümü korunup
          // gradyan sıcak ember'a çekiliyor, krem ikon iki durumda da okunur.
          gradient: RadialGradient(
            center: const Alignment(0, -0.68),
            colors: colors.brightness == Brightness.dark
                ? const <Color>[Color(0xFFB06A1C), Color(0xFF2A1A08)]
                : const <Color>[Color(0xFFE0912B), Color(0xFF8A4500)],
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
  const _BreakBody({required this.phase, required this.remaining, required this.progress});

  final PomodoroBreakRunning phase;
  final Duration remaining;
  final double progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String breakLabel = phase.isLong ? l10n.breakLong : l10n.breakShort;
    final bool canExtend = phase.extensionsUsed < kMaxBreakExtensions;
    // SPEC.md Ekran 09: katalogdan rastgele 2 ipucu. Seçim molanın başlangıç
    // anından türüyor, `build` saniyede bir koştuğu için (bkz. `selectBreakTips`).
    final List<BreakTip> tips = selectBreakTips(breakStartedAtUtc: phase.startedAtUtc);

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
                // Etiket + rozet satırı 390pt genişlikte taşıyordu; kırpmak
                // yerine küçültülüyor (alt gezinme çubuğunun `VERİLER` hapıyla
                // aynı çözüm, Faz 9 kararı).
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(PhosphorIconsRegular.checkCircle, size: 14, color: colors.mint),
                        const SizedBox(width: 6),
                        Text(l10n.breakPomodoroDone(phase.cyclePosition), style: AppTypography.body(fontSize: 11.5, color: colors.neutral500)),
                      ],
                    ),
                  ),
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
                  RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(330, 330),
                      painter: SessionRingPainter(
                        progress: progress,
                        colors: colors,
                        gradientColors: _breakRingGradient(colors),
                        gradientStops: const <double>[0, 0.7, 1],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(PhosphorIconsDuotone.coffee, size: 64, color: colors.mint),
                      const SizedBox(height: 2),
                      // Koyu temada sayaç neredeyse beyaz bir nane tonu;
                      // açık zeminde o ton kaybolduğu için gövde metnine
                      // düşülüyor (halka ve ikon nane rolünü zaten taşıyor).
                      Text(
                        formatClock(remaining),
                        style: AppTypography.counter(
                          fontSize: 72,
                          color: colors.brightness == Brightness.dark ? const Color(0xFFE7FFF8) : colors.text,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.breakRunning, style: AppTypography.kicker(fontSize: 9, color: colors.mint)),
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
                color: colors.surfaceCardSoft,
                borderRadius: BorderRadius.circular(24),
                border: Border.fromBorderSide(BorderSide(color: colors.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.breakTipsHeading, style: AppTypography.kicker(fontSize: 8, color: colors.neutral600)),
                  const SizedBox(height: 10),
                  for (final BreakTip tip in tips)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(tip.icon, size: 16, color: tip.tint == BreakTipTint.mint ? colors.mint : colors.sky),
                          const SizedBox(width: 10),
                          Expanded(child: Text(tip.text(l10n), style: AppTypography.body(fontSize: 13, color: colors.neutral300))),
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
                    label: l10n.breakExtend,
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
                    label: l10n.breakReturnToFocus,
                    icon: PhosphorIconsFill.play,
                    roleColor: colors.ember,
                    roleDeepColor: colors.emberDeep,
                    onPressed: () => ref.read(pomodoroControllerProvider.notifier).endBreakEarly(),
                  ),
                ),
              ],
            ),
            // Prototipin `interstitial · 3 pomodoroda 1` yer tutucusu
            // kaldırıldı: gerçek interstitial tam **bu** anda (mola
            // başlangıcı) `PomodoroController._completeFocus` üzerinden tam
            // ekran açılıyor (SPEC.md §7.2), ekranda yer kaplamıyor.
          ],
        ),
      ),
    );
  }
}

/// Ekran 10 — prototip satır 379-401.
class _CancelConfirmDialog extends StatelessWidget {
  const _CancelConfirmDialog({
    required this.l10n,
    required this.elapsed,
    required this.remaining,
    required this.streak,
    required this.showStreakRisk,
    required this.onConfirmCancel,
  });

  /// Dialog `showDialog`un kendi ağacında çiziliyor; metinler çağıranın
  /// bağlamından geçiriliyor ki `_confirmCancel` iki çağıranında da (X düğmesi
  /// ve sistem geri tuşu) aynı kaynak kullanılsın.
  final AppLocalizations l10n;
  final Duration elapsed;
  final Duration remaining;
  final int streak;
  final bool showStreakRisk;
  final VoidCallback onConfirmCancel;

  String _words(Duration d) => l10n.durationMinutesSeconds(d.inMinutes, d.inSeconds % 60);

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final String bodyText = showStreakRisk
        ? l10n.cancelDialogBodyWithStreak(_words(elapsed), streak)
        : l10n.cancelDialogBody(_words(elapsed));

    return Dialog(
      backgroundColor: colors.surfaceDialog,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: colors.rose.withValues(alpha: 0.28)),
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
            Text(l10n.cancelDialogTitle, style: AppTypography.display(fontSize: 23, weight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 10),
            Text(bodyText, textAlign: TextAlign.center, style: AppTypography.body(fontSize: 13.5, color: colors.neutral400)),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: colors.fillFaint, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: <Widget>[
                  Icon(PhosphorIconsRegular.clockCountdown, size: 19, color: colors.mint),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      l10n.cancelDialogRemaining(_words(remaining)),
                      style: AppTypography.body(fontSize: 12.5, color: colors.neutral300),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppPillButton(
              label: l10n.cancelDialogKeepGoing,
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
                  border: Border.all(color: colors.rose.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onConfirmCancel,
                    child: Center(
                      child: Text(l10n.cancelDialogConfirm, style: AppTypography.display(fontSize: 13.5, weight: FontWeight.w500, color: colors.rose)),
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
