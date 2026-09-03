import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';

/// Uygulamanın tek dili (SPEC.md §2 "ARB (tr varsayılan)"). Dil seçici yok —
/// `MaterialApp.locale` bununla sabitleniyor, cihaz dili uygulamanın metinlerini
/// değiştirmiyor (Faz 12 kararı: uygulama tek dilli).
const Locale kAppLocale = Locale('tr');

/// Bağlamı olmayan katmanların (`NotificationService`, `BadgeUnlockService`)
/// ARB'ye tek erişim yolu. Widget'lar `AppLocalizations.of(context)` kullanır —
/// orada `Localizations` zaten ağaçta ve `MaterialApp.locale` neyse o geçerli.
///
/// Servisler için bağlam yok: bir bildirim gövdesi `BuildContext` olmadan,
/// hatta ekran hiç açık değilken kuruluyor. `lookupAppLocalizations` bu yüzden
/// doğrudan çağrılıyor; elle yazılmış statik bir singleton yerine sağlayıcı
/// olması diğer servislerle aynı DI kalıbını (ve testlerde geçersiz kılma
/// imkânını) koruyor — SPEC §1 "singleton servisler yasak".
final Provider<AppLocalizations> appLocalizationsProvider = Provider<AppLocalizations>((Ref ref) {
  return lookupAppLocalizations(kAppLocale);
});
