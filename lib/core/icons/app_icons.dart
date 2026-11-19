// Phosphor ikonları (MIT, bkz. assets/fonts/phosphor/LICENSE).
//
// `phosphor_flutter` paketi `IconData`yı genişlettiği için Flutter 3.47'de
// derlenmiyor (IconData artık `final`). Kullandığımız ikonları aynı kod
// noktalarıyla burada tutuyoruz; yeni ikon gerekirse kod noktasını paketin
// kaynağından ya da phosphoricons.com'dan ekle.
//
// Duotone ikonlar hep düz `Icon` ile çizildi, yani yalnızca birincil katman
// görünüyordu; burada da yalnızca o katman var.
library;

import 'package:flutter/widgets.dart';

abstract final class AppIconsRegular {
  static const armchair = IconData(0xe012, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const arrowRight = IconData(0xe06c, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const calendarDots = IconData(0xe7b4, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const caretDown = IconData(0xe136, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const caretLeft = IconData(0xe138, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const chartBar = IconData(0xe150, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const check = IconData(0xe182, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const checkCircle = IconData(0xe184, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const clock = IconData(0xe19a, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const clockCountdown = IconData(0xed2c, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const downloadSimple = IconData(0xe20c, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const drop = IconData(0xe210, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const eye = IconData(0xe220, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const eyeClosed = IconData(0xe222, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const eyeSlash = IconData(0xe224, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const footprints = IconData(0xea88, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const gear = IconData(0xe270, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const info = IconData(0xe2ce, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const medal = IconData(0xe320, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const plus = IconData(0xe3d4, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const shareNetwork = IconData(0xe408, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const timer = IconData(0xe492, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const wind = IconData(0xe5d2, fontFamily: 'PhosphorRegular', matchTextDirection: true);
  static const x = IconData(0xe4f6, fontFamily: 'PhosphorRegular', matchTextDirection: true);
}

abstract final class AppIconsFill {
  static const chartBar = IconData(0xe150, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const flame = IconData(0xe624, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const gear = IconData(0xe270, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const medal = IconData(0xe320, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const pause = IconData(0xe39e, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const play = IconData(0xe3d0, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const sparkle = IconData(0xe6a2, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const sunHorizon = IconData(0xe5b6, fontFamily: 'PhosphorFill', matchTextDirection: true);
  static const timer = IconData(0xe492, fontFamily: 'PhosphorFill', matchTextDirection: true);
}

abstract final class AppIconsDuotone {
  static const alarm = IconData(0xe007, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const bell = IconData(0xe0cf, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const bellRinging = IconData(0xe5e9, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const bookOpen = IconData(0xe0e7, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const calendarBlank = IconData(0xe10b, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const calendarCheck = IconData(0xe713, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const calendarX = IconData(0xe10d, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const checkCircle = IconData(0xe185, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const circleHalf = IconData(0xe18d, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const clockCountdown = IconData(0xed2d, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const coffee = IconData(0xe1c3, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const crown = IconData(0xe615, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const deviceMobileSlash = IconData(0xee47, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const flame = IconData(0xe625, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const graduationCap = IconData(0xe62d, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const hourglass = IconData(0xe2b3, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const info = IconData(0xe2cf, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const lightning = IconData(0xe2df, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const medal = IconData(0xe321, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const moonStars = IconData(0xe58f, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const personSimpleRun = IconData(0xe731, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const sealCheck = IconData(0xe607, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const shieldCheck = IconData(0xe40f, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const speakerHigh = IconData(0xe44b, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const star = IconData(0xe46b, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const trash = IconData(0xe4a7, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const trophy = IconData(0xe67f, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const vibrate = IconData(0xe4d9, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
  static const warningCircle = IconData(0xe4e3, fontFamily: 'PhosphorDuotone', matchTextDirection: true);
}
