import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'exam_json_models.dart';

/// SPEC.md §4 üç katmanlı sınav tarihi kaynağının 2. katmanı: uzak JSON
/// override. 24 saat önbelleklenir, ağ/format hatasında **sessizce** yerel
/// seed'e (`assets/data/exam_dates.json`, `AppDatabase.onCreate` ile zaten
/// yazılmış preset satırlar) düşer — kullanıcıya hata gösterilmez.
///
/// Henüz gerçek bir backend verilmedi; `remoteOverrideUrl` boşken bu servis
/// devreye girmez ve yerel seed veri geçerliliğini korur (`DECISIONS.md`
/// Faz 3 kararı). Gerçek bir uç nokta bağlanınca `--dart-define` ile
/// açılabilir, kod değişikliği gerekmez.
class ExamSourceService {
  ExamSourceService({
    required AppDatabase database,
    required SharedPreferences prefs,
    http.Client? httpClient,
  })  : _database = database,
        _prefs = prefs,
        _httpClient = httpClient ?? http.Client();

  static const String _lastFetchPrefsKey = 'exam_source_last_fetch_utc';
  static const Duration cacheTtl = Duration(hours: 24);
  static const String remoteOverrideUrl =
      String.fromEnvironment('EXAM_DATES_REMOTE_URL', defaultValue: '');

  final AppDatabase _database;
  final SharedPreferences _prefs;
  final http.Client _httpClient;

  /// Uygulama açılışında bir kez çağrılır. 24 saatlik önbellek dolmadıysa
  /// veya uzak URL tanımlı değilse ağa hiç çıkmaz.
  Future<void> syncIfNeeded({DateTime? now}) async {
    if (remoteOverrideUrl.isEmpty) {
      return;
    }

    final DateTime nowUtc = (now ?? DateTime.now()).toUtc();
    final String? lastFetchIso = _prefs.getString(_lastFetchPrefsKey);
    if (lastFetchIso != null) {
      final DateTime lastFetch = DateTime.parse(lastFetchIso);
      if (nowUtc.difference(lastFetch) < cacheTtl) {
        return;
      }
    }

    try {
      final http.Response response = await _httpClient
          .get(Uri.parse(remoteOverrideUrl))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return;
      }
      final Map<String, Object?> payload = jsonDecode(response.body) as Map<String, Object?>;
      final List<ExamJsonEntry> entries = parseExamJsonPayload(payload);
      for (final ExamJsonEntry entry in entries) {
        await _database.examDao.upsertPresetExam(
          name: entry.name,
          subtitle: entry.subtitle,
          dateUtc: entry.dateUtc,
          timeOfDay: entry.timeOfDay,
          accentRole: entry.accentRole,
          verifiedAt: entry.verifiedAt,
        );
      }
      await _prefs.setString(_lastFetchPrefsKey, nowUtc.toIso8601String());
    } catch (_) {
      // SPEC.md §4: "Hata/ağ yoksa sessizce 3'e düş" — yerel seed korunur,
      // kullanıcıya hiçbir hata gösterilmez.
    }
  }
}
