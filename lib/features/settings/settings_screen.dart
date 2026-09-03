import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/exams/exam_providers.dart';
import '../../domain/review/app_review_service.dart';
import '../../domain/settings/app_data_reset_service.dart';
import '../../domain/settings/settings_providers.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';
import '../countdown/widgets/exam_picker_sheet.dart';

/// SPEC.md Ekran 07 slider sınırları — varsayılanlar (25/5/15) kolonların
/// kendi varsayılanı olduğu için burada tekrar edilmiyor (`tables.dart`).
const int kFocusMinutesMin = 5;
const int kFocusMinutesMax = 90;
const int kBreakMinutesMin = 1;
const int kBreakMinutesMax = 30;

/// Ekran 07 — ayarlar. Prototip v2 satır 287-315 birebir. Bu ekranda alt
/// gezinme çubuğu yok (prototipte de yok — Ekran 04 ile aynı durum, Faz 7
/// kararı); geri dönüş sistem geri tuşu/kaydırmasıyla olur.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Sürükleme sırasındaki anlık değerler. `appSettingsProvider` akışı her
  // yazımdan sonra yeniden yayınlıyor ama sürüklerken her karede DB'ye yazmak
  // gereksiz; parmak kalkınca (`onChangeEnd`) bir kez yazılıyor ve o ana kadar
  // gösterilen değer buradan geliyor. Ekran kapanınca durum da gidiyor,
  // yeniden açıldığında değer yine ayardan okunuyor.
  int? _focusMinutes;
  int? _shortBreakMinutes;
  int? _longBreakMinutes;

  Future<void> _write(AppSettingsTableCompanion changes) {
    return ref.read(appSettingsDaoProvider).updateSettings(changes);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AsyncValue<AppSettingsTableData> settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 6, 26, 0),
          child: settingsAsync.when(
            data: _buildContent,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object error, StackTrace stackTrace) => Center(
              child: Text(
                'Ayarlar okunamadı.',
                style: AppTypography.body(fontSize: 14, color: colors.neutral500),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AppSettingsTableData settings) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final int focus = _focusMinutes ?? settings.focusMinutes;
    final int shortBreak = _shortBreakMinutes ?? settings.shortBreakMinutes;
    final int longBreak = _longBreakMinutes ?? settings.longBreakMinutes;
    final Exam? activeExam = ref.watch(activeExamProvider).value;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 8),
          Text('AYARLAR', style: AppTypography.display(fontSize: 34, weight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xB81E2030),
              borderRadius: BorderRadius.circular(26),
              border: const Border.fromBorderSide(BorderSide(color: Color(0x12FFFFFF))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('SÜRELER', style: AppTypography.kicker(fontSize: 8, color: colors.neutral600, letterSpacingEm: 0.24)),
                const SizedBox(height: 14),
                _DurationSlider(
                  label: 'Odak',
                  minutes: focus,
                  min: kFocusMinutesMin,
                  max: kFocusMinutesMax,
                  tint: colors.ember,
                  onChanged: (int value) => setState(() => _focusMinutes = value),
                  onChangeEnd: (int value) => _write(AppSettingsTableCompanion(focusMinutes: Value<int>(value))),
                ),
                const SizedBox(height: 14),
                _DurationSlider(
                  label: 'Kısa mola',
                  minutes: shortBreak,
                  min: kBreakMinutesMin,
                  max: kBreakMinutesMax,
                  tint: colors.mint,
                  onChanged: (int value) => setState(() => _shortBreakMinutes = value),
                  onChangeEnd: (int value) => _write(AppSettingsTableCompanion(shortBreakMinutes: Value<int>(value))),
                ),
                const SizedBox(height: 14),
                _DurationSlider(
                  label: 'Uzun mola',
                  minutes: longBreak,
                  min: kBreakMinutesMin,
                  max: kBreakMinutesMax,
                  tint: colors.sky,
                  onChanged: (int value) => setState(() => _longBreakMinutes = value),
                  onChangeEnd: (int value) => _write(AppSettingsTableCompanion(longBreakMinutes: Value<int>(value))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: ColoredBox(
              // Satır aralarındaki 1px'lik boşluk bu zeminden görünüyor
              // (prototipteki `gap:1px` + kapsayıcı arka planı).
              color: const Color(0x12FFFFFF),
              child: Column(
                children: <Widget>[
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.bell,
                    iconColor: colors.accent400,
                    label: 'Bildirimler',
                    value: _onOff(settings.notificationsEnabled),
                    valueColor: _onOffColor(settings.notificationsEnabled, colors),
                    onTap: () => _write(
                      AppSettingsTableCompanion(notificationsEnabled: Value<bool>(!settings.notificationsEnabled)),
                    ),
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.speakerHigh,
                    iconColor: colors.accent400,
                    label: 'Sesli uyarı',
                    value: _onOff(settings.soundEnabled),
                    valueColor: _onOffColor(settings.soundEnabled, colors),
                    onTap: () => _write(
                      AppSettingsTableCompanion(soundEnabled: Value<bool>(!settings.soundEnabled)),
                    ),
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.vibrate,
                    iconColor: colors.accent400,
                    label: 'Titreşim',
                    value: _onOff(settings.hapticEnabled),
                    valueColor: _onOffColor(settings.hapticEnabled, colors),
                    onTap: () => _write(
                      AppSettingsTableCompanion(hapticEnabled: Value<bool>(!settings.hapticEnabled)),
                    ),
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.flame,
                    iconColor: colors.ember,
                    label: 'Seri hatırlatması',
                    value: _onOff(settings.streakReminderEnabled),
                    valueColor: _onOffColor(settings.streakReminderEnabled, colors),
                    onTap: () => _write(
                      AppSettingsTableCompanion(streakReminderEnabled: Value<bool>(!settings.streakReminderEnabled)),
                    ),
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.graduationCap,
                    iconColor: colors.sky,
                    label: 'Sınav seçimi',
                    value: activeExam?.name ?? 'Seçilmedi',
                    valueColor: colors.neutral500,
                    showCaret: true,
                    onTap: () => showExamPickerSheet(context),
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.clockCountdown,
                    iconColor: colors.neutral500,
                    label: "Gün 04:00'te başlar",
                    // SPEC.md §5.3'ün gün sınırı — dokunulacak bir hedefi yok,
                    // bilgi satırı (bu yüzden `onTap: null` ve ok işareti yok).
                    value: '',
                    valueColor: colors.neutral500,
                    onTap: null,
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.star,
                    iconColor: colors.ember,
                    label: 'Uygulamayı değerlendir',
                    value: '',
                    valueColor: colors.neutral500,
                    showCaret: true,
                    onTap: _openStoreListing,
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.info,
                    iconColor: colors.accent400,
                    label: 'Hakkında',
                    value: '',
                    valueColor: colors.neutral500,
                    showCaret: true,
                    onTap: () => _showInfoDialog(
                      title: 'HAKKINDA',
                      body: 'FocusSayaç, sınavına kalan günü ve odak sürelerini tek yerde tutan '
                          'bağımsız bir çalışma aracıdır. ÖSYM, MEB veya resmî bir kurumla '
                          'bağlantılı değildir; sınav tarihleri resmî takvimden doğrulanmalıdır.',
                    ),
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.shieldCheck,
                    iconColor: colors.mint,
                    label: 'Gizlilik politikası',
                    value: '',
                    valueColor: colors.neutral500,
                    showCaret: true,
                    onTap: () => _showInfoDialog(
                      title: 'GİZLİLİK POLİTİKASI',
                      body: 'FocusSayaç hesap açmanı istemez ve kişisel veri toplamaz. Sınavların, '
                          'odak geçmişin, rozetlerin ve ayarların yalnızca bu cihazda, uygulamanın '
                          'kendi veritabanında saklanır — hiçbiri sunucuya gönderilmez. Uygulamayı '
                          'kaldırdığında bu veriler de silinir.',
                    ),
                  ),
                  _SettingsRow(
                    icon: PhosphorIconsDuotone.trash,
                    iconColor: colors.rose,
                    label: 'Verileri sıfırla',
                    value: '',
                    valueColor: colors.neutral500,
                    showCaret: true,
                    onTap: _confirmReset,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _RemoveAdsRow(colors: colors),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Bağımsız bir çalışma aracıdır; ÖSYM, MEB veya resmî bir kurumla bağlantılı değildir.',
              style: AppTypography.body(fontSize: 11.5, color: colors.neutral600, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  static String _onOff(bool enabled) => enabled ? 'Açık' : 'Kapalı';

  static Color _onOffColor(bool enabled, AppColors colors) => enabled ? colors.mint : colors.neutral500;

  Future<void> _openStoreListing() async {
    final bool opened = await ref.read(appReviewServiceProvider).openStoreListing();
    if (opened || !mounted) return;
    // Açık bir dokunuş sessizce yutulmamalı (mağaza uygulaması yoksa ya da
    // kanal yanıt vermezse `openStoreListing` false döner).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mağaza sayfası açılamadı.')),
    );
  }

  Future<void> _showInfoDialog({required String title, required String body}) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xAD04050A),
      builder: (BuildContext context) => _InfoDialog(title: title, body: body),
    );
  }

  Future<void> _confirmReset() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xAD04050A),
      builder: (BuildContext context) => const _ResetConfirmDialog(),
    );
    if (confirmed != true) return;
    await ref.read(appDataResetServiceProvider).resetProgress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Odak geçmişin ve rozetlerin sıfırlandı.')),
    );
  }
}

/// Prototipteki süre satırı: solda etiket, sağda renkli değer, altında ince
/// ray + yuvarlak tutamak.
class _DurationSlider extends StatelessWidget {
  const _DurationSlider({
    required this.label,
    required this.minutes,
    required this.min,
    required this.max,
    required this.tint,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final int minutes;
  final int min;
  final int max;
  final Color tint;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    // Kayıtlı değer sınırların dışında kalmış olsaydı (ör. sınırlar sonradan
    // daralırsa) `Slider` aralık dışı değerde assert atardı; gösterim
    // kırpılıyor, kullanıcı kaydırdığı anda değer aralığa giriyor.
    final double value = minutes.clamp(min, max).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(label, style: AppTypography.body(fontSize: 13.5, color: colors.text)),
            Text(
              '$minutes dk',
              style: AppTypography.display(fontSize: 16, weight: FontWeight.w700, color: tint)
                  .copyWith(fontFeatures: const <FontFeature>[FontFeature.tabularFigures()]),
            ),
          ],
        ),
        SizedBox(
          height: 26,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: tint,
              inactiveTrackColor: const Color(0x17FFFFFF),
              thumbColor: tint,
              // Prototipin 18px'lik yuvarlak tutamağı: Material 3'ün varsayılan
              // çubuk tutamağı yerine açıkça yuvarlak şekil veriliyor.
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              overlayColor: tint.withValues(alpha: 0.16),
              // Prototipte tutamağın üstünde duran değer balonu yok.
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: value,
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (double v) => onChanged(v.round()),
              onChangeEnd: (double v) => onChangeEnd(v.round()),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.onTap,
    this.showCaret = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback? onTap;

  /// Prototip her satırın sonuna sağ ok koyuyor; ok yalnızca **başka bir yere
  /// götüren** satırlarda korundu. Yerinde değişen anahtarlarda (Bildirimler,
  /// Ses, Titreşim, Seri hatırlatması) ok olmayan bir hedefi vaat ederdi —
  /// orada "Açık/Kapalı" değerinin kendisi hem durumu hem dokunmanın sonucunu
  /// gösteriyor.
  final bool showCaret;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Material(
      color: const Color(0xDB1E2030),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: AppTypography.body(fontSize: 13.5, color: colors.text)),
              ),
              if (value.isNotEmpty)
                Text(value, style: AppTypography.body(fontSize: 12.5, color: valueColor)),
              if (showCaret) ...<Widget>[
                const SizedBox(width: 10),
                Icon(PhosphorIconsRegular.caretRight, size: 13, color: colors.neutral700),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// SPEC §7.3 — satın alma akışı Faz 11'de kodlanacak, satır o zamana kadar
/// prototipteki gibi **pasif** görünüyor ("yakında" rozetiyle).
class _RemoveAdsRow extends StatelessWidget {
  const _RemoveAdsRow({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
      child: Row(
        children: <Widget>[
          Icon(PhosphorIconsDuotone.sealCheck, size: 21, color: colors.ember.withValues(alpha: 0.75)),
          const SizedBox(width: 13),
          Expanded(
            child: Text('Reklamları kaldır', style: AppTypography.body(fontSize: 13.5, color: colors.neutral400)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x0FFFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'YAKINDA',
              style: AppTypography.kicker(fontSize: 8, color: colors.neutral500, letterSpacingEm: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Dialog(
      backgroundColor: const Color(0xF51A1C2A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: AppTypography.display(fontSize: 20, weight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 12),
            Text(body, style: AppTypography.body(fontSize: 13, color: colors.neutral400)),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Kapat',
                  style: AppTypography.display(fontSize: 13, weight: FontWeight.w500, color: colors.neutral500),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SPEC.md Ekran 07 "Verileri sıfırla (onaylı)". Ekran 10'un iptal onayıyla
/// aynı görsel dil: rose kenarlık, önce güvenli seçenek.
class _ResetConfirmDialog extends StatelessWidget {
  const _ResetConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return Dialog(
      backgroundColor: const Color(0xF71A1C2A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
        side: const BorderSide(color: Color(0x47FF6A86)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PhosphorIconsDuotone.trash, size: 46, color: colors.rose),
            const SizedBox(height: 18),
            Text('VERİLER SİLİNECEK', style: AppTypography.display(fontSize: 23, weight: FontWeight.w700, color: colors.text)),
            const SizedBox(height: 10),
            Text(
              'Odak geçmişin ve açılmış rozetlerin kalıcı olarak silinir, serin sıfırlanır. '
              'Sınavların ve ayarların olduğu gibi kalır. Bu işlem geri alınamaz.',
              textAlign: TextAlign.center,
              style: AppTypography.body(fontSize: 13.5, color: colors.neutral400),
            ),
            const SizedBox(height: 20),
            SizedBox(
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
                        'VAZGEÇ',
                        style: AppTypography.display(fontSize: 13.5, weight: FontWeight.w600, color: colors.mint),
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
                  border: Border.all(color: const Color(0x59FF6A86)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(true),
                    child: Center(
                      child: Text(
                        'Verileri sıfırla',
                        style: AppTypography.display(fontSize: 13.5, weight: FontWeight.w500, color: colors.rose),
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
