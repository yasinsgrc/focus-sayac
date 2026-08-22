import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/notifications/notification_service.dart';
import '../../services/storage/app_database.dart';
import '../../services/storage/storage_providers.dart';
import 'badge_definition.dart';
import 'badge_rules.dart';

/// Açılmış rozetler — Ekran 04'ün kilit/açık durumunu buradan türetir.
final StreamProvider<List<UserBadge>> unlockedBadgesProvider = StreamProvider<List<UserBadge>>((Ref ref) {
  return ref.watch(userBadgeDaoProvider).watchUnlockedBadges();
});

final Provider<BadgeUnlockService> badgeUnlockServiceProvider = Provider<BadgeUnlockService>((Ref ref) {
  return BadgeUnlockService(ref);
});

/// SPEC.md §5.4'ün IO'lu tarafı: saf [evaluateEarnedBadgeKeys] sonucunu henüz
/// açılmamış rozetlerle karşılaştırır, yeni kazanılanları `UserBadgeDao`'ya
/// yazar, her biri için `NotificationService.showBadgeUnlocked`'ı tetikler
/// (Faz 6'nın "Faz 7'de bağlanacak" notu) ve açılışta tek bir
/// `HapticFeedback.heavyImpact()` üretir (ayarlardan kapatılabilir — diğer
/// tüm haptik çağrılarıyla aynı kural, `PomodoroController._haptic`).
class BadgeUnlockService {
  BadgeUnlockService(this._ref);

  final Ref _ref;

  /// `PomodoroController._completeFocus`'un her odak tamamlanışında çağırdığı
  /// tek giriş noktası. Tüm tamamlanmış odak geçmişini yeniden değerlendirir
  /// (saf fonksiyon idempotent'tir) — bu yüzden geriye dönük hesap hatası
  /// riski yok, yalnızca zaten açık olanları tekrar yazmaz.
  Future<void> evaluateAfterFocusCompletion() async {
    final List<PomodoroSession> sessions =
        await _ref.read(pomodoroSessionDaoProvider).getAllCompletedFocusSessions();
    final Set<String> earnedKeys = evaluateEarnedBadgeKeys(completedFocusSessions: sessions);

    final List<UserBadge> existing = await _ref.read(userBadgeDaoProvider).getUnlockedBadges();
    final Set<String> existingKeys = existing.map((UserBadge b) => b.badgeKey).toSet();
    final Set<String> newlyEarned = earnedKeys.difference(existingKeys);
    if (newlyEarned.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now().toUtc();
    for (final String key in newlyEarned) {
      await _ref.read(userBadgeDaoProvider).unlockBadge(badgeKey: key, unlockedAt: now);
      final BadgeDefinition definition = badgeByKey(key);
      await _ref.read(notificationServiceProvider).showBadgeUnlocked(
            name: definition.name,
            ruleDescription: definition.rule,
          );
    }

    final AppSettingsTableData settings = await _ref.read(appSettingsDaoProvider).getSettings();
    if (settings.hapticEnabled) {
      unawaited(HapticFeedback.heavyImpact());
    }
  }
}
