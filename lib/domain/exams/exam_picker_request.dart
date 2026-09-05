import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sinav secicinin disaridan acilmasi icin tek yonlu sinyal.
///
/// Neden gerekli: Ekran 02 secicinin acilip acilmayacagini yalnizca
/// `initState` icinde, `CountdownScreen.autoOpenSheet` parametresinden
/// okuyor. Ana ekran widgetindan gelen `?pick=1` istegi ise uygulama zaten
/// geri sayim ekranindayken geliyor; `go_router` ayni konuma gidince State
/// nesnesi yeniden kurulmadigi icin parametre bir daha hic okunmuyordu ve
/// secici sessizce acilmiyordu.
///
/// Sayac her artisinda Ekran 02 seciciyi acar. Deger degil, DEGISIM anlamli:
/// arka arkaya iki istek de iki kez calisir.
final NotifierProvider<ExamPickerRequest, int> examPickerRequestProvider =
    NotifierProvider<ExamPickerRequest, int>(ExamPickerRequest.new);

class ExamPickerRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state = state + 1;
}
