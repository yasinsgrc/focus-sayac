import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/core/theme/app_typography.dart';

/// SPEC.md §10 DoD: "Her ekran prototiple yan yana konduğunda ayırt edilemiyor".
///
/// Bu maddenin son sözü cihazda, yan yana bakarak söylenir; ama "ayırt
/// edilebilir" hâle gelmenin en sessiz yolu paletin kayması. `app_colors.dart`
/// "prototipteki `:root` değişkenlerinden birebir" diyor — bugüne kadar bu
/// yalnızca bir yorum satırıydı, kimse doğrulamıyordu. Test tasarım dosyasını
/// **kaynak** kabul edip ayrıştırıyor: token elle değiştirilirse ya da prototip
/// güncellenip kod geride kalırsa düşer.
///
/// `:root`ta yalnız rol renkleri var; nötrler (#9397ab, #75798c …) prototipte
/// satır içi yazılmış, o yüzden bu testin kapsamı dışında.
const String _prototypePath = 'design/FocusSayac Prototip v2.dc.html';

/// `#f6f7ff` ve `#fff` (kısa biçim) — ikisi de opak ARGB'ye açılıyor.
int _argbFromCss(String hex) {
  String digits = hex.replaceFirst('#', '');
  if (digits.length == 3) {
    digits = digits.split('').map((String c) => '$c$c').join();
  }
  return int.parse('FF$digits', radix: 16);
}

/// CSS özel değişkenleri: `--ember:#ffb03a`. `--chrome` bir gradyan olduğu için
/// bu desene takılmıyor, aşağıda ayrıca ayrıştırılıyor.
Map<String, int> _rootColorTokens(String css) {
  final Map<String, int> tokens = <String, int>{};
  for (final RegExpMatch match
      in RegExp(r'--([a-z-]+):(#[0-9a-fA-F]{3,6})\b').allMatches(css)) {
    tokens[match.group(1)!] = _argbFromCss(match.group(2)!);
  }
  return tokens;
}

void main() {
  late String css;
  late Map<String, int> tokens;
  late AppColors colors;

  setUpAll(() {
    final File file = File(_prototypePath);
    expect(file.existsSync(), isTrue, reason: 'prototip dosyası bulunamadı: $_prototypePath');
    css = file.readAsStringSync();
    tokens = _rootColorTokens(css);
    colors = AppColors.dark();

    // Yanlış dosyayı ya da boş bir metni sessizce "geçmesin".
    expect(tokens.length, greaterThanOrEqualTo(9),
        reason: 'prototipin :root renk tokenları ayrıştırılamadı');
  });

  test('rol renkleri prototipin :root tokenlarıyla birebir', () {
    final Map<String, Color> mapping = <String, Color>{
      'ember': colors.ember,
      'ember-dim': colors.emberDim,
      'ember-deep': colors.emberDeep,
      'mint': colors.mint,
      'mint-deep': colors.mintDeep,
      'rose': colors.rose,
      'rose-deep': colors.roseDeep,
      'sky': colors.sky,
      'sky-deep': colors.skyDeep,
    };

    mapping.forEach((String token, Color color) {
      expect(tokens.containsKey(token), isTrue, reason: 'prototipte --$token yok');
      expect(
        color.toARGB32(),
        tokens[token],
        reason: '--$token prototiple uyuşmuyor',
      );
    });
  });

  test('zemin rengi prototipin body arka planıyla aynı', () {
    final RegExpMatch? body =
        RegExp(r'body\{[^}]*background:(#[0-9a-fA-F]{3,6})').firstMatch(css);
    expect(body, isNotNull, reason: 'prototipin body arka planı bulunamadı');
    expect(colors.bg.toARGB32(), _argbFromCss(body!.group(1)!));
  });

  test('krom gradyanı prototipin --chrome durakları', () {
    // `--chrome:linear-gradient(150deg,#f6f7ff,#b5abfc 34%,#63b4ff 52%,#ffb03a 78%,#fff)`
    final RegExpMatch? chrome =
        RegExp(r'--chrome:linear-gradient\(([^)]*)\)').firstMatch(css);
    expect(chrome, isNotNull, reason: 'prototipte --chrome gradyanı bulunamadı');

    final List<String> stops = chrome!
        .group(1)!
        .split(',')
        .map((String s) => s.trim())
        // İlk parça açı (`150deg`), renk değil.
        .where((String s) => s.startsWith('#'))
        .toList();

    expect(
      stops.map((String s) => _argbFromCss(s.split(' ').first)).toList(),
      AppColors.chromeGradient.map((Color c) => c.toARGB32()).toList(),
      reason: 'krom gradyanının renkleri prototiple uyuşmuyor',
    );

    // Yüzde verilmeyen ilk/son durak 0 ve 1; aradakiler prototipte yazılı.
    final List<double> expectedStops = <double>[];
    for (int i = 0; i < stops.length; i++) {
      final List<String> parts = stops[i].split(' ');
      if (parts.length > 1) {
        expectedStops.add(double.parse(parts[1].replaceAll('%', '')) / 100);
      } else {
        expectedStops.add(i == 0 ? 0 : 1);
      }
    }
    expect(AppColors.chromeGradientStops, expectedStops,
        reason: 'krom gradyanının durakları prototiple uyuşmuyor');
  });

  test('yazı tipi aileleri prototipin --disp/--mono tanımları', () {
    final RegExpMatch? disp = RegExp(r'--disp:"([^"]+)"').firstMatch(css);
    final RegExpMatch? mono = RegExp(r'--mono:"([^"]+)"').firstMatch(css);
    expect(disp, isNotNull, reason: 'prototipte --disp bulunamadı');
    expect(mono, isNotNull, reason: 'prototipte --mono bulunamadı');

    expect(AppFonts.display, disp!.group(1));
    expect(AppFonts.mono, mono!.group(1));
  });

  test('tipografi kuralları prototipin letter-spacing değerleri', () {
    // Prototipin başlıkları `letter-spacing:-.045em`, kicker'ları `.26em`.
    expect(css.contains('letter-spacing:-.045em'), isTrue,
        reason: 'prototipin başlık letter-spacing kuralı değişmiş');
    expect(css.contains('letter-spacing:.26em'), isTrue,
        reason: 'prototipin kicker letter-spacing kuralı değişmiş');

    // `em` oranı fontSize ile çarpılarak uygulanıyor.
    expect(AppTypography.display(fontSize: 100).letterSpacing, closeTo(-4.5, 1e-9));
    expect(AppTypography.kicker(fontSize: 100).letterSpacing, closeTo(26, 1e-9));
  });
}
