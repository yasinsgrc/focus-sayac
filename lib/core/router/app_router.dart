import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Uygulamanın tek `GoRouter` örneği. Ekranlar hazırlandıkça (Faz 4+) buraya
/// `GoRoute` girişleri eklenir; bu fazda yalnızca geçici bir başlangıç ekranı var.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) => const _BootstrapPlaceholder(),
      ),
    ],
  );
});

/// Faz 2 bitene kadar geçici kök ekran; Faz 4+'ta gerçek onboarding/geri sayım
/// rotalarıyla değiştirilecek. Prototipte karşılığı yok — yalnızca iskelet.
class _BootstrapPlaceholder extends StatelessWidget {
  const _BootstrapPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: Text(
          'FocusSayaç',
          style: AppTypography.display(fontSize: 32, color: colors.text),
        ),
      ),
    );
  }
}
