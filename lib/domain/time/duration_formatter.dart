import '../../l10n/gen/app_localizations.dart';

/// Saniye cinsinden süreyi saat/dakika bileşenlerine ayıran saf fonksiyon
/// (SPEC.md §9 test listesi: "duration_formatter (0, 1 dk, 99+ sa)").
/// Biçimlendirilmiş metin değil, ham bileşenler döner — ekran, rakam/etiket
/// kısımlarını prototipteki gibi ayrı stillerle çizebilsin diye
/// (`1<span> SA </span>15<span> DK</span>` kalıbı).
class FocusDurationParts {
  const FocusDurationParts({required this.hours, required this.minutes});

  final int hours;
  final int minutes;
}

FocusDurationParts formatFocusDuration(int totalSeconds) {
  final int clamped = totalSeconds < 0 ? 0 : totalSeconds;
  final int hours = clamped ~/ 3600;
  final int minutes = (clamped % 3600) ~/ 60;
  return FocusDurationParts(hours: hours, minutes: minutes);
}

/// Süreyi cümle içinde okunacak hâle getirir: `2 saat 15 dakika` / `45 dakika`
/// / `3 saat`. Saat tam olduğunda "3 saat 0 dakika" demiyor.
///
/// Burada duruyor çünkü iki ayrı yüzey aynı cümleyi kuruyor: hikâye kartının
/// "Bugün … odaklandım" satırı ve haftalık kapanış bildiriminin "Bu hafta …
/// odaklandın" gövdesi. İkisinde ayrı ayrı yazılsaydı biri diğerinden (ör.
/// saat yuvarlamasında) sapabilirdi. [l10n] de bir girdi olduğu için fonksiyon
/// yine saf.
String spellFocusDuration(AppLocalizations l10n, int totalSeconds) {
  final FocusDurationParts parts = formatFocusDuration(totalSeconds);
  if (parts.hours == 0) return l10n.durationMinutes(parts.minutes);
  if (parts.minutes == 0) return l10n.durationHours(parts.hours);
  return l10n.durationHoursMinutes(parts.hours, parts.minutes);
}
