import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/domain/exams/exam_picker_request.dart';

/// Ana ekran widgetindan gelen "sinav sec" sinyali. Deger degil DEGISIM
/// anlamli oldugu icin sayacin her istekte artmasi sart: iki ardisik istek
/// seciciyi iki kez acmali.
void main() {
  test('her istek sayaci artirir', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(examPickerRequestProvider), 0);

    container.read(examPickerRequestProvider.notifier).request();
    expect(container.read(examPickerRequestProvider), 1);

    container.read(examPickerRequestProvider.notifier).request();
    expect(container.read(examPickerRequestProvider), 2);
  });
}
