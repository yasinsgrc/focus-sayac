import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'user_badge_dao.g.dart';

/// `UserBadge` tablosu için sorgu/komutlar. Statik rozet kataloğu
/// (ad/kural) `badge_rules.dart`'ta (Faz 7) koddadır — burada yalnızca
/// hangi `badgeKey`'in ne zaman açıldığı tutulur (SPEC.md §4).
@DriftAccessor(tables: <Type>[UserBadges])
class UserBadgeDao extends DatabaseAccessor<AppDatabase> with _$UserBadgeDaoMixin {
  UserBadgeDao(super.db);

  Stream<List<UserBadge>> watchUnlockedBadges() => select(userBadges).watch();

  Future<List<UserBadge>> getUnlockedBadges() => select(userBadges).get();

  /// Aynı rozet iki kez açılamaz — `badgeKey` birincil anahtar olduğu için
  /// `insertOnConflictUpdate` yerine sessizce yok sayılır (idempotent).
  Future<void> unlockBadge({required String badgeKey, required DateTime unlockedAt}) {
    return into(userBadges).insert(
      UserBadgesCompanion.insert(badgeKey: badgeKey, unlockedAt: unlockedAt),
      mode: InsertMode.insertOrIgnore,
    );
  }
}
