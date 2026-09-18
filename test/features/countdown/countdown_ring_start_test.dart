import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_colors.dart';
import 'package:focussayac/features/countdown/widgets/countdown_ring_painter.dart';

/// ROADMAP madde 33. Bu dosya depodaki tek **piksel** testi: hata boyanın
/// kendisinde (`SweepGradient` yayın gerisinde 360°'ye sarılıp son durakta
/// örnekleniyordu), dolayısıyla painter'ın sözleşmesini okuyan bir iddia —
/// `effort_arc_test.dart`taki kalıp — bunu göremez. Gerçek font gerekmiyor,
/// çizilen tek şey geometri.
const double _size = 316;
const double _center = _size / 2;
const double _trackRadius = 130;
const double _strokeWidth = 9;

/// Yayın başlangıcı: 12 yönü.
const double _startAngle = -math.pi / 2;

/// Testin arkasına koyduğu opak zemin. Siyah seçildi ki `toByteData`nın
/// ön-çarpılmış alfası iddiaya karışmasın ve zeminin kendisi `r - b = 0` olsun.
const Color _backdrop = Color(0xFF000000);

Future<ui.Image> _render(AppColors colors, double progressRatio) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _size, _size),
    Paint()..color = _backdrop,
  );
  CountdownRingPainter(
    progressRatio: progressRatio,
    effortRatio: null,
    effortReached: false,
    dashRotation: 0,
    colors: colors,
  ).paint(canvas, const Size(_size, _size));
  return recorder.endRecording().toImage(_size.toInt(), _size.toInt());
}

/// Yayın merkezinden [angle] yönünde, [radius] uzaklıktaki piksel.
Color _pixelAt(ByteData pixels, double angle, double radius) {
  final int x = (_center + radius * math.cos(angle)).round().clamp(0, _size.toInt() - 1);
  final int y = (_center + radius * math.sin(angle)).round().clamp(0, _size.toInt() - 1);
  final int offset = (y * _size.toInt() + x) * 4;
  return Color.fromARGB(
    pixels.getUint8(offset + 3),
    pixels.getUint8(offset),
    pixels.getUint8(offset + 1),
    pixels.getUint8(offset + 2),
  );
}

/// Bir pikselin ne kadar "köz" olduğu: kırmızının maviye farkı. Köz
/// (255,176,58) +197, gökyüzü (99,180,255) −156, nötr zemin ve iz 0.
double _warmth(Color pixel) => (pixel.r - pixel.b) * 255;

/// Zeminden ve %7 saydam izden ayrılan, gerçekten boyanmış bir piksel mi?
/// İz koyu temada (18,18,18) = 54 toplamında kalıyor, yayın en sönük tonu bile
/// 300'ün üstünde.
bool _painted(Color pixel) => (pixel.r + pixel.g + pixel.b) * 255 > 200;

void main() {
  // `Picture.toImage` gerçek async istiyor; `testWidgets`in sahte zamanı yerine
  // düz `test` + hazırlanmış binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (String, AppColors) theme in <(String, AppColors)>[
    ('koyu', AppColors.dark()),
    ('açık', AppColors.light()),
  ]) {
    // %6 zaman yayının tabanı (400 gün ve ötesi), %25 tipik bir orta durum.
    // Leke oranla birlikte kımıldamıyordu, ikisi de kanıt.
    for (final double ratio in <double>[0.06, 0.25]) {
      test('${theme.$1} tema, %${(ratio * 100).round()}: yayın başlangıcında köz lekesi yok',
          () async {
        final ui.Image image = await _render(theme.$2, ratio);
        final ByteData pixels = (await image.toByteData())!;

        // Başlangıcın **gerisi**: yuvarlak uç buraya taşıyor ve gradyan burada
        // 360°'ye sarılıyordu. 20° geriden 2° ileriye, izin iki kenarı arasında
        // tarıyoruz.
        Color worst = _backdrop;
        double worstDegrees = 0;
        for (double degrees = -20; degrees <= 2; degrees += 0.25) {
          final double angle = _startAngle + degrees * math.pi / 180;
          for (double radius = _trackRadius - _strokeWidth;
              radius <= _trackRadius + _strokeWidth;
              radius += 0.5) {
            final Color pixel = _pixelAt(pixels, angle, radius);
            if (_warmth(pixel) > _warmth(worst)) {
              worst = pixel;
              worstDegrees = degrees;
            }
          }
        }

        // 12'lik pay yuvarlamaya ve kenar yumuşatmaya bırakıldı; leke oradayken
        // bu sayı 190'ın üstünde.
        expect(
          _warmth(worst),
          lessThan(12),
          reason: '$worstDegrees° konumunda sıcak piksel: $worst',
        );

        image.dispose();
      });
    }
  }

  test('iki uç da yuvarlak kalıyor', () async {
    // Kabul ölçütü bitiş ucunun yuvarlaklığını istiyor; başlangıç ucu da
    // prototipin `stroke-linecap="round"`u. İkisini de çiviliyoruz, yoksa
    // lekeyi ucu düzleştirerek "çözmek" testi yeşil bırakırdı.
    final ui.Image image = await _render(AppColors.dark(), 0.25);
    final ByteData pixels = (await image.toByteData())!;

    // Yuvarlak uç yarıçapı 4.5px; 2.5px ötesi hâlâ kapağın içinde, izin ise
    // yalnızca %7'lik grisi var.
    const double capProbe = 2.5 / _trackRadius;
    expect(
      _painted(_pixelAt(pixels, _startAngle - capProbe, _trackRadius)),
      isTrue,
      reason: 'başlangıç ucu düzleşmiş',
    );
    expect(
      _painted(_pixelAt(pixels, _startAngle + 2 * math.pi * 0.25 + capProbe, _trackRadius)),
      isTrue,
      reason: 'bitiş ucu düzleşmiş',
    );

    image.dispose();
  });
}
