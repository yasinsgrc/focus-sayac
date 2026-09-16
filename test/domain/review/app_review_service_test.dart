import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focussayac/domain/review/app_review_service.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// Sabit bir "şimdi": seans satırları testin gerçek saatine bağlı kalmasın.
final DateTime _now = DateTime.utc(2026, 3, 1, 20);

/// `InAppReview` yalnızca özel bir kurucuya sahip (`InAppReview._`), bu yüzden
/// `extends` değil `implements`. Platform kanalı olmadığı için gerçek nesne
/// testte her zaman `MissingPluginException` atardı ve "istem gösterildi"
/// dalına hiç girilemezdi.
class _FakeInAppReview implements InAppReview {
  _FakeInAppReview({this.available = true});

  final bool available;
  int requestReviewCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async {
    requestReviewCalls++;
  }

  @override
  Future<void> openStoreListing({String? appStoreId, String? microsoftStoreId}) async {}
}

Future<void> _completeFocusSessions(AppDatabase database, int count) async {
  for (int i = 0; i < count; i++) {
    final DateTime startedAt = _now.subtract(Duration(minutes: 30 * (count - i)));
    final int id = await database.pomodoroSessionDao.startSession(
      examId: null,
      type: SessionType.focus,
      startedAt: startedAt,
      plannedDurationSec: 25 * 60,
    );
    await database.pomodoroSessionDao.finishSession(
      id: id,
      completed: true,
      endedAt: startedAt.add(const Duration(minutes: 25)),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late SharedPreferences prefs;

  AppReviewService serviceWith(_FakeInAppReview review) {
    return AppReviewService(
      prefs: prefs,
      sessionDao: database.pomodoroSessionDao,
      review: review,
    );
  }

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.appSettingsDao.getSettings();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await database.close();
  });

  // Dönüş değeri interstitial'ın bastırma kapısını besliyor
  // (`InterstitialManager.maybeShowOnCycleComplete`): ikisi de 3. tamamlanan
  // seansta düşüyor ve aynı anda iki tam ekran istem çıkamaz.
  test('eşik altında istem gösterilmiyor ve false dönüyor', () async {
    final _FakeInAppReview review = _FakeInAppReview();
    final AppReviewService service = serviceWith(review);

    await _completeFocusSessions(database, 2);

    expect(await service.requestIfEligible(), isFalse);
    expect(review.requestReviewCalls, 0);
  });

  test('3. tamamlanan seansta istem gösteriliyor ve true dönüyor', () async {
    final _FakeInAppReview review = _FakeInAppReview();
    final AppReviewService service = serviceWith(review);

    await _completeFocusSessions(database, 3);

    expect(await service.requestIfEligible(), isTrue);
    expect(review.requestReviewCalls, 1);
    expect(prefs.getBool(AppReviewService.requestedPrefsKey), isTrue);
  });

  test('ikinci çağrıda istem yok ve false dönüyor', () async {
    final _FakeInAppReview review = _FakeInAppReview();
    final AppReviewService service = serviceWith(review);

    await _completeFocusSessions(database, 3);
    expect(await service.requestIfEligible(), isTrue);

    await _completeFocusSessions(database, 3);
    expect(await service.requestIfEligible(), isFalse);
    expect(review.requestReviewCalls, 1);
  });

  // Eklenti yokken `false` dönmesi kritik: `true` dönseydi hiç gösterilmemiş
  // bir istem interstitial'ı boşuna bastırırdı.
  test('eklenti kullanılamıyorsa false dönüyor ve bayrak yazılmıyor', () async {
    final _FakeInAppReview review = _FakeInAppReview(available: false);
    final AppReviewService service = serviceWith(review);

    await _completeFocusSessions(database, 3);

    expect(await service.requestIfEligible(), isFalse);
    expect(review.requestReviewCalls, 0);
    expect(prefs.getBool(AppReviewService.requestedPrefsKey), isNull);
  });
}
