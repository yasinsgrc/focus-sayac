import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/services/notifications/notification_service.dart';

/// `flutter_local_notifications` durum çubuğu ikonunu
/// `Resources.getIdentifier(name, "drawable", paket)` ile çözüyor
/// (`FlutterLocalNotificationsPlugin.java:855`) — **çıplak** kaynak adı
/// bekliyor. XML söz dizimi (`@drawable/ic_notification`) verilirse arama `0`
/// döner ve eklenti `PlatformException(invalid_icon)` fırlatır.
///
/// Bu istisna `main()` içinde `runApp()`tan **önceki** `await`te patlıyordu:
/// uygulama derleniyor, kuruluyor, ama hiç açılmıyordu. Analiz ve mevcut
/// bildirim testleri sahte bir `MethodChannel` ile koştuğu için hiçbiri bunu
/// göremedi — kaynağın gerçekten çözülüp çözülmediği yalnızca cihazda
/// belliydi. Bu test o boşluğu kapatıyor: `focus_palette_sync_test.dart` ile
/// aynı gerekçe, Dart tarafındaki bir dizenin Android kaynak ağacından
/// ayrışmasını yakalar.
void main() {
  /// Eklentinin aradığı ad; `res/drawable-*/<ad>.png` dosyalarıyla eşleşmeli.
  const String iconName = kNotificationIconResource;

  test('bildirim ikonu ciplak kaynak adi olarak veriliyor', () {
    expect(
      iconName.startsWith('@'),
      isFalse,
      reason: '`@drawable/...` bir XML basvurusu; getIdentifier bunu cozemez '
          've eklenti invalid_icon firlatir (uygulama acilmaz).',
    );
    expect(
      iconName.contains('/'),
      isFalse,
      reason: 'Kaynak adi tur/klasor oneki tasimamali, yalnizca dosya adi.',
    );
    expect(
      RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(iconName),
      isTrue,
      reason: 'Android kaynak adlari kucuk harf, rakam ve alt cizgi olabilir.',
    );
  });

  test('bildirim ikonu her yogunluk klasorunde mevcut', () {
    const List<String> buckets = <String>[
      'drawable-mdpi',
      'drawable-hdpi',
      'drawable-xhdpi',
      'drawable-xxhdpi',
      'drawable-xxxhdpi',
    ];

    for (final String bucket in buckets) {
      final File file = File('android/app/src/main/res/$bucket/$iconName.png');
      expect(
        file.existsSync(),
        isTrue,
        reason: '${file.path} yok - eklenti bu yogunluktaki cihazda ikonu '
            'cozemez ve acilista invalid_icon firlatir.',
      );
    }
  });
}
