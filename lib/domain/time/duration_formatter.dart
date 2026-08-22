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
