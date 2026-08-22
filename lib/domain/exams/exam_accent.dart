import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/storage/storage_enums.dart';

/// `Exam.accentRole` → tema rengi eşlemesi. SPEC.md §2 "Renk ROL taşır":
/// ember=ateş/seri, mint=tamamlanan iş, rose=iptal/risk, sky=veri,
/// accent(mor)=ikincil vurgu.
Color examAccentColor(ExamAccentRole role, AppColors colors) {
  switch (role) {
    case ExamAccentRole.ember:
      return colors.ember;
    case ExamAccentRole.mint:
      return colors.mint;
    case ExamAccentRole.rose:
      return colors.rose;
    case ExamAccentRole.sky:
      return colors.sky;
    case ExamAccentRole.accent:
      return colors.accent400;
  }
}

/// Sınav seçici sheet'te kalın (deep) zemin tonu — seçili satırın hafif
/// vurgusu için.
Color examAccentDeepColor(ExamAccentRole role, AppColors colors) {
  switch (role) {
    case ExamAccentRole.ember:
      return colors.emberDeep;
    case ExamAccentRole.mint:
      return colors.mintDeep;
    case ExamAccentRole.rose:
      return colors.roseDeep;
    case ExamAccentRole.sky:
      return colors.skyDeep;
    case ExamAccentRole.accent:
      return colors.accent900;
  }
}

/// Sınav seçici sheet'teki satır ikonu. Prototip bu alanı `{{ e.icon }}`
/// olarak veriye bağlamış ama somut bir değer vermemiş (yalnızca
/// `hint-placeholder-count`); tüm sınavlar için tek, tutarlı bir "sınav"
/// ikonu (mezuniyet kepi) kullanılıyor, rol rengiyle boyanıyor.
IconData examAccentIcon() => PhosphorIconsDuotone.graduationCap;
