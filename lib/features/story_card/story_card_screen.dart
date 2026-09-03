import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/time/app_day.dart';
import '../../domain/countdown/countdown_math.dart';
import '../../domain/exams/exam_providers.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import '../../domain/settings/settings_providers.dart';
import '../../domain/story_card/story_card_text.dart';
import '../../services/export/story_card_exporter.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';
import 'widgets/story_card_view.dart';

/// Ekran 05 — başarı kartı. Prototip v2 satır 214-245 birebir. Bu ekranda alt
/// gezinme çubuğu yok (prototipte de yok); Ekran 04'ün rozet dialogundaki
/// "BAŞARI KARTINI OLUŞTUR" düğmesinden açılıyor.
class StoryCardScreen extends ConsumerStatefulWidget {
  const StoryCardScreen({super.key});

  @override
  ConsumerState<StoryCardScreen> createState() => _StoryCardScreenState();
}

class _StoryCardScreenState extends ConsumerState<StoryCardScreen> {
  /// Dışa aktarımın tutamağı — `StoryCardExporter` bu anahtar üzerinden
  /// `RenderRepaintBoundary`ye ulaşıyor.
  final GlobalKey _cardKey = GlobalKey();

  /// Aynı anda ikinci bir yakalama başlatılmasın (üç aksiyon da kartı
  /// yeniden çiziyor).
  bool _busy = false;

  Future<void> _run(
    Future<StoryCardExportResult> Function(GlobalKey key) action,
    _Messages messages,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final StoryCardExportResult result = await action(_cardKey);
    if (!mounted) return;
    setState(() => _busy = false);

    final String? message = switch (result) {
      StoryCardExportResult.success => messages.success,
      StoryCardExportResult.permissionDenied => messages.permissionDenied,
      StoryCardExportResult.failed => messages.failed,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: AppTypography.body(fontSize: 13))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final StoryCardExporter exporter = ref.watch(storyCardExporterProvider);

    final AppSettingsTableData? settings = ref.watch(appSettingsProvider).value;
    final StoryCardTemplate template =
        StoryCardTemplate.fromIndex(settings?.selectedTemplateIndex ?? 0);

    final Exam? exam = ref.watch(activeExamProvider).value;
    final DateTime nowUtc = DateTime.now().toUtc();
    final StoryCardText text = buildStoryCardText(
      template: template,
      todayFocusSeconds: ref.watch(todayFocusStatsProvider).totalSeconds,
      streak: ref.watch(streakProvider),
      examName: exam?.name,
      examDateText: exam == null
          ? null
          : DateFormat('d MMMM y', 'tr').format(toIstanbulWallClock(exam.dateUtc)),
      daysRemaining: exam == null ? null : daysTo(exam.dateUtc, nowUtc),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 6, 26, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  InkWell(
                    onTap: () => context.pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x1FFFFFFF)),
                      ),
                      child: Icon(PhosphorIconsRegular.arrowLeft, size: 17, color: colors.neutral400),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'BAŞARI KARTI',
                    style: AppTypography.display(fontSize: 19, weight: FontWeight.w600, color: colors.text),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  width: kStoryCardPreviewWidth,
                  height: kStoryCardPreviewWidth * kStoryCardHeight / kStoryCardWidth,
                  // Kart her zaman 270×480 mantıksal boyutta çiziliyor;
                  // önizleme onu prototipin 248px'ine küçültüyor. Dışa aktarım
                  // `RepaintBoundary`nin kendi katmanından alındığı için bu
                  // ölçekten etkilenmiyor — PNG yine tam 1080×1920.
                  child: FittedBox(
                    child: StoryCardView(template: template, text: text, boundaryKey: _cardKey),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _TemplatePicker(
                selected: template,
                onSelect: (StoryCardTemplate value) {
                  unawaited(
                    ref.read(appSettingsDaoProvider).updateSettings(
                          AppSettingsTableCompanion(selectedTemplateIndex: Value<int>(value.index)),
                        ),
                  );
                },
              ),
              const Spacer(),
              _ShareButton(
                enabled: !_busy,
                onPressed: () => _run(
                  exporter.share,
                  const _Messages(failed: 'Kart paylaşılamadı.'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SecondaryButton(
                      icon: PhosphorIconsRegular.downloadSimple,
                      label: 'Kaydet',
                      roleColor: colors.mint,
                      enabled: !_busy,
                      onPressed: () => _run(
                        exporter.saveToGallery,
                        const _Messages(
                          success: 'Kart galeriye kaydedildi.',
                          permissionDenied: 'Galeriye kaydetmek için izin gerekiyor.',
                          failed: 'Kart kaydedilemedi.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecondaryButton(
                      icon: PhosphorIconsRegular.copy,
                      label: 'Kopyala',
                      roleColor: colors.sky,
                      enabled: !_busy,
                      onPressed: () => _run(
                        exporter.copyToClipboard,
                        const _Messages(
                          success: 'Kart panoya kopyalandı.',
                          failed: 'Kart kopyalanamadı.',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '1080 × 1920 PNG',
                textAlign: TextAlign.center,
                style: AppTypography.kicker(fontSize: 8.5, color: colors.neutral700, letterSpacingEm: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aksiyon başına kullanıcıya gösterilecek metinler. `null` olan durum mesaj
/// göstermiyor — paylaşımın başarısı zaten sistem sayfasıyla belli oluyor.
class _Messages {
  const _Messages({this.success, this.permissionDenied, this.failed});

  final String? success;
  final String? permissionDenied;
  final String? failed;
}

/// Prototip v2 satır 232-236: üç şablon düğmesi, üçü de v1'de ücretsiz.
class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.selected, required this.onSelect});

  final StoryCardTemplate selected;
  final ValueChanged<StoryCardTemplate> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xCC1E2030),
        borderRadius: BorderRadius.circular(18),
        border: const Border.fromBorderSide(BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Row(
        children: <Widget>[
          for (final StoryCardTemplate template in StoryCardTemplate.values) ...<Widget>[
            if (template != StoryCardTemplate.values.first) const SizedBox(width: 6),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelect(template),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: template == selected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[const Color(0xFF5D5294), colors.accent900],
                            )
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        template.label,
                        style: AppTypography.display(
                          fontSize: 11,
                          weight: FontWeight.w600,
                          color: template == selected ? const Color(0xFFF5F4FF) : colors.neutral600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Prototip v2 satır 238 — `accent-300` kenarlıklı ana aksiyon.
class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.accent300),
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[colors.accent900, colors.accent900.withValues(alpha: 0)],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(PhosphorIconsRegular.shareNetwork, size: 19, color: colors.accent200),
                  const SizedBox(width: 10),
                  Text(
                    'PAYLAŞ',
                    style: AppTypography.display(fontSize: 15, weight: FontWeight.w600, color: colors.accent200),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Prototip v2 satır 240-241 — "Kaydet" / "Kopyala".
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.roleColor,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;

  /// Prototipin `style-hover` rengi — dokunmatikte hover yok, ikonun rengi
  /// olarak kullanılıyor (aksiyonun rolünü yine de ayırt ettiriyor).
  final Color roleColor;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x1FFFFFFF)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 17, color: roleColor),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: AppTypography.display(fontSize: 13, weight: FontWeight.w500, color: colors.neutral300),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
