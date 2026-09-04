import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../domain/widgets/home_widget_snapshot.dart';

/// Ana ekran widget'larının Kotlin tarafıyla tek temas noktası. Anlık
/// görüntüyü paylaşılan `SharedPreferences`e yazar, sonra beş sağlayıcıyı da
/// yeniden çizdirir.
class HomeWidgetService {
  const HomeWidgetService();

  /// Kotlin sağlayıcılarının paketi — `AndroidManifest.xml`'deki `receiver`
  /// adlarıyla birebir aynı olmak zorunda.
  static const String androidWidgetPackage = 'com.focussayac.focussayac.widget';

  /// Beş widget'ın sağlayıcı sınıfları. Yeni bir widget eklendiğinde bu liste
  /// ve manifest birlikte güncellenir.
  static const List<String> providerClassNames = <String>[
    'RingWidgetProvider',
    'StripWidgetProvider',
    'StreakWidgetProvider',
    'QuickFocusWidgetProvider',
    'PanoramaWidgetProvider',
  ];

  /// Anlık görüntüyü yazar ve widget'ları tazeler.
  ///
  /// Platform hatası uygulamayı düşürmez: widget güncellemesi yardımcı bir
  /// yüzey, uygulamanın kendisi değil. Hata yutulmuyor — `debugPrint` ile
  /// yüzeye çıkarılıyor ki sessizce kaybolmasın.
  Future<void> push(HomeWidgetSnapshot snapshot) async {
    try {
      final Map<String, Object> payload = snapshot.toPayload();
      for (final MapEntry<String, Object> entry in payload.entries) {
        await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
      }
      for (final String className in providerClassNames) {
        await HomeWidget.updateWidget(
          qualifiedAndroidName: '$androidWidgetPackage.$className',
        );
      }
    } on PlatformException catch (error, stackTrace) {
      debugPrint('HomeWidgetService.push başarısız: $error\n$stackTrace');
    } on MissingPluginException catch (error) {
      // Widget eklentisi olmayan bir host'ta (ör. birim testi) sessiz geçilir.
      debugPrint('HomeWidgetService.push atlandı: $error');
    }
  }
}
