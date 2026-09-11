import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/router/route_paths.dart';
import 'notification_service.dart';

/// Bildirime basılınca uygulamayı doğru ekrana götürür.
///
/// `WidgetLaunchScope`in ikizi; ayrı tutulmasının sebebi kaynakların farklı
/// olması: widget dokunuşu `Uri` + sorgu parametresi taşıyor (`?autostart=1`),
/// bildirim ise düz bir yol dizesi, ve soğuk başlangıç yolları ayrı API'ler
/// (`initiallyLaunchedFromHomeWidget` ↔ [NotificationService.launchPayload]).
///
/// Yalnızca **yükü olan** bildirimler bir yere gidiyor. Seans bitişi, mola ve
/// rozet bildirimleri yüksüz: onlara basmak uygulamayı açıyor ve kullanıcı
/// bıraktığı yerde kalıyor. Haftalık kapanış bir yere davet ettiği için
/// (Ekran 06'daki özet kartı) yük taşıyor.
class NotificationLaunchScope extends ConsumerStatefulWidget {
  const NotificationLaunchScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationLaunchScope> createState() => _NotificationLaunchScopeState();
}

class _NotificationLaunchScopeState extends ConsumerState<NotificationLaunchScope> {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    // İlk kareden sonra: soğuk başlangıçta yönlendirici ve Ekran 02 kurulmadan
    // gezinmek yığını bozardı (`WidgetLaunchScope` ile aynı gerekçe).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final NotificationService service = ref.read(notificationServiceProvider);
      _taps = service.tappedPayloads.listen(_handle);
      unawaited(service.launchPayload().then(_handle));
    });
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  void _handle(String? payload) {
    if (payload == null || !mounted) return;
    final GoRouter router = ref.read(appRouterProvider);
    switch (payload) {
      case RoutePaths.stats:
        // `go`: sekmeler geri sayımın tek kat üstünde duruyor
        // (`navigateToNavTab`in kuralı) ve bildirimden gelen giriş yığına
        // ikinci bir kat eklememeli.
        router.go(payload);
      default:
        // Tanımadığımız bir yük uygulamayı yanlış yere götürmemeli; eski bir
        // sürümden kalmış bekleyen bildirim geri sayıma düşer.
        router.go(RoutePaths.countdown);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
