import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Geri bildirimin rolü — renk ve ikon buradan geliyor, çağıran taraf ham
/// `Color` seçmiyor.
enum AppToastTone {
  /// Kaydedildi / kopyalandı / sıfırlandı.
  success,

  /// İzin gerekiyor, kullanıcıdan bir adım bekleniyor.
  info,

  /// İşlem tamamlanamadı.
  error,
}

/// Aynı anda tek bir popup duruyor; ikinci bir mesaj gelirse öncekini
/// bekletmeden değiştiriyor (üst üste binmiş iki kart olmasın).
OverlayEntry? _current;

/// Alttan çıkan `SnackBar` yerine ekranın **ortasında** beliren, kendiliğinden
/// kapanan onay penceresi. Görsel dili ayar/rozet dialoglarıyla aynı:
/// `0xF51A1C2A` yüzey, ince kenarlık, 32 köşe. SPEC §6'ya uyması için runtime
/// blur yok — arka plan düz yarı saydam bir perde.
void showAppToast(
  BuildContext context, {
  required String message,
  AppToastTone tone = AppToastTone.success,
  Duration duration = const Duration(milliseconds: 1600),
}) {
  final OverlayState overlay = Overlay.of(context, rootOverlay: true);
  _current?.remove();
  _current = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => _AppToast(
      message: message,
      tone: tone,
      duration: duration,
      onDismissed: () {
        // Erken dokunuş ile zamanlayıcı yarışabilir; ikinci çağrı sessizce
        // düşüyor (kaldırılmış bir `OverlayEntry`yi kaldırmak assert atardı).
        if (_current != entry) return;
        entry.remove();
        _current = null;
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _AppToast extends StatefulWidget {
  const _AppToast({required this.message, required this.tone, required this.duration, required this.onDismissed});

  final String message;
  final AppToastTone tone;
  final Duration duration;
  final VoidCallback onDismissed;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  late final CurvedAnimation _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _holdTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _holdTimer?.cancel();
    if (!mounted) {
      widget.onDismissed();
      return;
    }
    _controller.reverse().whenComplete(widget.onDismissed);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final (IconData icon, Color tint) = switch (widget.tone) {
      AppToastTone.success => (PhosphorIconsDuotone.checkCircle, colors.mint),
      AppToastTone.info => (PhosphorIconsDuotone.info, colors.accent400),
      AppToastTone.error => (PhosphorIconsDuotone.warningCircle, colors.rose),
    };

    final Widget card = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
      decoration: BoxDecoration(
        color: colors.surfaceDialog,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 42, color: tint),
          const SizedBox(height: 14),
          Text(
            widget.message,
            textAlign: TextAlign.center,
            style: AppTypography.body(fontSize: 13.5, color: colors.text),
          ),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: GestureDetector(
        // Perdeye dokunuş popup'ı erken kapatıyor; süresini beklemek şart değil.
        onTap: _dismiss,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _curved,
          child: card,
          builder: (BuildContext context, Widget? child) {
            // "Hareketi azalt" açıkken kart doğrudan son hâlinde duruyor.
            final double t = MediaQuery.disableAnimationsOf(context) ? 1 : _curved.value;
            return ColoredBox(
              // Perde tokenı zaten kendi opaklığını taşıyor (koyuda %68,
              // açıkta %40); `t` onu 0'dan o değere kadar açıyor.
              color: colors.scrim.withValues(alpha: colors.scrim.a * t),
              child: Center(
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
