import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/countdown/countdown_screen.dart';
import '../../features/countdown/exam_expired_screen.dart';
import '../../features/exams/add_exam_screen.dart';
import 'route_paths.dart';

/// Uygulamanın tek `GoRouter` örneği. Ekran 01 (onboarding, Faz 10) henüz
/// yok — başlangıç rotası doğrudan geri sayım (Ekran 02); onboarding
/// eklendiğinde `initialLocation` ona alınacak (Faz 10 kararı).
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: RoutePaths.countdown,
    routes: <RouteBase>[
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
    ],
  );
});
