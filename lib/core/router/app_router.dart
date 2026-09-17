import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/badges/badges_screen.dart';
import '../../features/countdown/countdown_screen.dart';
import '../../features/countdown/exam_expired_screen.dart';
import '../../features/exams/add_exam_screen.dart';
import '../../features/focus_session/focus_session_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';
import '../../domain/story_card/story_card_text.dart';
import '../../features/story_card/story_card_screen.dart';
import '../theme/app_motion.dart';
import 'route_paths.dart';

/// Alt çubuğun beş sekmesi arasındaki geçiş: giren ekran opaklıkla ve
/// 1.02 → 1.0 ölçekle gelir (fade-through). Çıkan ekranın ayrı bir çıkış
/// animasyonu yok — `push`/`pushReplacement`te alttaki rota olduğu yerde
/// duruyor ve giren opak ekran onun üstünü kapatıyor; ikisini birden
/// soldurmak alt çubuğun opak zeminini geçiş boyunca yarı saydam gösterirdi.
///
/// Yatay kaydırma bilinçli olarak yok: sekmelerin bir sırası olsa da
/// aralarında bir "yön" yok, hepsi aynı katta.
Page<void> _tabPage(BuildContext context, GoRouterState state, Widget child) {
  final Duration duration = AppMotion.respectingMotion(context, AppMotion.base);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    // `NoTransitionPage` yerine sıfır süre: "hareketi azalt" dalı ayrı bir
    // sayfa tipi açmıyor, animasyon ilk karede zaten 1.0'da olduğu için hedef
    // doğrudan son hâlinde çiziliyor. Kapı yine `AppMotion.respectingMotion`.
    transitionsBuilder: _fadeThroughTransition,
    child: child,
  );
}

/// Ekran 02'nin üstüne `push` edilen tam ekranlar (odak seansı, sınav ekleme):
/// aşağıdan yukarı kayma + opaklık. Sekme geçişinden ayrı bir dil, çünkü bunlar
/// kardeş değil — yığında bir kat yukarı çıkıyorlar.
Page<void> _pushedPage(BuildContext context, GoRouterState state, Widget child) {
  final Duration duration = AppMotion.respectingMotion(context, AppMotion.base);
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: _slideUpTransition,
    child: child,
  );
}

// Eğriler `CurveTween` zinciriyle uygulanıyor, `CurvedAnimation` ile değil:
// `CurvedAnimation` rota animasyonuna bir durum dinleyicisi ekliyor ve her
// karede yeniden çağrılan bir geçiş oluşturucusunda onu bırakacak yer yok.
Widget _fadeThroughTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: animation.drive(CurveTween(curve: AppMotion.enter)),
    child: ScaleTransition(
      scale: animation.drive(Tween<double>(begin: 1.02, end: 1).chain(CurveTween(curve: AppMotion.enter))),
      child: child,
    ),
  );
}

Widget _slideUpTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: animation.drive(CurveTween(curve: AppMotion.enter)),
    child: SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).chain(CurveTween(curve: AppMotion.enter)),
      ),
      child: child,
    ),
  );
}

/// Açılış anındaki `AppSettings.onboardingCompleted` değeri. `main.dart`
/// Riverpod ağacı kurulmadan önce okuyup geçersiz kılar
/// (`notificationServiceProvider` ile aynı DI kalıbı).
///
/// Bilinçli olarak **anlık görüntü**: bayrağı `appSettingsProvider` akışından
/// izlemek, onboarding bitişinde bayrak yazılır yazılmaz yönlendiricinin
/// yeniden kurulmasına ve o anki gezinme yığınının sıfırlanmasına yol açardı.
/// Bayrağın tek tüketicisi zaten [appRouterProvider]'ın başlangıç rotası.
final Provider<bool> onboardingCompletedAtLaunchProvider = Provider<bool>((Ref ref) {
  throw UnimplementedError('onboardingCompletedAtLaunchProvider main.dart içinde override edilmeli.');
});

/// Uygulamanın tek `GoRouter` örneği. İlk açılışta Ekran 01 (onboarding),
/// sonraki açılışlarda doğrudan Ekran 02 (geri sayım) — SPEC.md Ekran 01
/// "Bitişte `onboardingCompleted = true`".
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final bool onboardingCompleted = ref.watch(onboardingCompletedAtLaunchProvider);
  return GoRouter(
    initialLocation: onboardingCompleted ? RoutePaths.countdown : RoutePaths.onboarding,
    routes: <RouteBase>[
      GoRoute(
        path: RoutePaths.onboarding,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _tabPage(context, state, const OnboardingScreen()),
      ),
      GoRoute(
        path: RoutePaths.countdown,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return _tabPage(context, state, CountdownScreen(autoOpenSheet: state.extra as bool? ?? false));
        },
      ),
      // Ekran 08 bir sekme değil ama oraya da Ekran 02'nin **yerine** gidiliyor
      // (`context.go`); kaydırmalı bir üst kat değil, aynı kattaki bir değişim.
      GoRoute(
        path: RoutePaths.examExpired,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _tabPage(context, state, const ExamExpiredScreen()),
      ),
      GoRoute(
        path: RoutePaths.addExam,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _pushedPage(context, state, const AddExamScreen()),
      ),
      GoRoute(
        path: RoutePaths.focusSession,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _pushedPage(context, state, const FocusSessionScreen()),
      ),
      GoRoute(
        path: RoutePaths.badges,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _tabPage(context, state, const BadgesScreen()),
      ),
      // Ekran 05 madde 28'den beri bir sekme değil, kazanım anında üste binen
      // bir kat: geçişi de sekme dilinde değil `push` dilinde (aşağıdan yukarı),
      // Ekran 11 ve odak seansıyla aynı.
      GoRoute(
        path: RoutePaths.storyCard,
        pageBuilder: (BuildContext context, GoRouterState state) {
          // `extra` yalnızca seri eşiği kutlamasından gelen geçişte dolu (SERİ
          // şablonunu öneriyor); rozet dialogu bir şey vermiyor ve `as ...?`
          // onu `null`a düşürüyor — Ekran 02'nin `autoOpenSheet` bayrağıyla
          // aynı kalıp.
          return _pushedPage(
            context,
            state,
            StoryCardScreen(initialTemplate: state.extra as StoryCardTemplate?),
          );
        },
      ),
      GoRoute(
        path: RoutePaths.stats,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _tabPage(context, state, const StatsScreen()),
      ),
      GoRoute(
        path: RoutePaths.settings,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            _tabPage(context, state, const SettingsScreen()),
      ),
    ],
  );
});
