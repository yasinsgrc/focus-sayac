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
import '../../features/story_card/story_card_screen.dart';
import 'route_paths.dart';

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
        builder: (BuildContext context, GoRouterState state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.countdown,
        builder: (BuildContext context, GoRouterState state) {
          return CountdownScreen(autoOpenSheet: state.extra as bool? ?? false);
        },
      ),
      GoRoute(
        path: RoutePaths.examExpired,
        builder: (BuildContext context, GoRouterState state) => const ExamExpiredScreen(),
      ),
      GoRoute(
        path: RoutePaths.addExam,
        builder: (BuildContext context, GoRouterState state) => const AddExamScreen(),
      ),
      GoRoute(
        path: RoutePaths.focusSession,
        builder: (BuildContext context, GoRouterState state) => const FocusSessionScreen(),
      ),
      GoRoute(
        path: RoutePaths.badges,
        builder: (BuildContext context, GoRouterState state) => const BadgesScreen(),
      ),
      GoRoute(
        path: RoutePaths.storyCard,
        builder: (BuildContext context, GoRouterState state) => const StoryCardScreen(),
      ),
      GoRoute(
        path: RoutePaths.stats,
        builder: (BuildContext context, GoRouterState state) => const StatsScreen(),
      ),
      GoRoute(
        path: RoutePaths.settings,
        builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
      ),
    ],
  );
});
