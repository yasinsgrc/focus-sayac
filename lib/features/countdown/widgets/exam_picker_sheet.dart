import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons/app_icons.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../services/storage/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../domain/countdown/countdown_math.dart';
import '../../../domain/exams/exam_accent.dart';
import '../../../domain/exams/exam_providers.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../services/storage/app_database.dart';

/// Ekran 02'nin "SINAV SEÇ" alt sayfası — prototip satır 116-133 birebir.
Future<void> showExamPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) => const _ExamPickerSheet(),
  );
}

class _ExamPickerSheet extends ConsumerWidget {
  const _ExamPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<List<Exam>> examsAsync = ref.watch(allExamsProvider);

    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(26, 18, 26, 30),
        decoration: BoxDecoration(
          color: colors.surfaceSheet,
          border: Border(top: BorderSide(color: colors.borderSubtle)),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colors.fillStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(l10n.examPickerTitle,
                    style: AppTypography.display(fontSize: AppTextSize.titleLg, color: colors.text)),
                Text(
                  l10n.examPickerVerifyOfficial,
                  style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            examsAsync.when(
              data: (List<Exam> exams) => _ExamList(exams: exams, colors: colors),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object error, StackTrace stackTrace) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.fillStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push(RoutePaths.addExam);
                },
                icon: Icon(Icons.add, size: 15, color: colors.neutral300),
                label: Text(
                  l10n.examPickerAddOwn,
                  style: AppTypography.label(
                      fontSize: AppTextSize.lg, weight: FontWeight.w500, color: colors.neutral300),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamList extends ConsumerWidget {
  const _ExamList({required this.exams, required this.colors});

  final List<Exam> exams;
  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime nowUtc = DateTime.now().toUtc();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.divider,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < exams.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: colors.divider),
            _ExamRow(
              exam: exams[i],
              colors: colors,
              days: daysTo(exams[i].dateUtc, nowUtc),
              onTap: () async {
                await ref.read(activeExamSwitcherProvider).switchTo(exams[i].id);
                if (context.mounted) Navigator.of(context).pop();
              },
              // H4: yalnızca kullanıcı sınavı düzenlenip silinebilir.
              onLongPress: exams[i].isPreset ? null : () => _showExamActions(context, ref, exams[i]),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ExamAction { edit, delete }

Future<void> _showExamActions(BuildContext pickerContext, WidgetRef ref, Exam exam) async {
  final AppColors colors = Theme.of(pickerContext).extension<AppColors>()!;
  final AppLocalizations l10n = AppLocalizations.of(pickerContext);
  final _ExamAction? action = await showModalBottomSheet<_ExamAction>(
    context: pickerContext,
    backgroundColor: colors.surfaceSheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
    ),
    builder: (BuildContext context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.edit_outlined, color: colors.neutral300),
              title: Text(l10n.examActionEdit,
                  style: AppTypography.label(fontSize: AppTextSize.lg, color: colors.text)),
              onTap: () => Navigator.of(context).pop(_ExamAction.edit),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: colors.rose),
              title: Text(l10n.examActionDelete,
                  style: AppTypography.label(fontSize: AppTextSize.lg, color: colors.rose)),
              onTap: () => Navigator.of(context).pop(_ExamAction.delete),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !pickerContext.mounted) return;

  switch (action) {
    case _ExamAction.edit:
      Navigator.of(pickerContext).pop();
      unawaited(pickerContext.push(RoutePaths.addExam, extra: exam));
    case _ExamAction.delete:
      final bool? confirmed = await showDialog<bool>(
        context: pickerContext,
        builder: (BuildContext context) => _DeleteExamDialog(examName: exam.name),
      );
      if (confirmed != true) return;
      try {
        // `AppSettings.activeExamId` sınava FK ile bağlı: önce seçim kalkmalı.
        if (exam.isActive) await ref.read(activeExamSwitcherProvider).clearActive();
        await ref.read(examDaoProvider).deleteUserExam(exam.id);
        if (pickerContext.mounted) showAppToast(pickerContext, message: l10n.deleteExamDone);
      } on Object {
        if (pickerContext.mounted) {
          showAppToast(pickerContext, message: l10n.deleteExamError, tone: AppToastTone.error);
        }
      }
  }
}

/// Ayarlar'daki sıfırlama onayıyla aynı dil: rose kenarlık, önce güvenli seçenek.
class _DeleteExamDialog extends StatelessWidget {
  const _DeleteExamDialog({required this.examName});

  final String examName;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: colors.surfaceDialog,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: BorderSide(color: colors.rose.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(AppIconsDuotone.trash, size: 46, color: colors.rose),
            const SizedBox(height: 18),
            Text(
              l10n.deleteExamDialogTitle,
              style: AppTypography.display(
                  fontSize: AppTextSize.heading, weight: FontWeight.w700, color: colors.text),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.deleteExamDialogBody(examName),
              textAlign: TextAlign.center,
              style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral400),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.mint),
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[colors.mintDeep, colors.mintDeep.withValues(alpha: 0)],
                  ),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(false),
                    child: Center(
                      child: Text(
                        l10n.settingsResetDialogCancel,
                        style: AppTypography.label(
                            fontSize: AppTextSize.md, weight: FontWeight.w600, color: colors.mint),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.rose.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(true),
                    child: Center(
                      child: Text(
                        l10n.deleteExamDialogConfirm,
                        style: AppTypography.label(
                            fontSize: AppTextSize.md, weight: FontWeight.w500, color: colors.rose),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({
    required this.exam,
    required this.colors,
    required this.days,
    required this.onTap,
    this.onLongPress,
  });

  final Exam exam;
  final AppColors colors;
  final int days;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color tint = examAccentColor(exam.accentRole, colors);
    // Satırın kendisi bir buton: ölçek `Container`ın **dışında**, yoksa
    // seçili satırın zemin rengi de küçülüp kenarında boşluk bırakırdı.
    return AppPressable(
      // Satır geniş ve alçak; 0.97 burada ekranın yarısı kadar bir yüzeyi
      // gözle görülür şekilde kaydırırdı, dokunuşu 0.99 zaten söylüyor.
      scale: 0.99,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          color: exam.isActive ? examAccentDeepColor(exam.accentRole, colors).withValues(alpha: 0.35) : Colors.transparent,
          child: Row(
            children: <Widget>[
              Icon(examAccentIcon(), size: 23, color: tint),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(exam.name,
                        style: AppTypography.label(
                            fontSize: AppTextSize.lg, weight: FontWeight.w500, color: colors.text)),
                    if (exam.subtitle != null && exam.subtitle!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(exam.subtitle!,
                          style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.neutral500)),
                    ],
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '$days',
                      style: AppTypography.display(fontSize: AppTextSize.title, color: tint).copyWith(
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: AppLocalizations.of(context).examPickerDaysSuffix,
                      style: AppTypography.label(
                          fontSize: AppTextSize.xs,
                          weight: FontWeight.w600,
                          color: tint.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
