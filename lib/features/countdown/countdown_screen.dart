import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/time/app_day.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../domain/countdown/countdown_math.dart';
import '../../domain/exams/exam_providers.dart';
import '../../domain/pomodoro/pomodoro_controller.dart';
import '../../domain/pomodoro/pomodoro_phase.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import '../../domain/settings/settings_providers.dart';
import '../../domain/time/duration_formatter.dart';
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
    _secondTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _nowUtc = DateTime.now().toUtc());
    });
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
  void dispose() {
    _dashController.dispose();
    _secondTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AsyncValue<Exam?> activeExamAsync = ref.watch(activeExamProvider);

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
          Positioned(
            top: 60,
            left: -90,
            child: IgnorePointer(
              child: Container(
                width: 580,
                height: 520,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[Color(0x579184D9), Colors.transparent],
                    stops: <double>[0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: activeExamAsync.when(
              data: (Exam? exam) {
                if (exam == null) return const _NoExamBody();
                return _CountdownBody(exam: exam, nowUtc: _nowUtc, dashController: _dashController);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stackTrace) => const _NoExamBody(
                title: 'SINAV YÜKLENEMEDİ',
                message: 'Kayıtlı sınavlar okunamadı. Listeden yeniden seçmeyi deneyebilirsin.',
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 18,
            child: BottomNavBar(
              active: AppNavTab.countdown,
              // Prototipin alt çubuğunda "flame" (seri) için ayrı bir ekran
              // yok — ikisi de rozetler ekranına gider (Faz 4 DECISIONS.md).
              // İstatistik sekmesi Ekran 06 (Faz 9) gelene kadar no-op.
              onSelect: (AppNavTab tab) {
                if (tab == AppNavTab.badges) context.push(RoutePaths.badges);
                if (tab == AppNavTab.settings) context.push(RoutePaths.settings);
              },
            ),
          ),
        ],
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
  const _NoExamBody({
    this.title = 'HEDEF SEÇİLMEDİ',
    this.message = 'Geri sayımın başlaması için bir sınav seç ya da kendi hedefini ekle.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;

    return Padding(
      // Alt boşluk gezinme çubuğunu (64px + 18px kenar boşluğu) açıkta bırakır.
      padding: const EdgeInsets.fromLTRB(34, 0, 34, 100),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x24FFFFFF)),
              ),
              child: Icon(PhosphorIconsDuotone.calendarBlank, size: 46, color: colors.neutral600),
            ),
            const SizedBox(height: 26),
            Text(title, style: AppTypography.display(fontSize: 26, weight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 12),
            SizedBox(
              width: 262,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body(fontSize: 14, color: colors.neutral500),
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
                  'SINAV SEÇ',
                  style: AppTypography.display(fontSize: 14.5, weight: FontWeight.w600, color: colors.ember),
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
    final int days = daysTo(exam.dateUtc, nowUtc);
    final double ratio = progressRatio(days);
    final Duration remaining = remainingDuration(exam.dateUtc, nowUtc);
    final Duration remainder = remaining - Duration(days: remaining.inDays);
    final String hh = remainder.inHours.toString().padLeft(2, '0');
    final String mm = (remainder.inMinutes % 60).toString().padLeft(2, '0');
    final String ss = (remainder.inSeconds % 60).toString().padLeft(2, '0');
    final DateFormat examDateFormat = DateFormat('d MMMM y', 'tr');
    final String examDateText = examDateFormat.format(toIstanbulWallClock(exam.dateUtc));

    final TodayFocusStats todayStats = ref.watch(todayFocusStatsProvider);
    final int streak = ref.watch(streakProvider);
    final FocusDurationParts todayParts = formatFocusDuration(todayStats.totalSeconds);
    final int cycleDots = todayStats.completedCount.clamp(0, 4);

    // Süre `AppSettings.focusMinutes`ten gelir (`startFocus()` de aynı ayarı
    // okur); ayar akışı ilk değerini yayınlamadan önceki tek karede sayı
    // yerine yalnızca eylem gösteriliyor — sabit bir "25" yazmak, ayar
    // değiştirildiğinde butonun yanlış süre vaat etmesi demekti.
    final int? focusMinutes = ref.watch(focusMinutesProvider);
    final String focusButtonLabel =
        focusMinutes == null ? 'ODAKLAN' : '$focusMinutes DAKİKA ODAKLAN';

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              GestureDetector(
                onTap: () => showExamPickerSheet(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('HEDEF', style: AppTypography.kicker(fontSize: 9, color: colors.neutral600)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          exam.name,
                          style: AppTypography.display(fontSize: 22, weight: FontWeight.w600, color: colors.text),
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
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                  ),
                  child: Icon(PhosphorIconsRegular.plus, size: 18, color: colors.neutral400),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 316,
              height: 316,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: dashController,
                      builder: (BuildContext context, Widget? child) {
                        return CustomPaint(
                          size: const Size(316, 316),
                          painter: CountdownRingPainter(
                            progressRatio: ratio,
                            dashRotation: dashController.value * 2 * math.pi,
                          ),
                        );
                      },
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ShaderMask(
                        shaderCallback: (Rect bounds) => const LinearGradient(
                          colors: AppColors.chromeGradient,
                          stops: AppColors.chromeGradientStops,
                        ).createShader(bounds),
                        child: Text(
                          '$days',
                          style: AppTypography.counter(fontSize: 100, weight: FontWeight.w700, color: Colors.white, height: 1),
                        ),
                      ),
                      Text('GÜN KALDI', style: AppTypography.kicker(fontSize: 9.5, color: colors.neutral500)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '$hh:$mm:$ss',
                            style: AppTypography.body(fontSize: 12.5, weight: FontWeight.w500, color: colors.neutral400).copyWith(
                              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 9),
                          Container(width: 3, height: 3, decoration: BoxDecoration(color: colors.ember, shape: BoxShape.circle)),
                          const SizedBox(width: 9),
                          Text(examDateText, style: AppTypography.body(fontSize: 12.5, weight: FontWeight.w500, color: colors.neutral400)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xB81E2030),
              borderRadius: BorderRadius.circular(24),
              border: const Border.fromBorderSide(BorderSide(color: Color(0x12FFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('BUGÜN', style: AppTypography.kicker(fontSize: 9, color: colors.neutral600)),
                    if (streak > 0)
                      Container(
                        height: 25,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(color: colors.emberDeep, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(PhosphorIconsFill.flame, size: 13, color: colors.ember),
                            const SizedBox(width: 5),
                            Text('$streak gün seri', style: AppTypography.body(fontSize: 11.5, weight: FontWeight.w500, color: colors.ember)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    RichText(
                      text: TextSpan(
                        children: <InlineSpan>[
                          TextSpan(
                            text: '${todayParts.hours}',
                            style: AppTypography.counter(fontSize: 38, color: colors.text, height: 1),
                          ),
                          TextSpan(text: ' SA ', style: AppTypography.display(fontSize: 17, color: colors.neutral500)),
                          TextSpan(
                            text: '${todayParts.minutes}',
                            style: AppTypography.counter(fontSize: 38, color: colors.text, height: 1),
                          ),
                          TextSpan(text: ' DK', style: AppTypography.display(fontSize: 17, color: colors.neutral500)),
                        ],
                      ),
                    ),
                    const Spacer(),
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
                                color: i < cycleDots ? colors.mint : const Color(0x1FFFFFFF),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: cycleDots / 4,
                      backgroundColor: const Color(0x17FFFFFF),
                      valueColor: AlwaysStoppedAnimation<Color>(colors.mint),
                    ),
                  ),
                ),
                if (todayStats.completedCount == 0) ...<Widget>[
                  const SizedBox(height: 9),
                  Text.rich(
                    TextSpan(
                      style: AppTypography.body(fontSize: 12, color: colors.neutral500),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Hedefe 1 pomodoro kaldı — serin '),
                        TextSpan(text: '${streak + 1}\'e', style: TextStyle(color: colors.ember)),
                        const TextSpan(text: ' çıkar.'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
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
                        Text(focusButtonLabel, style: AppTypography.display(fontSize: 15.5, weight: FontWeight.w600, color: colors.ember)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 50,
            margin: const EdgeInsets.only(bottom: 88),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Center(
              child: Text('BANNER 320×50', style: AppTypography.kicker(fontSize: 8.5, color: colors.neutral700)),
            ),
          ),
        ],
      ),
    );
  }
}
