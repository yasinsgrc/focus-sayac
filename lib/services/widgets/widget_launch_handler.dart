import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/router/app_router.dart';
import '../../core/router/route_paths.dart';
import '../../domain/exams/exam_picker_request.dart';
import '../../domain/pomodoro/pomodoro_controller.dart';
import '../../domain/pomodoro/pomodoro_phase.dart';

/// Ana ekran widgetlarindan gelen dokunuslari uygulama rotalarina cevirir.
///
/// Kotlin tarafi `focussayac://widget/<yol>` bicimli bir Uri gonderiyor
/// (`android/.../widget/WidgetRoutes.kt`); yollar `RoutePaths` ile birebir
/// ayni oldugu icin cevirim duz bir eslemedir.
class WidgetLaunchScope extends ConsumerStatefulWidget {
  const WidgetLaunchScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<WidgetLaunchScope> createState() => _WidgetLaunchScopeState();
}

class _WidgetLaunchScopeState extends ConsumerState<WidgetLaunchScope> {
  StreamSubscription<Uri?>? _clicks;

  @override
  void initState() {
    super.initState();
    // Ilk kareden sonra baglaniyor: soguk baslangicta yonlendirici ve
    // Ekran 02 kurulmadan once gezinmek, yigini bozardi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _clicks = HomeWidget.widgetClicked.listen(_handle);
      unawaited(HomeWidget.initiallyLaunchedFromHomeWidget().then(_handle));
    });
  }

  @override
  void dispose() {
    unawaited(_clicks?.cancel());
    super.dispose();
  }

  Future<void> _handle(Uri? uri) async {
    if (uri == null || !mounted) return;
    final GoRouter router = ref.read(appRouterProvider);
    final String path = uri.path;

    switch (path) {
      case RoutePaths.focusSession:
        await _openFocusSession(router, autostart: uri.queryParameters['autostart'] == '1');
      case RoutePaths.countdown:
        router.go(RoutePaths.countdown);
        // `extra` yeterli degil: uygulama zaten Ekran 02'deyse ayni konuma
        // gitmek State'i yeniden kurmuyor ve parametre okunmuyor.
        if (uri.queryParameters['pick'] == '1') {
          ref.read(examPickerRequestProvider.notifier).request();
        }
      case RoutePaths.stats:
      case RoutePaths.examExpired:
        router.go(path);
      default:
        // Tanimadigimiz bir yol uygulamayi yanlis yere goturmemeli; eski bir
        // widget surumunden gelen dokunus geri sayima duser.
        router.go(RoutePaths.countdown);
    }
  }

  /// Hizli Odak widgetinin yolu. Seans yalnizca faz bosken baslatilir:
  /// suren bir seansi widget uzerinden sessizce sifirlamak, kullanicinin
  /// biriken odagini silmek olurdu.
  Future<void> _openFocusSession(GoRouter router, {required bool autostart}) async {
    if (autostart && ref.read(pomodoroControllerProvider) is PomodoroIdle) {
      await ref.read(pomodoroControllerProvider.notifier).startFocus();
    }
    if (!mounted) return;

    // Once yigin geri sayima sabitleniyor ki seans bitisindeki `pop()` bos
    // bir yigina dusmesin (Ekran 03 kapanista pop ediyor).
    router.go(RoutePaths.countdown);
    if (_currentPath(router) == RoutePaths.focusSession) return;
    unawaited(router.push(RoutePaths.focusSession));
  }

  /// Ekran 02 aktif seans kurtarildiginda odak ekranini kendisi push ediyor
  /// (`_redirectIfSessionRecovered`). Ayni kareye iki push dusmesin diye
  /// mevcut konum kontrol ediliyor.
  String _currentPath(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  @override
  Widget build(BuildContext context) => widget.child;
}
