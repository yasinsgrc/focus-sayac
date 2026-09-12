import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/flame/flame_tier.dart';

/// Meşale widget'ı Dart merdivenine erişemediği için merdiven Kotlin'de bir
/// kez daha tanımlı. Bu test iki kopyanın ayrışmasını yakalar — palet senkron
/// testinin (`focus_palette_sync_test.dart`) aynı gerekçeyle kurulmuş kardeşi.
///
/// Seçilen mimarinin bilinen tek zayıf noktası buydu (bkz.
/// docs/superpowers/specs/2026-09-12-mesale-kademe-avatari-design.md, Riskler).
void main() {
  const String kotlinPath =
      'android/app/src/main/kotlin/com/focussayac/focussayac/widget/FlameTierLadder.kt';

  /// `FlameTier(index = 6, thresholdHours = 50, scale = 0.72f, emberBase = true, sparkCount = 2, haloOpacity = 0.0f)`
  /// satırlarını okur. Biçim değişirse test düşer — bu kasıtlı: satır düzeni
  /// sözleşmenin parçası.
  List<Map<String, String>> readKotlinLadder() {
    final File file = File(kotlinPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$kotlinPath bulunamadi - Kotlin merdiveni kaldirilmis olabilir',
    );

    final RegExp pattern = RegExp(
      r'FlameTier\(\s*index\s*=\s*(\d+),\s*'
      r'thresholdHours\s*=\s*(\d+),\s*'
      r'scale\s*=\s*([\d.]+)f,\s*'
      r'emberBase\s*=\s*(true|false),\s*'
      r'sparkCount\s*=\s*(\d+),\s*'
      r'haloOpacity\s*=\s*([\d.]+)f\s*\)',
    );

    return <Map<String, String>>[
      for (final RegExpMatch m in pattern.allMatches(file.readAsStringSync()))
        <String, String>{
          'index': m.group(1)!,
          'thresholdHours': m.group(2)!,
          'scale': m.group(3)!,
          'emberBase': m.group(4)!,
          'sparkCount': m.group(5)!,
          'haloOpacity': m.group(6)!,
        },
    ];
  }

  test('Kotlin merdiveni Dart merdiveniyle birebir aynı', () {
    final List<Map<String, String>> kotlin = readKotlinLadder();

    expect(
      kotlin.length,
      kFlameTierLadder.length,
      reason: 'Kotlin merdiveni ${kotlin.length} kademe, Dart ${kFlameTierLadder.length}',
    );

    for (int i = 0; i < kFlameTierLadder.length; i++) {
      final FlameTier dart = kFlameTierLadder[i];
      final Map<String, String> kt = kotlin[i];

      expect(int.parse(kt['index']!), dart.index, reason: 'K${dart.index} index sapmış');
      expect(int.parse(kt['thresholdHours']!), dart.thresholdHours,
          reason: 'K${dart.index} eşiği sapmış');
      expect(double.parse(kt['scale']!), closeTo(dart.scale, 1e-6),
          reason: 'K${dart.index} ölçeği sapmış');
      expect(kt['emberBase'] == 'true', dart.emberBase,
          reason: 'K${dart.index} kor yatağı sapmış');
      expect(int.parse(kt['sparkCount']!), dart.sparkCount,
          reason: 'K${dart.index} kıvılcım sayısı sapmış');
      expect(double.parse(kt['haloOpacity']!), closeTo(dart.haloOpacity, 1e-6),
          reason: 'K${dart.index} hâle opaklığı sapmış');
    }
  });
}
