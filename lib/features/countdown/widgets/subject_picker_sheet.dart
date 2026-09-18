import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../domain/subjects/subject_catalog.dart';
import '../../../domain/subjects/subject_providers.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Alt sayfadaki bir dersin hap düğmesi — testler seçimi bununla buluyor.
Key subjectChipKey(String subjectKey) => ValueKey<String>('subject-chip-$subjectKey');

/// "Ders belirtme" çıkışı.
const Key kSubjectClearKey = Key('subject-clear');

/// Ekran 02'nin ders alt sayfası (ROADMAP madde 30). `exam_picker_sheet.dart`
/// ile aynı kabuk: tutamak, başlık, seçim yüzeyi, en altta ikincil çıkış.
///
/// Sınav listesinden farkı seçim yüzeyi: ders adları kısa ve sayıları sınava
/// göre 2 ile 11 arasında değişiyor. Satır listesi YKS'de kaydırma
/// gerektirirdi; haplar tek ekranda duruyor ve seçili olan tek bakışta
/// görünüyor.
Future<void> showSubjectPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext context) => const _SubjectPickerSheet(),
  );
}

class _SubjectPickerSheet extends ConsumerWidget {
  const _SubjectPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> catalog = ref.watch(subjectCatalogProvider);
    final String? active = ref.watch(activeSubjectProvider);

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
                Text(l10n.subjectPickerTitle,
                    style: AppTypography.display(fontSize: AppTextSize.titleLg, color: colors.text)),
                // Esnek: kicker'ın harf aralığı büyük sistem yazı tipinde
                // başlıkla birlikte 338px'lik alt sayfayı taşırıyordu.
                Flexible(
                  child: Text(
                    l10n.subjectPickerHint,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String key in catalog)
                  _SubjectChip(
                    subjectKey: key,
                    selected: key == active,
                    colors: colors,
                    onTap: () async {
                      await ref.read(subjectSelectorProvider)(key);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                key: kSubjectClearKey,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.fillStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () async {
                  await ref.read(subjectSelectorProvider)(null);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  l10n.subjectPickerClear,
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

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({
    required this.subjectKey,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String subjectKey;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Seçili hap ember, seçilmeyen nötr — sınav satırının `isActive` dolgusuyla
    // aynı dil, yalnızca yüzey küçüldü.
    final Color border = selected ? colors.ember : colors.fillMedium;
    final Color text = selected ? colors.ember : colors.neutral300;

    return AppPressable(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: subjectChipKey(subjectKey),
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? colors.emberDeep : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border),
            ),
            child: Text(
              subjectName(AppLocalizations.of(context), subjectKey),
              style: AppTypography.label(
                  fontSize: AppTextSize.md, weight: FontWeight.w500, color: text),
            ),
          ),
        ),
      ),
    );
  }
}
