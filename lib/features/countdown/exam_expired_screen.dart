import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/time/app_day.dart';
import '../../domain/exams/exam_providers.dart';
import '../../services/storage/app_database.dart';

/// Ekran 08 — sınav tarihi geçti. Prototip satır 319-333 birebir. "Odak
/// geçmişin ve rozetlerin korunur." metni SPEC.md gereği doğru olmak
/// zorunda — bu ekran yalnızca `Exam.isActive` bayrağını değiştirir,
/// hiçbir `PomodoroSession`/`UserBadge` satırı silinmez.
class ExamExpiredScreen extends ConsumerWidget {
  const ExamExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final Exam? exam = ref.watch(activeExamProvider).value;
    final String subtitle = exam == null
        ? ''
        : '${toIstanbulWallClock(exam.dateUtc).year} ${exam.name} geride kaldı. Yeni bir hedef seç, sayaç oradan devam etsin.';

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: <Widget>[
          Positioned(
            bottom: -140,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 520,
                height: 420,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[Color(0x2EFF6A86), Colors.transparent],
                    stops: <double>[0, 0.64],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(34),
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
                      child: Icon(PhosphorIconsDuotone.calendarX, size: 46, color: colors.neutral600),
                    ),
                    const SizedBox(height: 26),
                    Text('SINAVIN GEÇTİ', style: AppTypography.display(fontSize: 28, weight: FontWeight.w700, color: colors.text)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 262,
                      child: Text(
                        subtitle,
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
                          side: BorderSide(color: colors.accent300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          backgroundColor: colors.accent900.withValues(alpha: 0.4),
                        ),
                        // Sınav seçimi geri sayıma dönmeden önce burada
                        // düşürülüyor: alt sayfa kapatılırsa (kullanıcı
                        // hiçbir sınav seçmezse) geri sayım ekranı hâlâ
                        // `isActive` olan geçmiş tarihli sınavla açılıyor ve
                        // "0 GÜN KALDI" gösteren bir sayaçta takılı
                        // kalıyordu — `CountdownScreen`in süre kontrolü
                        // yalnızca `activeExamProvider` yeni bir değer
                        // yayınladığında çalıştığı için orada yeniden
                        // tetiklenmiyor. Bayrak düşünce ekran "HEDEF
                        // SEÇİLMEDİ" boş durumuna düşer, "SINAV SEÇ" çıkışı
                        // her koşulda elde kalır.
                        onPressed: () async {
                          await ref.read(activeExamSwitcherProvider).clearActive();
                          if (context.mounted) context.go(RoutePaths.countdown, extra: true);
                        },
                        child: Text(
                          'YENİ SINAV SEÇ',
                          style: AppTypography.display(fontSize: 14.5, weight: FontWeight.w600, color: colors.accent200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Odak geçmişin ve rozetlerin korunur.',
                      style: AppTypography.body(fontSize: 12.5, color: colors.neutral600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
