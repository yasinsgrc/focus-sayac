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
import '../../core/widgets/app_pressable.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/rise_in.dart';
import '../../domain/countdown/countdown_math.dart';
import '../../domain/exams/exam_providers.dart';
import '../../domain/pomodoro/pomodoro_stats_providers.dart';
import '../../domain/settings/settings_providers.dart';
import '../../domain/story_card/story_card_text.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/export/story_card_exporter.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';
import 'widgets/story_card_view.dart';

/// Ekran 05 — başarı kartı. Prototip v2 satır 214-245 birebir.
///
/// Madde 28'e kadar alt çubuğun bir sekmesiydi; artık **kazanım anına bağlı**
/// bir üst kat: Ekran 04'ün rozet dialogundan, rozet açılışı kutlamasından ve
/// seri eşiği kutlamasından açılıyor. Nadiren kullanılan bir dışa aktarma
/// aracının beş kalıcı yuvadan birini tutması, birincil eylemin (odak seansı)
/// yalnızca Ekran 02'den ulaşılabilir kalmasına mal oluyordu.
///
/// Sekme olmadığı için çubuğu da yok: üstüne binen her kat gibi sol üstte
/// kapatma düğmesiyle geldiği yere dönüyor (Ekran 11 ile aynı kalıp).
class StoryCardScreen extends ConsumerStatefulWidget {
  const StoryCardScreen({super.key, this.initialTemplate});

  /// Bu açılış için önerilen şablon; `null` ise kayıtlı tercih kullanılır.
  ///
  /// Seri eşiği kutlaması SERİ şablonunu öneriyor — "30 gün" diye kutlanıp
  /// bugünün saatini gösteren bir kart açmak tutarsız olurdu. Öneri
  /// `AppSettings.selectedTemplateIndex`e **yazılmıyor**: kullanıcının kendi
  /// seçimini tek bir kutlama yüzünden kalıcı değiştirmek, sessizce tercih
  /// ezmek olurdu.
  final StoryCardTemplate? initialTemplate;

  @override
  ConsumerState<StoryCardScreen> createState() => _StoryCardScreenState();
}

class _StoryCardScreenState extends ConsumerState<StoryCardScreen> {
  /// [StoryCardScreen.initialTemplate]'in yaşadığı yer. Kullanıcı seçiciye
  /// dokunduğu anda temizleniyor: o dokunuş kayıtlı tercihi yazıyor ve
  /// önerinin üstüne çıkması gerekiyor.
  StoryCardTemplate? _templateOverride;

  @override
  void initState() {
    super.initState();
    _templateOverride = widget.initialTemplate;
  }

  /// Dışa aktarımın tutamağı — `StoryCardExporter` bu anahtar üzerinden
  /// `RenderRepaintBoundary`ye ulaşıyor.
  final GlobalKey _cardKey = GlobalKey();

  /// Aynı anda ikinci bir yakalama başlatılmasın (iki aksiyon da kartı
  /// yeniden çiziyor).
  bool _busy = false;

  Future<void> _run(Future<StoryCardExportResult> Function(GlobalKey key) action, _Messages messages) async {
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
    showAppToast(
      context,
      message: message,
      tone: switch (result) {
        StoryCardExportResult.success => AppToastTone.success,
        StoryCardExportResult.permissionDenied => AppToastTone.info,
        StoryCardExportResult.failed => AppToastTone.error,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StoryCardExporter exporter = ref.watch(storyCardExporterProvider);

    final AppSettingsTableData? settings = ref.watch(appSettingsProvider).value;
    final StoryCardTemplate template =
        _templateOverride ?? StoryCardTemplate.fromIndex(settings?.selectedTemplateIndex ?? 0);

    final Exam? exam = ref.watch(activeExamProvider).value;
    final DateTime nowUtc = DateTime.now().toUtc();
    final StoryCardText text = buildStoryCardText(
      l10n: l10n,
      template: template,
      todayFocusSeconds: ref.watch(todayFocusStatsProvider).totalSeconds,
      streak: ref.watch(streakProvider),
      examName: exam?.name,
      examDateText: exam == null ? null : DateFormat('d MMMM y', 'tr').format(toIstanbulWallClock(exam.dateUtc)),
      daysRemaining: exam == null ? null : daysTo(exam.dateUtc, nowUtc),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          // Alt boşluk artık çubuğun payı kadar değil: çubuk bu ekranda yok,
          // "1080×1920" bilgisi Ekran 11'deki gibi 26px'lik kenarda duruyor.
          padding: const EdgeInsets.fromLTRB(26, 6, 26, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              RiseIn(
                child: Row(
                  children: <Widget>[
                    _CloseButton(colors: colors, label: l10n.commonClose),
                    const SizedBox(width: 14),
                    Text(
                      l10n.storyCardTitle,
                      style: AppTypography.display(fontSize: AppTextSize.titleLg, color: colors.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              RiseIn(
                delay: RiseIn.step,
                child: Center(
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
              ),
              const SizedBox(height: 18),
              RiseIn(
                delay: RiseIn.step * 2,
                child: _TemplatePicker(
                  selected: template,
                  onSelect: (StoryCardTemplate value) {
                    // Kullanıcı seçti: kutlamanın önerisi bitti, bundan
                    // sonra kayıtlı tercih geçerli.
                    setState(() => _templateOverride = null);
                    unawaited(
                      ref
                          .read(appSettingsDaoProvider)
                          .updateSettings(
                            AppSettingsTableCompanion(selectedTemplateIndex: Value<int>(value.index)),
                          ),
                    );
                  },
                ),
              ),
              const Spacer(),
              RiseIn(
                delay: RiseIn.step * 3,
                child: _ShareButton(
                  enabled: !_busy,
                  onPressed: () => _run(
                    // Paylaşım metni kartla aynı kaynaktan üretiliyor:
                    // şablon değişince metin de kendiliğinden değişiyor.
                    (GlobalKey key) => exporter.share(key, text: buildStoryCardShareText(l10n, text)),
                    _Messages(failed: l10n.storyCardShareFailed),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              RiseIn(
                delay: RiseIn.step * 4,
                child: _SecondaryButton(
                  icon: PhosphorIconsRegular.downloadSimple,
                  label: l10n.storyCardSave,
                  roleColor: colors.mint,
                  enabled: !_busy,
                  onPressed: () => _run(
                    exporter.saveToGallery,
                    _Messages(
                      success: l10n.storyCardSaved,
                      permissionDenied: l10n.storyCardSavePermissionDenied,
                      failed: l10n.storyCardSaveFailed,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RiseIn(
                delay: RiseIn.step * 5,
                child: Text(
                  l10n.storyCardExportSize,
                  textAlign: TextAlign.center,
                  style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ekranı kapatıp geldiği yere dönen düğme. Ölçüleri ve boyası Ekran 11'in
/// (sınav ekleme) kapatma düğmesiyle birebir aynı: ikisi de alt çubuğu olmayan,
/// üste binen bir kat ve farklı görünmeleri için bir sebep yok.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.colors, required this.label});

  final AppColors colors;

  /// Ekran okuyucunun okuduğu ad; düğmenin görünen bir metni yok.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: colors.fillMedium),
          ),
          child: Icon(PhosphorIconsRegular.x, size: 16, color: colors.neutral400),
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
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.fromBorderSide(BorderSide(color: colors.hairline)),
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
                              // Alt gezinme hapıyla aynı mantık: koyu temada
                              // dolu mor bir gradyan + açık yazı, açık temada
                              // seyreltik gradyan + koyu yazı.
                              colors: <Color>[
                                colors.brightness == Brightness.dark
                                    ? const Color(0xFF5D5294)
                                    : colors.accent400.withValues(alpha: 0.22),
                                colors.accent900,
                              ],
                            )
                          : null,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        template.label(AppLocalizations.of(context)),
                        style: AppTypography.label(
                          fontSize: AppTextSize.xs,
                          weight: FontWeight.w600,
                          color: template == selected
                              ? (colors.brightness == Brightness.dark ? const Color(0xFFF5F4FF) : colors.accent200)
                              : colors.neutral600,
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
    return AppPressable(
      enabled: enabled,
      child: SizedBox(
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
                      AppLocalizations.of(context).storyCardShare,
                      style: AppTypography.label(
                          fontSize: AppTextSize.lg, weight: FontWeight.w600, color: colors.accent200),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Prototip v2 satır 240 — "Kaydet".
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
    return AppPressable(
      enabled: enabled,
      child: SizedBox(
        height: 50,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colors.fillMedium),
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
                      style: AppTypography.label(
                          fontSize: AppTextSize.md, weight: FontWeight.w500, color: colors.neutral300),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
