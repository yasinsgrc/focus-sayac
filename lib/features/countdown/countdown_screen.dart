import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_typography.dart';
import '../../core/time/app_day.dart';
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/pop_on_increase.dart';
import '../../core/widgets/rise_in.dart';
import '../../core/widgets/rolling_number.dart';
import '../../domain/countdown/countdown_math.dart';
import '../../domain/exams/exam_picker_request.dart';
import '../../domain/exams/exam_providers.dart';
import '../../domain/flame/flame_tier.dart';
import '../../domain/pomodoro/pomodoro_controller.dart';
import '../../domain/pomodoro/pomodoro_phase.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import '../../domain/settings/settings_providers.dart';
import '../../domain/stats/stats_providers.dart';
import '../../domain/stats/weekly_goal.dart';
import '../../domain/streak/comeback_status.dart';
import '../../domain/streak/streak_calculator.dart';
import '../../domain/time/duration_formatter.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/ads/banner_ad_slot.dart';
import '../../services/storage/app_database.dart';
import 'widgets/countdown_ring_painter.dart';
import 'widgets/exam_picker_sheet.dart';

/// Ekran 02 — geri sayım. Prototip satır 68-135 birebir; telefon çerçevesi
/// (46px radius, sahte 9:41 durum çubuğu) tasarım aracının mockup'ı, gerçek
/// uygulamada yok (SPEC.md Ekran 01 kuralı tüm ekranlara uygulanır).
class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key, this.autoOpenSheet = false});

  final bool autoOpenSheet;

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends ConsumerState<CountdownScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _dashController;
  Timer? _secondTicker;
  DateTime _nowUtc = DateTime.now().toUtc();
  bool _redirectedForExpiry = false;

  @override
  void initState() {
    super.initState();
    _dashController = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
    // Saniye tikleyicisi `initState`te değil `didChangeDependencies`te kuruluyor
    // (o da ilk build'den önce bir kez çalışır) — kurulması ve durması tek
    // koşula bağlı kalsın diye; bkz. `_setSecondTickerEnabled`.
    if (widget.autoOpenSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showExamPickerSheet(context);
      });
    }
    _redirectIfSessionRecovered();
  }

  /// SPEC.md DoD: "Uygulama öldürülüp açıldığında aktif seans kurtarılıyor"
  /// — `PomodoroController.build()` `SharedPreferences`'tan aktif fazı geri
  /// yüklerse (Faz 5), soğuk başlangıçta uygulama her zaman bu ekrandan
  /// (initialLocation) açıldığı için buradan odak/mola ekranına yönlendirmek
  /// gerekiyor.
  ///
  /// Kontrol yalnızca burada, ekran ilk kurulurken bir kez yapılıyor:
  /// `sharedPreferencesProvider` hazır bir değerle override edildiği için
  /// (`main.dart`) kurtarılan faz bu noktada senkron okunabiliyor. Bu kontrol
  /// `build()` içinde fazı izleyerek yapılsaydı "… DAKİKA ODAKLAN" butonunun
  /// `startFocus()` çağrısı da fazı `idle` dışına taşıdığı için tetiklenir,
  /// butonun kendi `push`'uyla birlikte yığına iki `FocusSessionScreen`
  /// eklenirdi; seans bitişindeki tek `pop()` o zaman yalnızca üsttekini
  /// kapatıp kullanıcıyı boş bir odak ekranında bırakıyordu.
  void _redirectIfSessionRecovered() {
    if (ref.read(pomodoroControllerProvider) is PomodoroIdle) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.push(RoutePaths.focusSession);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // SPEC.md §6 kural 4: odak seansı sürerken dekoratif animasyonlar durur.
    // Odak ekranı bu rotanın **üstüne** `push` ediliyor ve `Overlay`, üstteki
    // opak rotanın altında kalan girdilerin `TickerMode`unu kapatıyor — halkanın
    // `_dashController`ı bu yüzden kendiliğinden susuyor. `Timer.periodic` ise
    // `TickerMode`a bakmaz: kapalı kalan bu rota, odak ekranı 60 fps çizerken
    // saniyede bir `setState` ile yeniden build + layout oluyordu (görünmeyen,
    // 25 dakika süren bir iş). Tikleyici aynı sinyale bağlanınca ikisi birlikte
    // duruyor, odak ekranı popladığında ikisi birlikte geri geliyor.
    _setSecondTickerEnabled(TickerMode.of(context));
  }

  void _setSecondTickerEnabled(bool enabled) {
    if (enabled == (_secondTicker != null)) return;
    if (!enabled) {
      _secondTicker?.cancel();
      _secondTicker = null;
      return;
    }
    // Tikleyici durduğu sürece saat ilerledi; ilk periyodik tik beklenmeden
    // yakalanıyor (bu çağrı build'den önce, `setState` gerekmiyor).
    _nowUtc = DateTime.now().toUtc();
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
  }

  @override
  void dispose() {
    _dashController.dispose();
    _secondTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AsyncValue<Exam?> activeExamAsync = ref.watch(activeExamProvider);

    // Ana ekran widgetindan gelen "sinav sec" istegi (Faz 16). Ekran zaten
    // acikken geldigi icin `autoOpenSheet` parametresi ise yaramiyor:
    // `go_router` ayni konuma gidince bu State yeniden kurulmuyor.
    ref.listen<int>(examPickerRequestProvider, (int? previous, int next) {
      if (previous == null || next <= previous) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showExamPickerSheet(context);
      });
    });

    ref.listen<AsyncValue<Exam?>>(activeExamProvider, (AsyncValue<Exam?>? previous, AsyncValue<Exam?> next) {
      final Exam? exam = next.value;
      if (exam != null && exam.dateUtc.isBefore(DateTime.now().toUtc()) && !_redirectedForExpiry) {
        _redirectedForExpiry = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(RoutePaths.examExpired);
        });
      }
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: activeExamAsync.when(
              data: (Exam? exam) {
                if (exam == null) return const _NoExamBody();
                return _CountdownBody(exam: exam, nowUtc: _nowUtc, dashController: _dashController);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => _NoExamBody(
                title: AppLocalizations.of(context).countdownExamLoadFailedTitle,
                message: AppLocalizations.of(context).countdownExamLoadFailedMessage,
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            // Yönlendirme kuralı `navigateToNavTab`de: beş ekran da aynı
            // çubuğu gösterdiği için beş kopya `switch` yerine tek yer.
            child: BottomNavBar(
              active: AppNavTab.countdown,
              onSelect: (AppNavTab tab) => navigateToNavTab(context, tab, current: AppNavTab.countdown),
            ),
          ),
        ],
      ),
    );
  }
}

/// Testler parıltının halkayla eş merkezli olduğunu bu anahtarla doğruluyor.
const Key kCountdownGlowKey = Key('countdown_ambient_glow');

/// Ekran 02'nin geniş mor aurora'sı (prototip satır 72: 580×520, `.34` → %60'ta
/// saydam).
///
/// Prototipte ekrana `top:60;left:-90` ile çakılıydı; ama o değerler 390px'lik
/// mockup çerçevesine — ve onun **çizilmeyen** 52px'lik sahte durum çubuğuna —
/// göre ölçülmüştü. Ekrana sabitlenen her değer bu yüzden gerçek cihazda
/// halkanın altına kayıyor: durum çubuğu her cihazda farklı, ekran genişliği de
/// 390 değil. Parıltı artık odak dairesinin kendi `Stack`inde duruyor, yani
/// merkezi hesapla değil **tanım gereği** halkanınkiyle aynı.
///
/// Düzende **sıfır** yer kaplıyor: `SizedBox`ın 0×0'ına oturan [OverflowBox],
/// 580×520'lik boyayı o noktanın çevresine ortalıyor. Böylece parıltı ne
/// `Stack`in boyunu büyütüyor ne de `_NoExamBody`nin sınırsız yükseklikteki
/// `Column`unda ölçüsüz kalıyor; `Stack(alignment: center)` içinde konumu
/// doğrudan yığının merkezi oluyor. Taşan alanın kırpılmaması için yığında
/// `clipBehavior: Clip.none` gerekiyor — ama gradyan zaten r=156'da (0.6 × 260)
/// saydama düştüğü için boya halkanın 14px ötesinde bitiyor, üstteki başlığa
/// hiç değmiyor.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return IgnorePointer(
      child: SizedBox(
        width: 0,
        height: 0,
        child: OverflowBox(
          minWidth: 580,
          maxWidth: 580,
          minHeight: 520,
          maxHeight: 520,
          child: DecoratedBox(
            key: kCountdownGlowKey,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[colors.glowViolet.withValues(alpha: 0.34), Colors.transparent],
                stops: const <double>[0, 0.6],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aktif sınav yokken (ilk kurulumda seçim yapılmadan, ya da aktif sınav
/// silindiğinde) gösterilir. Daha önce burada `SizedBox.shrink()` vardı:
/// ekranda yalnızca alt gezinme çubuğu kalıyordu ve gezinme çubuğunun hiçbir
/// sekmesi sınav seçimine gitmediği için kullanıcı geri sayıma dönemiyordu.
/// Aynı çıkışsızlık `activeExamProvider` hata yayınladığında da oluşuyordu,
/// o dal da buraya bağlandı — sadece başlık/metin değişir, "SINAV SEÇ"
/// düğmesi (ve içindeki "Kendi sınavımı ekle") her iki durumda da çalışır.
class _NoExamBody extends StatelessWidget {
  const _NoExamBody({this.title, this.message});

  /// `null` ise "hedef seçilmedi" boş durumu; hata dalı kendi metnini geçiyor.
  /// Varsayılanlar ARB'den geldiği için (`const` olamazlar) alanlar nullable.
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String titleText = title ?? l10n.countdownNoExamTitle;
    final String messageText = message ?? l10n.countdownNoExamMessage;

    return Padding(
      // Alt boşluk gezinme çubuğunu (64px + 18px kenar boşluğu) açıkta bırakır.
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 100),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Aurora bu dalda da ekranda kalıyor (eskiden `Scaffold`
            // seviyesindeydi), yalnızca odağı bu durumun kendi dairesi.
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                const AmbientGlow(),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderStrong),
                  ),
                  child: Icon(PhosphorIconsDuotone.calendarBlank, size: 46, color: colors.neutral600),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(titleText,
                style: AppTypography.display(
                    fontSize: AppTextSize.headingLg, weight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 12),
            SizedBox(
              width: 262,
              child: Text(
                messageText,
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: AppTextSize.lg, color: colors.neutral500),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 54,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  side: BorderSide(color: colors.ember),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: colors.emberDeep,
                ),
                onPressed: () => showExamPickerSheet(context),
                child: Text(
                  l10n.countdownPickExam,
                  style: AppTypography.label(
                      fontSize: AppTextSize.lg, weight: FontWeight.w600, color: colors.ember),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownBody extends ConsumerWidget {
  const _CountdownBody({required this.exam, required this.nowUtc, required this.dashController});

  final Exam exam;
  final DateTime nowUtc;
  final AnimationController dashController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int days = daysTo(exam.dateUtc, nowUtc);
    final double ratio = progressRatio(days);
    final Duration remaining = remainingDuration(exam.dateUtc, nowUtc);
    final Duration remainder = remaining - Duration(days: remaining.inDays);
    final String hh = remainder.inHours.toString().padLeft(2, '0');
    final String mm = (remainder.inMinutes % 60).toString().padLeft(2, '0');
    final String ss = (remainder.inSeconds % 60).toString().padLeft(2, '0');
    final DateFormat examDateFormat = DateFormat('d MMMM y', 'tr');
    final String examDateText = examDateFormat.format(toIstanbulWallClock(exam.dateUtc));

    // Son düzlükte ekranın işareti dönüyor: kahraman sayı kalan gün değil, bu
    // sınav için biriken odak saati olur (`isFinalStretch` gerekçeyi taşıyor).
    // Halkanın oranı **değişmiyor** — o zaten sınava yaklaştıkça dolan, yani
    // zaten ileriye bakan bir gösterge.
    final int examSeconds = ref.watch(examFocusSecondsProvider(exam.id));
    final bool finalStretch = isFinalStretch(days: days, examFocusSeconds: examSeconds);
    final int examFocusHours = formatFocusDuration(examSeconds).hours;

    // Halka içindeki meta satırının ortak stili; son düzlükte bu satır iki
    // parçadan üçe çıktığı için üç kez tekrarlanmasın diye burada.
    final TextStyle metaStyle = AppTypography.body(
        fontSize: AppTextSize.sm, weight: FontWeight.w500, color: colors.neutral400);
    final Widget metaDot = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Container(
          width: 3, height: 3, decoration: BoxDecoration(color: colors.ember, shape: BoxShape.circle)),
    );

    final TodayFocusStats todayStats = ref.watch(todayFocusStatsProvider);
    final StreakStatus streakStatus = ref.watch(streakStatusProvider);
    final int streak = streakStatus.days;
    final FocusDurationParts todayParts = formatFocusDuration(todayStats.totalSeconds);
    final int cycleDots = todayStats.completedCount.clamp(0, 4);
    final WeeklyGoalProgress weeklyGoal = ref.watch(weeklyGoalProgressProvider);
    final ComebackStatus comeback = ref.watch(comebackStatusProvider);

    // Süre `AppSettings.focusMinutes`ten gelir (`startFocus()` de aynı ayarı
    // okur); ayar akışı ilk değerini yayınlamadan önceki tek karede sayı
    // yerine yalnızca eylem gösteriliyor — sabit bir "25" yazmak, ayar
    // değiştirildiğinde butonun yanlış süre vaat etmesi demekti.
    final int? focusMinutes = ref.watch(focusMinutesProvider);
    final String focusButtonLabel = focusMinutes == null
        ? l10n.countdownFocusButton
        : l10n.countdownFocusButtonWithMinutes(focusMinutes);

    // Gövde **yalnızca sığmadığında** kayıyor: `minHeight` ekranın tamamı
    // olduğu için uzun ekranlarda içerik eskisi gibi yerleşiyor ve görünüm
    // birebir aynı kalıyor. Banner kaydırma alanının dışında — reklam
    // kaydırılıp gözden kaybolmuyor, yuvası da eskisi gibi altta duruyor.
    //
    // Haftalık hedef satırı (ROADMAP madde 24) eklenince gerekti: 390x844
    // ekranda 90dp lik adaptive banner ile Ekran 02 nin toplam bosluğu 26px,
    // satır ise en sıkı hâliyle 43px istiyor. Alternatiflerin hepsi prototipin
    // ölçülerini (halka 316, dikey aralıklar) değiştirmeyi gerektiriyordu;
    // kaydırma hiçbirine dokunmuyor. Ekran zaten sınırdaydı: büyük sistem
    // yazı tipinde bu madde olmadan da taşardı.
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        RiseIn(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              GestureDetector(
                                onTap: () => showExamPickerSheet(context),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(l10n.countdownTarget,
                                        style: AppTypography.kicker(
                                            fontSize: AppTextSize.kicker, color: colors.neutral600)),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Text(
                                          exam.name,
                                          style: AppTypography.display(
                                              fontSize: AppTextSize.titleLg, color: colors.text),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(PhosphorIconsRegular.caretDown, size: 14, color: colors.ember),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => context.push(RoutePaths.addExam),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.fillMedium),
                                  ),
                                  child: Icon(PhosphorIconsRegular.plus, size: 18, color: colors.neutral400),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        RiseIn(
                          delay: RiseIn.step,
                          child: Center(
                            child: SizedBox(
                              width: 316,
                              height: 316,
                              child: Stack(
                                alignment: Alignment.center,
                                // Aurora 316'lık kutudan taşıyor; kırpılmaması gerekiyor.
                                // Taşan kısım zaten saydam (bkz. [kCountdownGlowKey]).
                                clipBehavior: Clip.none,
                                children: <Widget>[
                                  // Geniş aurora — prototip satır 72.
                                  const AmbientGlow(),
                                  // Prototip satır 81: halkanın **içinde**, sayının arkasında
                                  // duran çekirdek (`inset:56px` → 204px, `.42` → %68'de
                                  // saydam). Prototipin `glow 6s` nabzı, SPEC.md §6'nın
                                  // dekoratif animasyon kuralı gereği statik gradyana
                                  // sadeleştirildi (DECISIONS.md'deki diğer nabızlar gibi).
                                  IgnorePointer(
                                    child: Container(
                                      width: 204,
                                      height: 204,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: <Color>[
                                            colors.glowViolet.withValues(alpha: 0.42),
                                            Colors.transparent,
                                          ],
                                          stops: const <double>[0, 0.68],
                                        ),
                                      ),
                                    ),
                                  ),
                                  RepaintBoundary(
                                    // Oran yalnızca sınav değişince ve gün dönümünde
                                    // değişiyor; saniye tikleri `days`i kımıldatmadığı için
                                    // tween boşta çalışmıyor, o iki anda akıyor.
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(end: ratio),
                                      duration: AppMotion.respectingMotion(context, AppMotion.slow),
                                      curve: AppMotion.standard,
                                      builder: (BuildContext context, double animatedRatio, Widget? _) {
                                        // Emek ekseni ayrı bir tween'de (ROADMAP
                                        // madde 27): iki oran bambaşka anlarda
                                        // değişiyor — zaman gün dönümünde, emek
                                        // her seans bitişinde — ve tek tween iki
                                        // değeri taşıyamaz. Süre/eğri
                                        // `_WeeklyGoalRow`unkiyle aynı, böylece
                                        // halkanın yayı ile kartın çubuğu aynı
                                        // hızda yürüyor.
                                        return TweenAnimationBuilder<double>(
                                          tween: Tween<double>(end: weeklyGoal.ratio),
                                          duration: AppMotion.respectingMotion(context, AppMotion.slow),
                                          curve: AppMotion.standard,
                                          builder: (BuildContext context, double animatedEffort, Widget? _) {
                                            return AnimatedBuilder(
                                              animation: dashController,
                                              builder: (BuildContext context, Widget? child) {
                                                return CustomPaint(
                                                  size: const Size(316, 316),
                                                  painter: CountdownRingPainter(
                                                    progressRatio: animatedRatio,
                                                    effortRatio:
                                                        weeklyGoal.isOff ? null : animatedEffort,
                                                    effortReached: weeklyGoal.isReached,
                                                    dashRotation: dashController.value * 2 * math.pi,
                                                    colors: colors,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      ShaderMask(
                                        shaderCallback: (Rect bounds) => LinearGradient(
                                          colors: colors.chromeGradient,
                                          stops: AppColors.chromeGradientStops,
                                        ).createShader(bounds),
                                        child: RollingNumber(
                                          value: finalStretch ? examFocusHours : days,
                                          style: AppTypography.counter(
                                              fontSize: AppTextSize.counterHero,
                                              weight: FontWeight.w700,
                                              color: Colors.white,
                                              height: 1),
                                        ),
                                      ),
                                      Text(finalStretch ? l10n.countdownFocusedHoursUnit : l10n.countdownDaysLeft,
                                          style: AppTypography.kicker(
                                              fontSize: AppTextSize.kicker, color: colors.neutral500)),
                                      const SizedBox(height: 16),
                                      // Kalan gün kahramanlığı bırakıyor ama **kaybolmuyor**:
                                      // son düzlükte bu satırın başına geçiyor ve üç parça
                                      // oluyor ("12 GÜN • 04:22:31 • 12 Haziran 2027").
                                      // Halkanın kesik çizgili iç çemberi 224px; 316'lık
                                      // kutuda taşma hatası çıkmasa da satır o çemberi
                                      // aşabiliyor, `FittedBox` böyle bir durumda kırpmak
                                      // yerine küçültüyor (284 = halkanın 9px'lik izinin
                                      // içinde kalan genişlik).
                                      SizedBox(
                                        width: 284,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              if (finalStretch) ...<Widget>[
                                                // Gün sayısı burada da azalan bir değer;
                                                // `RollingNumber` gece yarısı zıplamayı
                                                // engelliyor, sabit "GÜN" eki kımıldamıyor.
                                                RollingNumber(
                                                  value: days,
                                                  text: l10n.countdownDaysLeftInline(days),
                                                  style: metaStyle,
                                                ),
                                                metaDot,
                                              ],
                                              Text(
                                                '$hh:$mm:$ss',
                                                style: metaStyle.copyWith(
                                                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                                                ),
                                              ),
                                              metaDot,
                                              Text(examDateText, style: metaStyle),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        RiseIn(
                          delay: RiseIn.step * 2,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: colors.surfaceCardSoft,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.fromBorderSide(BorderSide(color: colors.hairline)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    Text(l10n.countdownToday,
                                        style: AppTypography.kicker(
                                            fontSize: AppTextSize.kicker, color: colors.neutral600)),
                                    if (streak > 0)
                                      // Korumadaki seri sönmüş değil, soluk: alev yerinde
                                      // duruyor ve yalnızca opaklığı düşüyor. Renk tokenı
                                      // değiştirilmiyor (ember → nötr bir gri, "seri bitti"
                                      // demek olurdu); geri kazanıldığı kare rozet yeniden
                                      // tam parlaklığa dönüyor.
                                      AnimatedOpacity(
                                        opacity: streakStatus.isProtected ? 0.45 : 1,
                                        duration: AppMotion.respectingMotion(context, AppMotion.base),
                                        curve: AppMotion.standard,
                                        child: Container(
                                          height: 25,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(color: colors.emberDeep, borderRadius: BorderRadius.circular(999)),
                                          child: Semantics(
                                            container: true,
                                            excludeSemantics: true,
                                            // Soluklaşma yalnızca görsel bir sinyal; ekran
                                            // okuyucu korumayı sözle duyuyor.
                                            label: streakStatus.isProtected
                                                ? l10n.countdownStreakProtectedSemantics(streak)
                                                : l10n.countdownStreakBadge(streak),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: <Widget>[
                                                // Seri büyüdüğünde alev sayıya eşlik ediyor
                                                // (ROADMAP madde 19); seri 0'dan 1'e çıkarken
                                                // rozetin kendisi ağaca yeni giriyor, o yüzden
                                                // vurgu ilk build'de çalışmıyor.
                                                PopOnIncrease(
                                                  value: streak,
                                                  child: Icon(PhosphorIconsFill.flame, size: 13, color: colors.ember),
                                                ),
                                                const SizedBox(width: 5),
                                                RollingNumber(
                                                  value: streak,
                                                  text: l10n.countdownStreakBadge(streak),
                                                  style: AppTypography.body(
                                                      fontSize: AppTextSize.sm,
                                                      weight: FontWeight.w500,
                                                      color: colors.ember),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: <Widget>[
                                    // Sayılar `RollingNumber`a taşındığı için `RichText`in
                                    // tek ağacı Row'a açıldı; hizalama yine yazı tabanında,
                                    // yani span'ların verdiğinin aynısı.
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: <Widget>[
                                        RollingNumber(
                                          value: todayParts.hours,
                                          style: AppTypography.counter(
                                              fontSize: AppTextSize.counterMd, color: colors.text, height: 1),
                                        ),
                                        Text(l10n.countdownHoursUnit,
                                            style: AppTypography.display(
                                                fontSize: AppTextSize.title,
                                                weight: FontWeight.w500,
                                                color: colors.neutral500)),
                                        RollingNumber(
                                          value: todayParts.minutes,
                                          style: AppTypography.counter(
                                              fontSize: AppTextSize.counterMd, color: colors.text, height: 1),
                                        ),
                                        Text(l10n.countdownMinutesUnit,
                                            style: AppTypography.display(
                                                fontSize: AppTextSize.title,
                                                weight: FontWeight.w500,
                                                color: colors.neutral500)),
                                      ],
                                    ),
                                    // Gün henüz boşken dört nokta 0/4'ü, çubuk da %0'ı
                                    // duyuruyordu: ikisi birden açılışı bir eksik bildirimine
                                    // çeviriyor. İlk pomodoro tamamlanana kadar ikisi de
                                    // yok; yerlerini ileriye bakan tek satır alıyor.
                                    if (todayStats.completedCount > 0) ...<Widget>[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 7),
                                        child: Row(
                                          children: List<Widget>.generate(4, (int i) {
                                            return Padding(
                                              padding: const EdgeInsets.only(left: 5),
                                              child: Container(
                                                width: 9,
                                                height: 9,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: i < cycleDots ? colors.mint : colors.fillMedium,
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (todayStats.completedCount > 0) ...<Widget>[
                                  const SizedBox(height: 14),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: SizedBox(
                                      height: 4,
                                      child: LinearProgressIndicator(
                                        value: cycleDots / 4,
                                        backgroundColor: colors.fillSubtle,
                                        valueColor: AlwaysStoppedAnimation<Color>(colors.mint),
                                      ),
                                    ),
                                  ),
                                ] else ...<Widget>[
                                  const SizedBox(height: 12),
                                  Text.rich(
                                    TextSpan(
                                      style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.neutral500),
                                      // Üç ayrı vaat, üçü de kazanç tarafından: korumadaki
                                      // seride bugünkü pomodoro seriyi büyütmüyor, dünkü
                                      // boşluğu telafi edip onu geri kazandırıyor; seri
                                      // yokken büyütecek bir sayı da yok, seans seriyi
                                      // başlatıyor; gerisinde seri bir gün ileri taşınıyor.
                                      children: streakStatus.isProtected
                                          ? <InlineSpan>[
                                              TextSpan(text: l10n.countdownStreakProtectedHintPrefix),
                                              TextSpan(
                                                  text: l10n.countdownStreakProtectedHintValue,
                                                  style: TextStyle(color: colors.ember)),
                                              TextSpan(text: l10n.countdownStreakProtectedHintSuffix),
                                            ]
                                          : streak == 0
                                              ? <InlineSpan>[
                                                  TextSpan(text: l10n.countdownFirstStreakHintPrefix),
                                                  TextSpan(
                                                      text: l10n.countdownFirstStreakHintValue,
                                                      style: TextStyle(color: colors.ember)),
                                                  TextSpan(text: l10n.countdownFirstStreakHintSuffix),
                                                ]
                                              : <InlineSpan>[
                                                  TextSpan(text: l10n.countdownFirstSessionHintPrefix),
                                                  TextSpan(
                                                      text: l10n.countdownFirstSessionHintValue(streak + 1),
                                                      style: TextStyle(color: colors.ember)),
                                                  TextSpan(text: l10n.countdownFirstSessionHintSuffix),
                                                ],
                                    ),
                                  ),
                                ],
                                // Haftalık hedef (ROADMAP madde 24). Günlük noktaların
                                // aksine boş haftada **gizlenmiyor**: dört nokta 0/4'te bir
                                // eksik bildirimi olurdu, ama haftalık çubuğun pazartesi
                                // sabahı %0'da olması eksiklik değil, haftanın başıdır.
                                // Tek gizlenme koşulu hedefin kapalı olması.
                                // Dönüş şeridi (ROADMAP madde 26): üç gün
                                // odaklanmayan kullanıcı döndüğünde kartın
                                // sıfırlarını okumadan önce korunanı görüyor.
                                if (comeback.welcomeDue) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Divider(height: 1, thickness: 1, color: colors.hairline),
                                  const SizedBox(height: 10),
                                  _ComebackRow(
                                    cumulativeSeconds: ref.watch(focusStatsProvider).cumulativeSeconds,
                                  ),
                                ],
                                if (!weeklyGoal.isOff) ...<Widget>[
                                  const SizedBox(height: 12),
                                  Divider(height: 1, thickness: 1, color: colors.hairline),
                                  const SizedBox(height: 10),
                                  _WeeklyGoalRow(progress: weeklyGoal),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        RiseIn(
                          delay: RiseIn.step * 3,
                          // Ekranın birincil eylemi: dalganın yanına basıldığını hissettiren
                          // ölçek de giriyor (madde 20).
                          child: AppPressable(
                            child: SizedBox(
                              height: 60,
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
                                    onTap: () async {
                                      await ref.read(pomodoroControllerProvider.notifier).startFocus();
                                      if (context.mounted) unawaited(context.push(RoutePaths.focusSession));
                                    },
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Icon(PhosphorIconsFill.play, size: 16, color: colors.ember),
                                          const SizedBox(width: 10),
                                          Text(focusButtonLabel,
                                              style: AppTypography.label(
                                                  fontSize: AppTextSize.lg,
                                                  weight: FontWeight.w600,
                                                  color: colors.ember)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // SPEC.md §7.1: banner yalnızca Ekran 02 ve Ekran 06.
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 26),
          child: BannerAdSlot(bottomMargin: 88),
        ),
      ],
    );
  }
}

/// Haftalık hedef çubuğu. `BUGÜN` kartında iki `LinearProgressIndicator`
/// olabiliyor (günlük döngü + haftalık hedef); testler hangisine baktığını
/// bu anahtarla söylüyor.
const Key kWeeklyGoalProgressKey = Key('weekly-goal-progress');

/// Dönüş şeridi anahtarı — testler kartın hangi satırına baktığını bununla
/// söylüyor.
const Key kComebackRowKey = Key('comeback-row');

/// `BUGÜN` kartının dönüş satırı (ROADMAP madde 26).
///
/// Üç gün hiç odaklanmayan kullanıcı döndüğünde onu bir sıfır tablosu
/// karşılıyordu. Satır kaybedileni değil **korunanı** söylüyor: meşale kademesi
/// asla küçülmüyor ve kümülatif saat duruyor, yani seri kırılmış olsa bile
/// söylenecek doğru ve olumlu bir gerçek var.
///
/// Kapanışı da veriden geliyor: ilk odak tamamlandığı anda `absentDays`
/// sıfırlanır ve satır ağaçtan çıkar — "gösterildi mi" bayrağı, kapatma butonu,
/// yeni kalıcı alan yok.
class _ComebackRow extends StatelessWidget {
  const _ComebackRow({required this.cumulativeSeconds});

  /// Tüm zamanların tamamlanmış odak saniyesi (`FocusStats.cumulativeSeconds`).
  final int cumulativeSeconds;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Kademe ve süre bildirimle aynı kaynaktan: iki yüzey aynı anda farklı sayı
    // söyleyemez.
    final String tierName = flameTierFor(cumulativeSeconds).tier.name(l10n);
    final String spelled = spellFocusDuration(l10n, cumulativeSeconds);

    return Semantics(
      key: kComebackRowKey,
      container: true,
      excludeSemantics: true,
      label: l10n.countdownComebackSemantics(tierName, spelled),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            l10n.countdownComebackKicker,
            style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.countdownComebackBody(tierName, spelled),
            style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.ember),
          ),
        ],
      ),
    );
  }
}

/// `BUGÜN` kartının ikinci satırı: haftalık hedefin ilerlemesi
/// (ROADMAP madde 24).
///
/// Yeni bir kart açılmadı — Ekran 02 zaten 316px halka + kart + CTA ile dolu ve
/// ikinci bir kart birincil eylemi ekranın dışına iterdi. Hedefin haftası
/// Ekran 06'nın kartıyla ve pazar bildirimiyle aynı pencere
/// (`domain/stats/weekly_goal.dart`).
///
/// Aynı ilerleme ROADMAP madde 27'den beri geri sayım halkasının emek yayını da
/// besliyor; ikisi de bu sınıfın aldığı [WeeklyGoalProgress] örneğini okuyor.
class _WeeklyGoalRow extends StatelessWidget {
  const _WeeklyGoalRow({required this.progress});

  final WeeklyGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    // `mint` uygulamanın tamamlanma dili (döngü noktaları, `_CompletionRing`);
    // hedefe giderken `ember`.
    final Color tint = progress.isReached ? colors.mint : colors.ember;
    // Ekran okuyucu kısaltmayı değil sözü duyuyor: "4sa" harf harf okunurdu.
    final String spelledFocused = spellFocusDuration(l10n, progress.focusedSeconds);

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: progress.isReached
          ? l10n.countdownWeeklyGoalReachedSemantics(spelledFocused)
          : l10n.countdownWeeklyGoalSemantics(
              spelledFocused,
              spellFocusDuration(l10n, progress.goalSeconds),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                l10n.countdownWeeklyGoalLabel,
                style: AppTypography.kicker(
                    fontSize: AppTextSize.kicker, color: colors.neutral600),
              ),
              // 99 saati aşan hedef/ilerleme birleşimi satırı taşırabilir;
              // kicker sabit kalıp değer küçülüyor.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    progress.isReached
                        ? l10n.countdownWeeklyGoalReached
                        : l10n.countdownWeeklyGoalValue(
                            compactFocusDuration(l10n, progress.focusedSeconds),
                            compactFocusDuration(l10n, progress.goalSeconds),
                          ),
                    style: AppTypography.body(
                        fontSize: AppTextSize.sm, weight: FontWeight.w500, color: tint),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Oran yalnızca bir seans bitince değişiyor, yani tween boşta kare
          // üretmiyor — madde 18'in oran geçişi kalıbı, SPEC §6.4 ile uyumlu.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress.ratio),
            duration: AppMotion.respectingMotion(context, AppMotion.slow),
            curve: AppMotion.standard,
            builder: (BuildContext context, double value, Widget? child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 4,
                  child: LinearProgressIndicator(
                    key: kWeeklyGoalProgressKey,
                    value: value,
                    backgroundColor: colors.fillSubtle,
                    valueColor: AlwaysStoppedAnimation<Color>(tint),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
