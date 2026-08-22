import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/countdown/countdown_math.dart';
import '../../domain/exams/exam_accent.dart';
import '../../domain/exams/exam_providers.dart';
import '../../services/storage/storage_enums.dart';
import '../../services/storage/storage_providers.dart';

/// Ekran 11 — özel sınav ekleme. Prototip satır 402-433 birebir.
class AddExamScreen extends ConsumerStatefulWidget {
  const AddExamScreen({super.key});

  @override
  ConsumerState<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends ConsumerState<AddExamScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  ExamAccentRole _accent = ExamAccentRole.ember;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  DateTime get _dateUtc {
    return DateTime.utc(_date.year, _date.month, _date.day, _time.hour, _time.minute)
        .subtract(const Duration(hours: 3));
  }

  String get _timeOfDayText =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final int id = await ref.read(examDaoProvider).insertUserExam(
          name: name,
          subtitle: _subtitleController.text.trim().isEmpty ? null : _subtitleController.text.trim(),
          dateUtc: _dateUtc,
          timeOfDay: _timeOfDayText,
          accentRole: _accent,
        );
    await ref.read(activeExamSwitcherProvider).switchTo(id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final bool canSave = _nameController.text.trim().isNotEmpty && !_saving;
    final int previewDays = daysTo(_dateUtc, DateTime.now().toUtc());

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
                      child: Icon(PhosphorIconsRegular.x, size: 16, color: colors.neutral400),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('ÖZEL SINAV', style: AppTypography.display(fontSize: 19, weight: FontWeight.w600, color: colors.text)),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _FieldLabel('SINAV ADI', colors),
                      const SizedBox(height: 8),
                      _TextField(
                        controller: _nameController,
                        hint: 'Ehliyet sınavı',
                        focusedColor: colors.sky,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('OTURUM ETİKETİ (OPSİYONEL)', colors),
                      const SizedBox(height: 8),
                      _TextField(controller: _subtitleController, hint: 'ör. 2. dönem', focusedColor: colors.sky),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            flex: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _FieldLabel('TARİH', colors),
                                const SizedBox(height: 8),
                                _PickerField(
                                  text: DateFormat('d MMMM y', 'tr').format(_date),
                                  icon: PhosphorIconsRegular.calendarDots,
                                  colors: colors,
                                  onTap: _pickDate,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _FieldLabel('SAAT', colors),
                                const SizedBox(height: 8),
                                _PickerField(
                                  text: _timeOfDayText,
                                  icon: PhosphorIconsRegular.clock,
                                  colors: colors,
                                  onTap: _pickTime,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('VURGU RENGİ', colors),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          for (final ExamAccentRole role in ExamAccentRole.values) ...<Widget>[
                            _AccentDot(
                              role: role,
                              selected: _accent == role,
                              colors: colors,
                              onTap: () => setState(() => _accent = role),
                            ),
                            const SizedBox(width: 10),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: colors.skyDeep.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: colors.sky.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(PhosphorIconsRegular.info, size: 18, color: colors.sky),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'Özel sınavlar her zaman öncelikli gösterilir; paketle gelen tarih tablosunu ezmez.',
                                style: AppTypography.body(fontSize: 12, color: colors.neutral300),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: <Widget>[
                    Icon(PhosphorIconsFill.timer, size: 20, color: colors.ember),
                    const SizedBox(width: 12),
                    Text.rich(
                      TextSpan(
                        style: AppTypography.body(fontSize: 12.5, color: colors.neutral300),
                        children: <InlineSpan>[
                          const TextSpan(text: 'Önizleme: '),
                          TextSpan(
                            text: '$previewDays gün',
                            style: AppTypography.display(fontSize: 15, weight: FontWeight.w700, color: colors.text),
                          ),
                          const TextSpan(text: ' kaldı'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.mint),
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[colors.mintDeep, colors.mintDeep.withValues(alpha: 0)],
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: canSave ? _save : null,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(PhosphorIconsRegular.check, size: 17, color: canSave ? colors.mint : colors.neutral600),
                            const SizedBox(width: 9),
                            Text(
                              'KAYDET',
                              style: AppTypography.display(
                                fontSize: 15,
                                weight: FontWeight.w600,
                                color: canSave ? colors.mint : colors.neutral600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.colors);

  final String text;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTypography.kicker(fontSize: 8, color: colors.neutral600));
  }
}

class _TextField extends StatelessWidget {
  const _TextField({required this.controller, required this.hint, required this.focusedColor, this.onChanged});

  final TextEditingController controller;
  final String hint;
  final Color focusedColor;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTypography.body(fontSize: 15, weight: FontWeight.w500, color: colors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body(fontSize: 15, color: colors.neutral600),
        filled: true,
        fillColor: const Color(0xCC1E2030),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: focusedColor),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.text, required this.icon, required this.colors, required this.onTap});

  final String text;
  final IconData icon;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xCC1E2030),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(fontSize: 15, weight: FontWeight.w500, color: colors.text),
              ),
            ),
            Icon(icon, size: 18, color: colors.sky),
          ],
        ),
      ),
    );
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.role, required this.selected, required this.colors, required this.onTap});

  final ExamAccentRole role;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = examAccentColor(role, colors);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: selected
              ? <BoxShadow>[
                  BoxShadow(color: colors.bg, spreadRadius: 2),
                  BoxShadow(color: color, spreadRadius: 4),
                ]
              : null,
        ),
      ),
    );
  }
}
