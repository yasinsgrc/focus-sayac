import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';

/// Aktif sınav — `Exam.isActive = true` olan tek satır. `ExamDao.setActiveExam`
/// değiştirdiğinde otomatik yeniden yayınlanır (drift `watchSingleOrNull`).
final StreamProvider<Exam?> activeExamProvider = StreamProvider<Exam?>((Ref ref) {
  return ref.watch(examDaoProvider).watchActiveExam();
});

/// Tüm sınavlar — kullanıcı sınavı her zaman preset'lerden önce sıralanır
/// (bkz. `ExamDao.watchAllExams`, SPEC.md §4).
final StreamProvider<List<Exam>> allExamsProvider = StreamProvider<List<Exam>>((Ref ref) {
  return ref.watch(examDaoProvider).watchAllExams();
});

/// Aktif sınavı ve `AppSettings.activeExamId`'yi tek işlemde değiştirir —
/// Faz 3 `DECISIONS.md`'nin ertelediği birleşik "değiştir" API'si.
final Provider<ActiveExamSwitcher> activeExamSwitcherProvider = Provider<ActiveExamSwitcher>((Ref ref) {
  return ActiveExamSwitcher(ref);
});

class ActiveExamSwitcher {
  ActiveExamSwitcher(this._ref);

  final Ref _ref;

  Future<void> switchTo(int examId) async {
    await _ref.read(examDaoProvider).setActiveExam(examId);
    await _ref.read(appSettingsDaoProvider).setActiveExam(examId);
  }
}
