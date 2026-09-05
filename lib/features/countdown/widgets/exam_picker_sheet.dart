import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
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
                Text(l10n.examPickerTitle, style: AppTypography.display(fontSize: 21, weight: FontWeight.w600, color: colors.text)),
                Text(
                  l10n.examPickerVerifyOfficial,
                  style: AppTypography.kicker(fontSize: 8.5, color: colors.neutral600),
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
                  style: AppTypography.display(fontSize: 14, weight: FontWeight.w500, color: colors.neutral300),
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
            ),
          ],
        ],
      ),
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam, required this.colors, required this.days, required this.onTap});

  final Exam exam;
  final AppColors colors;
  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tint = examAccentColor(exam.accentRole, colors);
    return InkWell(
      onTap: onTap,
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
                  Text(exam.name, style: AppTypography.display(fontSize: 15, weight: FontWeight.w500, color: colors.text)),
                  if (exam.subtitle != null && exam.subtitle!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(exam.subtitle!, style: AppTypography.body(fontSize: 12, color: colors.neutral500)),
                  ],
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$days',
                    style: AppTypography.display(fontSize: 17, weight: FontWeight.w700, color: tint).copyWith(
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: AppLocalizations.of(context).examPickerDaysSuffix,
                    style: AppTypography.display(fontSize: 11, weight: FontWeight.w700, color: tint.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
