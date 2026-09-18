import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/stats/subject_breakdown.dart';
import '../../../domain/subjects/subject_catalog.dart';
import '../../../domain/text/turkish_suffix.dart';
import '../../../domain/time/duration_formatter.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Dağılımın bir satırı — testler bir dersin süresine/yüzdesine bununla
/// bakıyor. Belirtilmemiş dilimin anahtarı `unspecified`.
Key subjectRowKey(String? subjectKey) =>
    ValueKey<String>('subject-row-${subjectKey ?? 'unspecified'}');

/// Çubuk rengi: sıraya göre `sky` → `skyDeep` rampası. Yeni tema alanı
/// açılmıyor — `sky` tanımı gereği "veri, istatistik" ve bar chart ile ısı
/// haritası da bu rengi kullanıyor.
///
/// Belirtilmemiş dilim rampanın dışında (`fillMedium`): bir ders değil, o
/// yüzden derslerin rengini almıyor.
Color subjectBarColor(AppColors colors, String? subjectKey, int index, int count) {
  if (subjectKey == null) return colors.fillMedium;
  if (count <= 1) return colors.sky;
  return Color.lerp(colors.sky, colors.skyDeep, index / (count - 1))!;
}

/// Ekran 06'nın ders dağılımı kartı (ROADMAP madde 30).
///
/// Pencere `calculateSubjectBreakdown` ile geliyor: bugünle biten yedi
/// uygulama günü, "BU HAFTA" kartıyla ve bar chart'la aynı tanım.
///
/// `CustomPainter` değil widget ağacı (`MonthlyHeatmapCard` ile aynı gerekçe):
/// satırlar testten görünüyor ve metinler sistem yazı tipi ölçeğine uyuyor.
class SubjectBreakdownCard extends StatelessWidget {
  const SubjectBreakdownCard({required this.breakdown, super.key});

  final SubjectBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          container: true,
          excludeSemantics: true,
          label: l10n.statsSubjectSemantics(
            breakdown.slices.length,
            spellFocusDuration(l10n, breakdown.totalSeconds),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              color: colors.surfaceCardSoft,
              borderRadius: BorderRadius.circular(26),
              border: Border.fromBorderSide(BorderSide(color: colors.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _header(colors, l10n),
                const SizedBox(height: 14),
                for (int i = 0; i < breakdown.slices.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 12),
                  _row(colors, l10n, breakdown.slices[i], i),
                ],
                ..._balance(colors, l10n),
              ],
            ),
          ),
        ),
        if (breakdown.neglect != null) ...<Widget>[
          const SizedBox(height: 12),
          _neglectRow(colors, l10n, breakdown.neglect!),
        ],
      ],
    );
  }

  Widget _header(AppColors colors, AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          l10n.statsSubjectLabel,
          style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
        ),
        // Kısa biçim (`4sa 30dk`): ısı haritasının başlığı `BU AY` ile kısa,
        // buradaki kicker `DERS DAĞILIMI` ile uzun ve ikisi 296px'lik kart
        // genişliğine birlikte sığmıyordu. Ekran okuyucu yine sözü duyuyor —
        // kartın `Semantics` etiketi uzun biçimi taşıyor.
        Flexible(
          child: Text(
            compactFocusDuration(l10n, breakdown.totalSeconds),
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.sky),
          ),
        ),
      ],
    );
  }

  /// Ad + süre + yüzde, altında oranı taşıyan çubuk. Çubuk kartın tam
  /// genişliğini kullanıyor: yüzdeler birbirine yakınken (%31 ↔ %28) sayıdan
  /// önce uzunluk okunuyor.
  Widget _row(AppColors colors, AppLocalizations l10n, SubjectSlice slice, int index) {
    return Column(
      key: subjectRowKey(slice.key),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                subjectName(l10n, slice.key),
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(
                  fontSize: AppTextSize.md,
                  weight: FontWeight.w500,
                  // Belirtilmemiş dilim soluk: dağılımda duruyor ama gözü
                  // derslerden önce çekmiyor.
                  color: slice.key == null ? colors.neutral500 : colors.text,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              compactFocusDuration(l10n, slice.seconds),
              style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.neutral400)
                  .copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.statsSubjectPercent((slice.ratio * 100).round()),
              style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.neutral600)
                  .copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: slice.ratio,
              backgroundColor: colors.fillSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(
                subjectBarColor(colors, slice.key, index, breakdown.slices.length),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Haftalık denge (iki uç). Önceki pencere boşken hesaplayıcı ikisini de
  /// `null` veriyor ve satır hiç çizilmiyor.
  List<Widget> _balance(AppColors colors, AppLocalizations l10n) {
    final SubjectShift? rise = breakdown.biggestRise;
    final SubjectShift? fall = breakdown.biggestFall;
    if (rise == null && fall == null) return const <Widget>[];

    return <Widget>[
      const SizedBox(height: 16),
      Divider(height: 1, thickness: 1, color: colors.hairline),
      const SizedBox(height: 12),
      // İki satır, tek satır değil: kicker etiketi + iki uç 390px ekranda
      // kartın içine sığmıyordu (emülatör öncesi widget testinde 40px taşma).
      Text(
        l10n.statsSubjectBalanceLabel,
        style: AppTypography.kicker(fontSize: AppTextSize.kicker, color: colors.neutral600),
      ),
      const SizedBox(height: 6),
      Text(
        <String>[
          if (rise != null)
            l10n.statsSubjectShiftUp(
              subjectName(l10n, rise.key),
              compactFocusDuration(l10n, rise.deltaSeconds),
            ),
          if (fall != null)
            l10n.statsSubjectShiftDown(
              subjectName(l10n, fall.key),
              compactFocusDuration(l10n, -fall.deltaSeconds),
            ),
        ].join('  ·  '),
        // Azalan uç da **nötr** tonda: düşen bir dersi uyarı rengiyle
        // göstermek `_WeeklyClosingCard`ın reddettiği ölçen ton olurdu.
        style: AppTypography.body(fontSize: AppTextSize.sm, color: colors.neutral400),
      ),
    ];
  }

  /// "En çok ihmal ettiğin ders" — `_ProductiveWindowCard` ile aynı kabuk:
  /// veriden çıkan tek cümlelik bir gözlem, kartın içi değil ekranın satırı.
  Widget _neglectRow(AppColors colors, AppLocalizations l10n, SubjectNeglect neglect) {
    final String name = subjectName(l10n, neglect.key);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.skyDeep.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.sky.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Icon(PhosphorIconsDuotone.bookOpen, size: 22, color: colors.sky),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              // Ek sözcüğün son ünlüsünden türetiliyor: `Kimya'ya`,
              // `Türkçe'ye`, `Tarih'e` (`turkish_suffix.dart`).
              l10n.statsSubjectNeglect('$name${dativeSuffix(name)}', neglect.daysSince),
              style: AppTypography.body(fontSize: AppTextSize.md, color: colors.neutral300),
            ),
          ),
        ],
      ),
    );
  }
}
