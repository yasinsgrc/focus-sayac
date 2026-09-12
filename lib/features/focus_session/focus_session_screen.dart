import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_pill_button.dart';
import '../../core/widgets/flame_widget.dart';
import '../../core/widgets/settling_progress.dart';
import '../../domain/badges/badge_definition.dart';
import '../../domain/celebration/session_celebration.dart';
import '../../domain/flame/flame_providers.dart';
import '../../domain/pomodoro/break_tips.dart';
import '../../domain/pomodoro/pomodoro_controller.dart';
import '../../domain/pomodoro/pomodoro_math.dart';
import '../../domain/pomodoro/pomodoro_phase.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import '../../domain/settings/settings_providers.dart';
import '../../domain/story_card/story_card_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../badges/badges_screen.dart';
import 'widgets/session_ring_painter.dart';
import 'widgets/streak_celebration_dialog.dart';

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

  /// Odak seansı **doğal bitişle** molaya geçtiğinde, mola gövdesi çizilmeden
  /// önce dolu halkanın közden naneye döndüğü kısa pencere (ROADMAP madde 19).
  /// Bitmiş odak fazı burada tutuluyor: durum çoktan molaya geçti, ama ekranda
  /// hâlâ biten seansın gövdesi var.
  ///
  /// Yalnızca `focusRunning → breakRunning` geçişinde doluyor — iptalde
  /// (`→ idle`) ve duraklatmada (`→ focusPaused`) değil.
  PomodoroFocusRunning? _completingFocus;
  Timer? _completionTimer;

  void _startCompletion(PomodoroFocusRunning finished, Duration duration) {
    _completionTimer?.cancel();
    setState(() => _completingFocus = finished);
    _completionTimer = Timer(duration, () {
      if (mounted) setState(() => _completingFocus = null);
    });
  }

  /// Aynı kutlamanın iki kez açılmasını engelleyen kapı. `consume()` yuvayı
  /// hemen boşaltıyor ama dialog açıkken gelen ikinci bir tik (ör. gecikmeli
  /// yakalama tiki ikinci bir fazı da kapatırsa) yeni bir kutlama sunabilir.
  bool _celebrating = false;

  /// Kutlamayı gösterir: rozet açılışında Ekran 04'ün dialogu, seri eşiğinde
  /// kutlama dialogu. İkisinin de birincil aksiyonu başarı kartı — paylaşım
  /// artık kullanıcının gidip aramasını beklemiyor, kutlama anında önüne
  /// geliyor.
  Future<void> _showCelebration(SessionCelebration celebration) async {
    if (_celebrating) return;
    _celebrating = true;
    // Yuva hemen boşaltılıyor: dialog açıkken ekran yeniden çizilirse
    // `ref.listen` yeniden tetiklenmesin.
    ref.read(sessionCelebrationProvider.notifier).consume();
    try {
      // Dolu halkanın közden naneye döndüğü pencere (bkz. [_startCompletion])
      // bitmeden dialog açmak, seansın kendi kapanış anını kapatırdı.
      await Future<void>.delayed(AppMotion.respectingMotion(context, AppMotion.slow));
      if (!mounted) return;

      switch (celebration) {
        case BadgeCelebration(badgeKeys: final List<String> keys):
          // Katalog sırasında geziliyor: aynı anda birden fazla rozet açılabilir
          // ve merdivenin sırası sunum kararıdır (`session_celebration.dart`).
          for (final BadgeDefinition definition in kBadgeCatalog) {
            if (!keys.contains(definition.key)) continue;
            if (!mounted) return;
            await showBadgeUnlockDialog(
              context,
              definition: definition,
              unlocked: true,
              // Rozet kutlamasında şablon zorlanmıyor: kullanıcının seçtiği
              // kart neyse o açılıyor.
              onOpenStoryCard: _openStoryCard,
            );
          }
        case StreakCelebration(days: final int days):
          await showStreakCelebrationDialog(
            context,
            days: days,
            // Seri kutlamasında SERİ şablonu öneriliyor: "30 gün" diye kutlanıp
            // bugünün saatini gösteren bir kart açmak tutarsız olurdu. Tercih
            // **yazılmıyor**, yalnızca bu açılışta gösteriliyor.
            onOpenStoryCard: () => _openStoryCard(StoryCardTemplate.streak),
          );
      }
    } finally {
      _celebrating = false;
    }
  }

  /// Başarı kartını bu ekranın **yerine** açar.
  ///
  /// `push` değil `pushReplacement`: `push` olsaydı bu ekran altta canlı
  /// kalırdı ve molanın bitişinde idle dinleyicisi `context.pop()` çağırıp
  /// kullanıcıyı kartın ortasından çekip alırdı. Yerine geçmek molayı
  /// durdurmuyor — faz controller'da sürüyor, bitiş bildirimi kurulu ve
  /// Ekran 02 aktif seansı kurtarıyor.
  void _openStoryCard([StoryCardTemplate? template]) {
    context.pushReplacement(RoutePaths.storyCard, extra: template);
  }

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
    _completionTimer?.cancel();
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final PomodoroPhase phase = ref.watch(pomodoroControllerProvider);

    ref.listen<PomodoroPhase>(pomodoroControllerProvider, (PomodoroPhase? previous, PomodoroPhase next) {
      if (previous is PomodoroFocusRunning && next is PomodoroBreakRunning) {
        // "Hareketi azalt" açıkken pencere hiç açılmıyor: mola gövdesi ilk
        // karede geliyor, atlanacak bir ara hâl yok.
        final Duration duration = AppMotion.respectingMotion(context, AppMotion.slow);
        if (duration > Duration.zero) _startCompletion(previous, duration);
      }
      if (next is PomodoroIdle && !_leftForIdle) {
        // Ekrandan çıkılıyor: gösterilemeyecek bir kutlama yuvada kalmasın,
        // yoksa bir sonraki seansın başında eski kutlama açılırdı.
        ref.read(sessionCelebrationProvider.notifier).consume();
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

    // Kutlamayı `PomodoroController._completeFocus` yuvaya bırakıyor; bu ekran
    // o anda zaten ağaçta (tamamlanmayı tetikleyen tik buradan geliyor).
    // `addPostFrameCallback`: `build` sürerken dialog açmak yasak.
    ref.listen<SessionCelebration?>(sessionCelebrationProvider,
        (SessionCelebration? previous, SessionCelebration? next) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showCelebration(next));
      });
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
        // Tamamlanma penceresi açıkken durum artık mola, ekran hâlâ biten
        // seansın gövdesi: sayaç 00:00'da, halka dolu ve közden naneye
        // dönüyor. Pencere kapanınca mola gövdesi geliyor.
        body: _completingFocus != null
            ? _FocusBody(
                phase: _completingFocus!,
                remaining: Duration.zero,
                progress: 1,
                running: true,
                completing: true,
              )
            : switch (phase) {
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

  // Perde rengi `dialogTheme.barrierColor`dan geliyor (bkz. `app_theme.dart`).
  showDialog<void>(
    context: context,
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
  const _FocusBody({
    required this.phase,
    required this.remaining,
    required this.progress,
    required this.running,
    this.completing = false,
  });

  /// [PomodoroFocusRunning] ya da [PomodoroFocusPaused].
  final PomodoroPhase phase;
  final Duration remaining;
  final double progress;
  final bool running;

  /// Seans doğal bitişle kapandı: halka dolu ve közden naneye dönüyor, denetim
  /// düğmeleri artık bir şey yapamayacağı için dokunuşa kapalı.
  final bool completing;

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
                      Text(l10n.focusCycleBadge(_cyclePosition),
                          style: AppTypography.kicker(
                              fontSize: AppTextSize.kicker, color: colors.ember)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(PhosphorIconsRegular.eyeSlash, size: 14, color: colors.neutral600),
                    const SizedBox(width: 6),
                    Text(l10n.focusAdHidden,
                        style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.neutral600)),
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
                    // Halka ilk değerine bir kez akıyor (kurtarılan seans yarı
                    // dolu bir halkayla açılmasın); sonraki saniye tikleri
                    // doğrudan geçiyor — bkz. `SettlingProgress`.
                    child: completing
                        ? _CompletionRing(colors: colors)
                        : SettlingProgress(
                            progress: progress,
                            builder: (BuildContext context, double ringProgress, Widget? _) => CustomPaint(
                              size: const Size(330, 330),
                              painter: running
                                  ? SessionRingPainter(
                                      progress: ringProgress,
                                      colors: colors,
                                      gradientColors: _focusRingGradient(colors),
                                      gradientStops: const <double>[0, 0.62, 1],
                                    )
                                  : SessionRingPainter(
                                      progress: ringProgress,
                                      colors: colors,
                                      solidColor: colors.neutral700,
                                    ),
                            ),
                          ),
                  ),
                  RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(
                          height: 106,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FlameWidget(
                              // Kademe kalıcı: seans bitince alev buraya
                              // döner, asla altına inmez.
                              tier: ref.watch(flameTierProvider).tier,
                              boxHeight: 98,
                              intensity: progress,
                              flickering: running,
                              desaturated: !running,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(formatClock(remaining),
                            style: AppTypography.counter(
                                fontSize: AppTextSize.counterXl, color: clockColor, height: 1)),
                        const SizedBox(height: 6),
                        Text(phaseLabel,
                            style: AppTypography.kicker(
                                fontSize: AppTextSize.kicker, color: phaseColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            // Tamamlanma penceresinde seans çoktan kapandı: iptal onayı da
            // oynat/duraklat da artık molaya uygulanırdı (ikisi de sessizce
            // düşer). Düğmeler yerinde duruyor ama dokunuşa kapalı.
            IgnorePointer(
              ignoring: completing,
              child: Row(
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
            ),
            const Spacer(),
            _FocusHintLine(text: hintLine, iconColor: hintIconColor),
          ],
        ),
      ),
    );
  }

}

/// Odak seansının doğal bitişi: dolu halka bir kez közden naneye dönüyor
/// (ROADMAP madde 19). 25 dakika bitip ekranın öylece mola gövdesine geçmesi
/// uygulamanın en duygusal anını sessiz bırakıyordu.
///
/// **SPEC.md §6.4 ile çatışmıyor:** bu hareket seansın **bittiği anda**
/// başlıyor, yani odak süresi dolmuşken; süren seans boyunca tek bir fazladan
/// kare üretmiyor ve bir kez çalışıp duruyor.
class _CompletionRing extends StatelessWidget {
  const _CompletionRing({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final List<Color> from = _focusRingGradient(colors);
    final List<Color> to = _breakRingGradient(colors);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.respectingMotion(context, AppMotion.slow),
      curve: AppMotion.standard,
      builder: (BuildContext context, double t, Widget? _) => CustomPaint(
        size: const Size(330, 330),
        painter: SessionRingPainter(
          // Halka tanım gereği dolu: geçişin anlattığı şey oranın değişmesi
          // değil, biten seansın renginin molaya devredilmesi.
          progress: 1,
          colors: colors,
          gradientColors: <Color>[
            for (int i = 0; i < from.length; i++) Color.lerp(from[i], to[i], t)!,
          ],
          // İki gradyanın orta durağı (0.62 ve 0.7) arasında sabit bir orta
          // nokta: duraklar da tween'lenseydi 420ms boyunca her karede yeni
          // bir `LinearGradient` kurulurdu, gözle görülür bir karşılığı yok.
          gradientStops: const <double>[0, 0.66, 1],
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
            Expanded(
                child: Text(widget.text,
                    style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral400))),
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
                      Text(breakLabel,
                          style: AppTypography.kicker(
                              fontSize: AppTextSize.kicker, color: colors.mint)),
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
                        Text(l10n.breakPomodoroDone(phase.cyclePosition),
                            style: AppTypography.body(
                                fontSize: AppTextSize.sm, color: colors.neutral500)),
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
                    child: SettlingProgress(
                      progress: progress,
                      builder: (BuildContext context, double ringProgress, Widget? _) => CustomPaint(
                        size: const Size(330, 330),
                        painter: SessionRingPainter(
                          progress: ringProgress,
                          colors: colors,
                          gradientColors: _breakRingGradient(colors),
                          gradientStops: const <double>[0, 0.7, 1],
                        ),
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
                          fontSize: AppTextSize.counterXl,
                          color: colors.brightness == Brightness.dark ? const Color(0xFFE7FFF8) : colors.text,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.breakRunning,
                          style: AppTypography.kicker(
                              fontSize: AppTextSize.kicker, color: colors.mint)),
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
                  Text(l10n.breakTipsHeading,
                      style: AppTypography.kicker(
                          fontSize: AppTextSize.kicker, color: colors.neutral600)),
                  const SizedBox(height: 10),
                  for (final BreakTip tip in tips)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(tip.icon, size: 16, color: tip.tint == BreakTipTint.mint ? colors.mint : colors.sky),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(tip.text(l10n),
                                  style: AppTypography.body(
                                      fontSize: AppTextSize.md, color: colors.neutral300))),
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
            Text(l10n.cancelDialogTitle,
                style: AppTypography.display(
                    fontSize: AppTextSize.heading, weight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 10),
            Text(bodyText,
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral400)),
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
                      style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral300),
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
                      child: Text(l10n.cancelDialogConfirm,
                          style: AppTypography.label(
                              fontSize: AppTextSize.md,
                              weight: FontWeight.w500,
                              color: colors.rose)),
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
