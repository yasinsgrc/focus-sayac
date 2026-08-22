/// Uygulama içi rota yolları. Ekran adları SPEC.md §3'teki numaralandırmayla eşleşir.
/// Ekran 09 (mola) ve 10 (iptal onayı) Ekran 03'ün durum makinesi/dialog'u
/// içinde ele alınır, ayrı rota değildir (Faz 5 kararı).
abstract final class RoutePaths {
  static const String onboarding = '/onboarding';
  static const String countdown = '/countdown';
  static const String focusSession = '/focus';
  static const String badges = '/badges';
  static const String storyCard = '/story-card';
  static const String stats = '/stats';
  static const String settings = '/settings';
  static const String examExpired = '/exam-expired';
  static const String addExam = '/add-exam';
}
