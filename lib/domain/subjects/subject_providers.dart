import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';
import '../exams/exam_providers.dart';
import '../settings/settings_providers.dart';
import 'subject_catalog.dart';

/// Aktif sınavın ders listesi (ROADMAP madde 30). Sınav değiştiğinde kendi
/// kendine yeniden yayınlanıyor — alt sayfanın ve hapın tek kaynağı bu.
final Provider<List<String>> subjectCatalogProvider = Provider<List<String>>((Ref ref) {
  final Exam? exam = ref.watch(activeExamProvider).value;
  return subjectsForExam(exam?.presetKey);
});

/// Hapın gösterdiği ders. Ayardaki anahtar katalogda yoksa `null`:
/// `startFocus()` ile **aynı** çözümleme (`resolveActiveSubject`), yani hap ne
/// gösteriyorsa seansa o yazılıyor. İkisi ayrı ayrı hesaplansaydı sınav
/// değiştikten sonra hap bir ders gösterip seans dersiz yazılabilirdi.
final Provider<String?> activeSubjectProvider = Provider<String?>((Ref ref) {
  return resolveActiveSubject(
    ref.watch(appSettingsProvider).value?.activeSubjectKey,
    ref.watch(subjectCatalogProvider),
  );
});

/// Alt sayfanın yazma yolu. `ActiveExamSwitcher` gibi ayrı bir sınıf değil:
/// dersin eşleneceği ikinci bir tablo yok, tek bir ayar sütunu yazılıyor.
final Provider<Future<void> Function(String?)> subjectSelectorProvider =
    Provider<Future<void> Function(String?)>((Ref ref) {
  return (String? subjectKey) => ref.read(appSettingsDaoProvider).setActiveSubject(subjectKey);
});
