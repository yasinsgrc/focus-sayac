import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focussayac/domain/widgets/home_widget_snapshot.dart';
import 'package:focussayac/services/widgets/home_widget_service.dart';

/// `HomeWidgetService` platform kanalina ne gonderiyor sorusunun testi.
/// Kanal sahte bir isleyiciyle yakalaniyor; gercek bir Android widgetina
/// ihtiyac yok.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('home_widget');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  HomeWidgetSnapshot buildSnapshot() {
    return HomeWidgetSnapshot.noExam(
      streak: 4,
      todayMinutes: 50,
      weeklyMinutes: const <int>[0, 0, 25, 25, 50, 0, 50],
      sessionActive: true,
      updatedAtUtc: DateTime.utc(2026, 6, 1),
    );
  }

  Iterable<MethodCall> callsNamed(String name) =>
      calls.where((MethodCall call) => call.method == name);

  test('sozlesmedeki her anahtari tek tek yazar', () async {
    await const HomeWidgetService().push(buildSnapshot());

    final Set<String> written = callsNamed('saveWidgetData')
        .map((MethodCall call) => (call.arguments as Map<Object?, Object?>)['id'] as String)
        .toSet();
    expect(written, HomeWidgetSnapshot.payloadKeys.toSet());
  });

  test('bes saglayicinin hepsini tazeler', () async {
    await const HomeWidgetService().push(buildSnapshot());

    final List<String> updated = callsNamed('updateWidget')
        .map((MethodCall call) =>
            (call.arguments as Map<Object?, Object?>)['qualifiedAndroidName'] as String)
        .toList();

    expect(
      updated,
      HomeWidgetService.providerClassNames
          .map((String name) => '${HomeWidgetService.androidWidgetPackage}.$name')
          .toList(),
    );
  });

  test('saglayici adlari manifestteki paketle esler', () {
    // Ad bir harf bile kaysa `updateWidget` sessizce hicbir sey yapmaz;
    // widget ekranda bayat kalir ve hata da gorunmez.
    expect(HomeWidgetService.androidWidgetPackage, 'com.focussayac.focussayac.widget');
    expect(HomeWidgetService.providerClassNames, hasLength(5));
  });

  test('platform hatasi cagirana sizmaz', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      throw PlatformException(code: 'boom');
    });

    // Widget guncellemesi yardimci bir yuzey; basarisiz olmasi uygulamayi
    // dusurmemeli.
    await expectLater(const HomeWidgetService().push(buildSnapshot()), completes);
  });
}
