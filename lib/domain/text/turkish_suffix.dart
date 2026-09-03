/// Türkçe yönelme hâli eki (`-e` / `-a`) üreteci — Ekran 05'in başarı kartı
/// metinleri için. Prototip eki sabit yazıyor (`ex.name + "'e "`,
/// `"Yarın 7'ye"`); paylaşılan bir görselde `YKS 2027'e` gibi bir hata kalıcı
/// olduğu için ek burada sözcüğün son ünlüsünden türetiliyor.
///
/// Saf fonksiyon, IO yok.
library;

const String _frontVowels = 'eiöü';
const String _backVowels = 'aıou';

/// Okunuşun ek için gereken iki özelliği: son ünlüsü ince mi, ve okunuş
/// ünlüyle mi bitiyor (kaynaştırma `y`'si gerekir mi).
class _Reading {
  const _Reading({required this.front, required this.endsWithVowel});

  final bool front;
  final bool endsWithVowel;
}

/// `iki` → ince + ünlüyle biter, `dokuz` → kalın, `altı` → kalın + ünlü …
const Map<int, _Reading> _digitReadings = <int, _Reading>{
  1: _Reading(front: true, endsWithVowel: false), // bir
  2: _Reading(front: true, endsWithVowel: true), // iki
  3: _Reading(front: true, endsWithVowel: false), // üç
  4: _Reading(front: true, endsWithVowel: false), // dört
  5: _Reading(front: true, endsWithVowel: false), // beş
  6: _Reading(front: false, endsWithVowel: true), // altı
  7: _Reading(front: true, endsWithVowel: true), // yedi
  8: _Reading(front: true, endsWithVowel: false), // sekiz
  9: _Reading(front: false, endsWithVowel: false), // dokuz
};

/// Sonu sıfırla biten sayılarda okunan basamak onlar hanesidir: `20` → yirmi.
const Map<int, _Reading> _tensReadings = <int, _Reading>{
  1: _Reading(front: false, endsWithVowel: false), // on
  2: _Reading(front: true, endsWithVowel: true), // yirmi
  3: _Reading(front: false, endsWithVowel: false), // otuz
  4: _Reading(front: false, endsWithVowel: false), // kırk
  5: _Reading(front: true, endsWithVowel: true), // elli
  6: _Reading(front: false, endsWithVowel: false), // altmış
  7: _Reading(front: true, endsWithVowel: false), // yetmiş
  8: _Reading(front: true, endsWithVowel: false), // seksen
  9: _Reading(front: false, endsWithVowel: false), // doksan
};

const _Reading _hundred = _Reading(front: true, endsWithVowel: false); // yüz
const _Reading _thousand = _Reading(front: true, endsWithVowel: false); // bin
const _Reading _million = _Reading(front: false, endsWithVowel: false); // milyon
const _Reading _zero = _Reading(front: false, endsWithVowel: false); // sıfır

/// [word]'e eklenecek kesme işaretli yönelme eki: `2027` → `'ye`,
/// `100` → `'e`, `Deneme` → `'ye`, `KPSS` → `'e`.
///
/// Sözcük rakamla bitiyorsa ek, sayının **okunuşuna** göre seçilir (özel ad
/// + sayı kalıbı: `YKS 2027`). Aksi hâlde son ünlünün kalınlık/incelik
/// uyumuna göre.
String dativeSuffix(String word) {
  final String trimmed = word.trim();
  if (trimmed.isEmpty) return "'e";

  final RegExpMatch? digits = RegExp(r'(\d+)$').firstMatch(trimmed);
  final _Reading reading =
      digits != null ? _numberReading(digits.group(1)!) : _wordReading(trimmed);

  final String vowel = reading.front ? 'e' : 'a';
  return reading.endsWithVowel ? "'y$vowel" : "'$vowel";
}

/// Sayının **son okunan** birimini bulur: `2027` → yedi, `2020` → yirmi,
/// `1200` → yüz, `2000` → bin.
_Reading _numberReading(String digits) {
  final String trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final int lastDigit = int.parse(trimmed[trimmed.length - 1]);
  if (lastDigit != 0) return _digitReadings[lastDigit]!;

  int zeros = 0;
  while (zeros < trimmed.length && trimmed[trimmed.length - 1 - zeros] == '0') {
    zeros += 1;
  }
  if (zeros >= trimmed.length) return _zero; // "0", "000"
  if (zeros >= 6) return _million;
  if (zeros >= 3) return _thousand;
  if (zeros == 2) return _hundred;
  return _tensReadings[int.parse(trimmed[trimmed.length - 2])]!;
}

_Reading _wordReading(String word) {
  final String lowered = _toTurkishLowerCase(word);
  for (int i = lowered.length - 1; i >= 0; i--) {
    final String char = lowered[i];
    final bool front = _frontVowels.contains(char);
    if (front || _backVowels.contains(char)) {
      return _Reading(front: front, endsWithVowel: i == lowered.length - 1);
    }
  }
  // Hiç ünlü yok (kısaltmalar: `KPSS`, `DGS`) — harflerin kendi okunuşu
  // ince biter (`ke-pe-se-se`, `de-ge-se`), ince ek doğru olan.
  return const _Reading(front: true, endsWithVowel: false);
}

/// Dart'ın `toLowerCase()`i `I`yi `i`ye çevirir; Türkçede karşılığı `ı`.
String _toTurkishLowerCase(String value) {
  return value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
}
