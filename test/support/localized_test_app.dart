import 'package:flutter/material.dart';

import 'package:focussayac/core/l10n/l10n_providers.dart';
import 'package:focussayac/core/theme/app_theme.dart';
import 'package:focussayac/l10n/gen/app_localizations.dart';

/// Testlerin `FocusSayacApp` yerine tek bir ekranı çizdiği durumlar için
/// `MaterialApp` kurulumu. Delegeleri ve `locale`i `main.dart`taki
/// `FocusSayacApp` ile **birebir** aynı tutuyor: `AppLocalizations.of(context)`
/// çağıran her widget ağaçta `Localizations` bulmak zorunda, ve ekranlar
/// testte de uygulamadaki dille (tr) çizilmeli.
MaterialApp localizedTestApp(Widget home) {
  return MaterialApp(
    theme: buildAppTheme(),
    locale: kAppLocale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

/// Widget ağacı olmayan testler (saf metin üreticileri, `NotificationService`)
/// için ARB örneği — uygulamanın tek diliyle aynı kaynak.
final AppLocalizations testL10n = lookupAppLocalizations(kAppLocale);
