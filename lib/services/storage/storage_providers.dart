import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'daos/app_settings_dao.dart';
import 'daos/exam_dao.dart';
import 'daos/pomodoro_session_dao.dart';
import 'daos/user_badge_dao.dart';

/// Uygulamanın tek `AppDatabase`/`SharedPreferences` örneği. `main.dart`
/// bunları gerçek örneklerle `ProviderScope.overrides` içinde geçersiz kılar
/// (Riverpod'un DI graf'ı — SPEC.md §1 "singleton servisler yasak" kuralına
/// aykırı değil, elle yazılmış statik singleton yerine bu kullanılıyor).
final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  throw UnimplementedError('appDatabaseProvider main.dart içinde override edilmeli.');
});

final Provider<SharedPreferences> sharedPreferencesProvider = Provider<SharedPreferences>((Ref ref) {
  throw UnimplementedError('sharedPreferencesProvider main.dart içinde override edilmeli.');
});

final Provider<ExamDao> examDaoProvider = Provider<ExamDao>((Ref ref) {
  return ref.watch(appDatabaseProvider).examDao;
});

final Provider<PomodoroSessionDao> pomodoroSessionDaoProvider = Provider<PomodoroSessionDao>((Ref ref) {
  return ref.watch(appDatabaseProvider).pomodoroSessionDao;
});

final Provider<UserBadgeDao> userBadgeDaoProvider = Provider<UserBadgeDao>((Ref ref) {
  return ref.watch(appDatabaseProvider).userBadgeDao;
});

final Provider<AppSettingsDao> appSettingsDaoProvider = Provider<AppSettingsDao>((Ref ref) {
  return ref.watch(appDatabaseProvider).appSettingsDao;
});
