import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/domain/widgets/home_widget_snapshot.dart';

/// Launcher simgesinin zemini **temaya bagli olmamali**: Play Console'a tek bir
/// statik 512x512 PNG yukleniyor, cihazdaki simge ondan ayrisamaz.
///
/// Zemin bir kez `@color/focus_bg`e baglanmisti; o token niteleyiciye gore
/// cozuluyor (`values/` acik, `values-night/` koyu) ve launcher onu **sistem**
/// temasiyla cozdugu icin acik modda simge krem zeminli cikiyordu - magaza
/// gorseli ise koyu. Emulatorde (madde 38) goruldu.
///
/// Uc kaynak ayni rengi tasimak zorunda: adaptive zemin (API 26+), simge
/// katmanlarini rasterize eden `tool/generate_app_icon.py` (Play 512 ve API 26
/// oncesi mipmap'ler oradan cikiyor) ve Dart paletinin koyu `bg` tokeni.
void main() {
  const String xmlPath =
      'android/app/src/main/res/drawable/ic_launcher_background.xml';
  const String pyPath = 'tool/generate_app_icon.py';

  String read(String path) {
    final File file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path bulunamadi');
    return file.readAsStringSync();
  }

  /// Yorumlar haric govde: dosyanin kendi aciklamasi hatayi anlatmak icin
  /// `@color/focus_bg`i anmak zorunda, bu bir bagimlilik degil.
  String body(String path) =>
      read(path).replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  test('adaptive zemin AppColors.dark().bg ile birebir ayni', () {
    final String xml = body(xmlPath);

    final RegExpMatch? solid =
        RegExp(r'<solid\s+android:color="(#[0-9A-Fa-f]{8})"').firstMatch(xml);
    expect(solid, isNotNull, reason: '$xmlPath icinde duz zemin rengi yok');

    expect(
      solid!.group(1)!.toUpperCase(),
      HomeWidgetSnapshot.toHex(AppColors.dark().bg),
      reason: 'simge zemini Dart paletinin koyu bg tokeninden sapmis',
    );
  });

  test('adaptive zemin temaya bagli bir tokene baglanmiyor', () {
    // Asil hata buydu: `@color/focus_bg` derlenir, test gecer, ama simge
    // cihazin sistem temasina gore renk degistirir.
    expect(
      body(xmlPath),
      isNot(contains('@color/focus_bg')),
      reason: 'simge zemini niteleyiciye gore cozulen bir tokene baglanmis',
    );
  });

  test('simge ureteci ayni zemini kullaniyor', () {
    final RegExpMatch? bg = RegExp(
      r'^BG\s*=\s*\(0x([0-9A-Fa-f]{2}),\s*0x([0-9A-Fa-f]{2}),\s*0x([0-9A-Fa-f]{2})\)',
      multiLine: true,
    ).firstMatch(read(pyPath));
    expect(bg, isNotNull, reason: '$pyPath icinde BG sabiti bulunamadi');

    final Color expected = AppColors.dark().bg;
    expect(
      <int>[
        int.parse(bg!.group(1)!, radix: 16),
        int.parse(bg.group(2)!, radix: 16),
        int.parse(bg.group(3)!, radix: 16),
      ],
      <int>[
        (expected.r * 255).round(),
        (expected.g * 255).round(),
        (expected.b * 255).round(),
      ],
      reason: 'Play 512 ureteci simgenin adaptive zemininden ayrismis',
    );
  });
}
