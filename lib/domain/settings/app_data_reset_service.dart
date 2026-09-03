import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/storage/storage_providers.dart';
import '../pomodoro/pomodoro_controller.dart';

final Provider<AppDataResetService> appDataResetServiceProvider = Provider<AppDataResetService>((Ref ref) {
  return AppDataResetService(ref);
});

/// SPEC.md Ekran 07 "Verileri sıfırla (onaylı)". Sıfırlanan şey **ilerleme**:
/// odak geçmişi, açılmış rozetler ve kurtarılabilir aktif seans kaydı.
///
/// Sınavlar ve ayarlar bilinçli olarak korunuyor — sınav listesi kullanıcının
/// ilerlemesi değil uygulamanın kataloğu (silinseydi 4 preset de giderdi ve
/// Ekran 02 sınavsız kalırdı), süreler/anahtarlar ise tercih. Onay dialogunun
/// metni de tam olarak bunu söylüyor: "sıfırla"nın kapsamı kullanıcıya
/// söylenenle birebir aynı olmak zorunda.
class AppDataResetService {
  const AppDataResetService(this._ref);

  final Ref _ref;

  Future<void> resetProgress() async {
    await _ref.read(pomodoroSessionDaoProvider).deleteAllSessions();
    await _ref.read(userBadgeDaoProvider).deleteAllBadges();
    // Silinen seans satırına işaret eden kurtarma kaydı geride kalmamalı:
    // kalsaydı `PomodoroController.build()` artık var olmayan bir `sessionId`
    // ile odak fazını geri yükler, faz kapanışındaki `finishSession` de
    // sessizce hiçbir satırı güncellemezdi.
    final SharedPreferences prefs = _ref.read(sharedPreferencesProvider);
    await prefs.remove(kPomodoroPhasePrefsKey);
    // Bellekteki faz da aynı kayda dayanıyor; provider yeniden kurulunca
    // `build()` boşalan kayıttan `idle` okuyor.
    _ref.invalidate(pomodoroControllerProvider);
  }
}
