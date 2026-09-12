# Meşale Kademe Avatarı — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Seans içinde büyüyüp sıfırlanan meşaleyi, kümülatif odak saatine bağlı 10 kademeli kalıcı bir avatara dönüştürmek; kademeyi ve sonraki kademeye kalan saati Ekran 04'te ve yeni bir ana ekran widget'ında göstermek.

**Architecture:** Saf bir merdiven (`lib/domain/flame/flame_tier.dart`) mevcut `FocusStats.cumulativeSeconds`'ten kademe türetir. `FlameWidget` iki ayrı eksenle parametrize edilir: kademe (boyut/süsleme, kalıcı) ve seans (parlaklık/titreşim, geçici). Merdiven Kotlin'de bir kez daha tanımlanır (widget çizimi için) ve bir senkron testiyle Dart'a çivilenir — palet için kurulmuş emsalin aynısı.

**Tech Stack:** Flutter 3 / Dart, Riverpod 3.1, drift, `home_widget`, Android RemoteViews + Canvas (Kotlin), ARB l10n.

**Tasarım belgesi:** `docs/superpowers/specs/2026-09-12-mesale-kademe-avatari-design.md`
**Dönüş noktası:** `git checkout mesale-tasarim-onayi`

---

## Dosya haritası

| Dosya | Durum | Sorumluluk |
|---|---|---|
| `lib/domain/flame/flame_tier.dart` | yeni | Merdiven verisi + `flameTierFor()`. Saf, IO yok. |
| `lib/domain/flame/flame_providers.dart` | yeni | `flameTierProvider`. |
| `lib/core/widgets/flame_widget.dart` | taşındı + değişti | `features/focus_session/widgets/`ten taşınır; `tier`/`intensity` API'si. |
| `lib/features/focus_session/focus_session_screen.dart` | değişir | Yeni API'ye bağlanır (satır 447). |
| `lib/features/badges/widgets/flame_avatar_card.dart` | yeni | Ekran 04 kahraman kartı. |
| `lib/features/badges/badges_screen.dart` | değişir | Kartı grid'in üstüne ekler. |
| `lib/l10n/app_tr.arb` | değişir | 10 kademe adı + yardımcı metinler. |
| `lib/domain/widgets/home_widget_snapshot.dart` | değişir | `cumulativeFocusSeconds` anahtarı. |
| `lib/services/widgets/home_widget_sync.dart` | değişir | Alanı doldurur. |
| `lib/services/widgets/widget_launch_handler.dart` | değişir | `/badges` rotası. |
| `android/.../widget/FlameTierLadder.kt` | yeni | Merdivenin Kotlin aynası. |
| `android/.../widget/FlameRenderer.kt` | yeni | Kademe alevi bitmap'i. |
| `android/.../widget/FlameWidgetProvider.kt` | yeni | Altıncı sağlayıcı. |
| `android/.../widget/FocusWidgetSnapshot.kt` | değişir | Yeni alanı okur. |
| `android/.../widget/BaseFocusWidgetProvider.kt` | değişir | `PROVIDERS` listesi. |
| `android/.../widget/WidgetRoutes.kt` | değişir | `BADGES`. |
| `android/app/src/main/res/layout/widget_flame.xml` | yeni | 2×2 yerleşim. |
| `android/app/src/main/res/xml/widget_flame_info.xml` | yeni | Widget meta. |
| `android/app/src/main/res/drawable/widget_preview_flame.xml` | yeni | Seçici önizlemesi. |
| `android/app/src/main/res/values/strings.xml` | değişir | Widget metinleri. |
| `android/app/src/main/AndroidManifest.xml` | değişir | Receiver. |

**Fazlar:** A (Task 1–3, domain) → B (Task 4–5, çizim) → C (Task 6–8, Ekran 04) → D (Task 9–11, widget) → E (Task 12–14, doğrulama ve belgeler).

Her faz kendi başına çalışır ve test edilir. A bitince hiçbir ekran değişmez ama merdiven kullanılabilirdir; B bitince odak ekranı kalıcı alevi gösterir; C bitince kimlik yüzeyi hazırdır; D widget'ı ekler.

---

## Task 1: Merdiven ve `flameTierFor`

**Files:**
- Create: `lib/domain/flame/flame_tier.dart`
- Test: `test/domain/flame/flame_tier_test.dart`

- [ ] **Step 1: Write the failing test**

`test/domain/flame/flame_tier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/flame/flame_tier.dart';

/// Saat -> saniye. Merdivenin tamamı saat cinsinden tanımlı, girdi ise saniye.
int _h(num hours) => (hours * 3600).round();

void main() {
  group('merdiven biçimi', () {
    test('10 kademe var, indeksler 1..10', () {
      expect(kFlameTierLadder.length, 10);
      expect(
        kFlameTierLadder.map((FlameTier t) => t.index),
        <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
    });

    test('eşikler kesin artan ve K1 sıfırdan başlıyor', () {
      expect(kFlameTierLadder.first.thresholdHours, 0);
      for (int i = 1; i < kFlameTierLadder.length; i++) {
        expect(
          kFlameTierLadder[i].thresholdHours,
          greaterThan(kFlameTierLadder[i - 1].thresholdHours),
          reason: 'K${i + 1} eşiği K$i ile aynı ya da altında',
        );
      }
    });

    test('ölçek 0.35ten 1.0a kesin artıyor', () {
      expect(kFlameTierLadder.first.scale, 0.35);
      expect(kFlameTierLadder.last.scale, 1.0);
      for (int i = 1; i < kFlameTierLadder.length; i++) {
        expect(kFlameTierLadder[i].scale, greaterThan(kFlameTierLadder[i - 1].scale));
      }
    });
  });

  group('flameTierFor', () {
    test('geçmiş boşken K1', () {
      final FlameTierStatus status = flameTierFor(0);
      expect(status.tier.index, 1);
      expect(status.cumulativeHours, 0);
      expect(status.nextTier!.index, 2);
      expect(status.hoursRemaining, 1);
      expect(status.ratioInTier, 0);
    });

    test('tam eşikte kademe atlıyor', () {
      expect(flameTierFor(_h(10)).tier.index, 4);
      expect(flameTierFor(_h(50)).tier.index, 6);
      expect(flameTierFor(_h(100)).tier.index, 7);
      expect(flameTierFor(_h(250)).tier.index, 9);
    });

    test('eşiğin bir saniye altı hâlâ önceki kademe', () {
      expect(flameTierFor(_h(10) - 1).tier.index, 3);
      expect(flameTierFor(_h(400) - 1).tier.index, 9);
    });

    test('saat aşağı yuvarlanıyor — 99sa 59dk hâlâ K6', () {
      final FlameTierStatus status = flameTierFor(_h(99) + 59 * 60);
      expect(status.tier.index, 6);
      expect(status.cumulativeHours, 99);
      expect(status.hoursRemaining, 1);
    });

    test('kademe içi oran iki uçta doğru', () {
      // K6 50sa, K7 100sa -> 75sa tam orta.
      expect(flameTierFor(_h(75)).ratioInTier, closeTo(0.5, 1e-9));
      expect(flameTierFor(_h(50)).ratioInTier, 0);
      expect(flameTierFor(_h(99)).ratioInTier, closeTo(0.98, 1e-9));
    });

    test('kalan saat sonraki eşiğe olan fark', () {
      final FlameTierStatus status = flameTierFor(_h(62));
      expect(status.tier.index, 6);
      expect(status.nextTier!.thresholdHours, 100);
      expect(status.hoursRemaining, 38);
    });

    test('en üst kademede sonraki yok', () {
      final FlameTierStatus status = flameTierFor(_h(400));
      expect(status.tier.index, 10);
      expect(status.nextTier, isNull);
      expect(status.hoursRemaining, isNull);
      expect(status.ratioInTier, 1);
      expect(status.isTopTier, isTrue);
    });

    test('en üst kademenin çok üstünde de K10, taşma yok', () {
      final FlameTierStatus status = flameTierFor(_h(5000));
      expect(status.tier.index, 10);
      expect(status.ratioInTier, 1);
      expect(status.cumulativeHours, 5000);
    });

    test('negatif girdi K1e düşüyor, patlamıyor', () {
      // Savunma amaçlı: veri bozulsa bile ekran çizilmeli.
      expect(flameTierFor(-1).tier.index, 1);
      expect(flameTierFor(-1).cumulativeHours, 0);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/flame/flame_tier_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:focussayac/domain/flame/flame_tier.dart'".

- [ ] **Step 3: Write the implementation**

`lib/domain/flame/flame_tier.dart`:

```dart
/// Meşale avatarının tek bir kademesi. Görsel parametreler (ölçek, süsleme)
/// burada duruyor çünkü Kotlin tarafındaki widget da aynı sayıları çiziyor ve
/// `test/android/flame_tier_sync_test.dart` iki kopyayı karşılaştırıyor.
///
/// Palet duraklarının **burada olmamasının** sebebi: gradyan açık/koyu temaya
/// göre dallanıyor ve bu bir çizim kararı — `FlameWidget` içinde kalıyor,
/// bugünkü `_darkBody`/`_lightBody` ayrımının aynısı.
class FlameTier {
  const FlameTier({
    required this.index,
    required this.thresholdHours,
    required this.scale,
    required this.emberBase,
    required this.sparkCount,
    required this.haloOpacity,
  });

  /// 1..10. Kullanıcıya gösterilen kademe numarası, liste konumu değil.
  final int index;

  /// Bu kademeye girmek için gereken kümülatif tamamlanmış odak saati.
  final int thresholdHours;

  /// Yüzeyin verdiği kutuya oranı (0.35 → 1.0). Mutlak piksel yok: odak
  /// ekranı 98px, rozet kartı 120px, widget ~64dp kutu veriyor.
  final double scale;

  /// Alevin altında kor yatağı çizilir mi.
  final bool emberBase;

  /// Alevin üstünde yükselen kıvılcım parçacığı sayısı.
  final int sparkCount;

  /// Alevin arkasındaki hâlenin opaklığı; 0 ise hâle çizilmez.
  final double haloOpacity;
}

/// Kademe merdiveni. **Yayınlandıktan sonra eşikler değiştirilemez** —
/// kademe düşüren bir değişiklik kazanılmış kimliği geri almak olur
/// (`BadgeKeys` ile aynı kısıt).
///
/// Eşikler `badge_rules.dart`'ın saat merdivenini (10/50/100/250) **içerir**:
/// K4, K6, K7 ve K9 aynı anda bir rozet de açar. Aradaki kademelerin rozeti
/// yok, sessizce geçilir. Hizalamayı `flame_tier_test.dart` çiviliyor.
///
/// Aralıklar erken sık, geç seyrek: ilk 10 saatte dört kademe (yeni kullanıcı
/// hemen ilerleme görür), 100 saatten sonra üç kademe (eksen tükenmez).
const List<FlameTier> kFlameTierLadder = <FlameTier>[
  FlameTier(index: 1, thresholdHours: 0, scale: 0.35, emberBase: false, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 2, thresholdHours: 1, scale: 0.42, emberBase: false, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 3, thresholdHours: 3, scale: 0.50, emberBase: false, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 4, thresholdHours: 10, scale: 0.58, emberBase: true, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 5, thresholdHours: 25, scale: 0.65, emberBase: true, sparkCount: 0, haloOpacity: 0),
  FlameTier(index: 6, thresholdHours: 50, scale: 0.72, emberBase: true, sparkCount: 2, haloOpacity: 0),
  FlameTier(index: 7, thresholdHours: 100, scale: 0.80, emberBase: true, sparkCount: 3, haloOpacity: 0),
  FlameTier(index: 8, thresholdHours: 175, scale: 0.87, emberBase: true, sparkCount: 3, haloOpacity: 0.18),
  FlameTier(index: 9, thresholdHours: 250, scale: 0.94, emberBase: true, sparkCount: 4, haloOpacity: 0.26),
  FlameTier(index: 10, thresholdHours: 400, scale: 1.00, emberBase: true, sparkCount: 5, haloOpacity: 0.34),
];

/// Bir anın kademe durumu — kart, odak ekranı ve widget aynı nesneyi okur.
class FlameTierStatus {
  const FlameTierStatus({
    required this.tier,
    required this.nextTier,
    required this.hoursRemaining,
    required this.ratioInTier,
    required this.cumulativeHours,
  });

  final FlameTier tier;

  /// En üst kademede `null`.
  final FlameTier? nextTier;

  /// Sonraki eşiğe kalan tam saat; en üst kademede `null`. Null olması
  /// bilinçli: 0 yazsaydı kart "sonraki kademeye 0 saat" diye yalan kurardı.
  final int? hoursRemaining;

  /// 0–1, bu kademe içindeki ilerleme. En üst kademede 1.
  final double ratioInTier;

  /// Tüm zamanların tamamlanmış odak saati (aşağı yuvarlanmış).
  final int cumulativeHours;

  bool get isTopTier => nextTier == null;
}

/// Saf hesaplayıcı. [cumulativeSeconds] `FocusStats.cumulativeSeconds`tir.
///
/// Saat aşağı yuvarlanır — `badge_rules.dart`'taki `totalPlannedSeconds ~/ 3600`
/// ile **aynı** kural. İki merdivenin eşiklerde birlikte tetiklenmesi buna
/// bağlı; `floor(sn/3600) >= E` ile `sn >= E*3600` aynı kümeyi veriyor.
FlameTierStatus flameTierFor(int cumulativeSeconds) {
  final int hours = cumulativeSeconds <= 0 ? 0 : cumulativeSeconds ~/ 3600;

  int position = 0;
  for (int i = 1; i < kFlameTierLadder.length; i++) {
    if (hours >= kFlameTierLadder[i].thresholdHours) position = i;
  }

  final FlameTier tier = kFlameTierLadder[position];
  final FlameTier? next =
      position + 1 < kFlameTierLadder.length ? kFlameTierLadder[position + 1] : null;

  if (next == null) {
    return FlameTierStatus(
      tier: tier,
      nextTier: null,
      hoursRemaining: null,
      ratioInTier: 1,
      cumulativeHours: hours,
    );
  }

  final int span = next.thresholdHours - tier.thresholdHours;
  return FlameTierStatus(
    tier: tier,
    nextTier: next,
    hoursRemaining: next.thresholdHours - hours,
    ratioInTier: ((hours - tier.thresholdHours) / span).clamp(0.0, 1.0),
    cumulativeHours: hours,
  );
}
```

> **Sıra notu:** `FlameTier.name()` metodu bu adımda **yazılmıyor** — ARB
> anahtarları henüz yok. Task 6 ekliyor.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/flame/flame_tier_test.dart`
Expected: PASS — 12 test.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/flame/flame_tier.dart test/domain/flame/flame_tier_test.dart
git commit -m "Kademe merdiveni ve flameTierFor"
```

---

## Task 2: Rozet hizalaması ve tek kaynak testi

Merdivenin tek gerçek riski, saat rozetlerinden sapmasıdır. Bu görev onu testle çiviler; üretim kodu değişmez.

**Files:**
- Modify: `test/domain/flame/flame_tier_test.dart` (importlar + `main()` sonu)

- [ ] **Step 1: Write the test**

Dosya başındaki importlara ekle:

```dart
import 'package:focussayac/domain/badges/badge_definition.dart';
import 'package:focussayac/domain/badges/badge_rules.dart';
import 'package:focussayac/domain/stats/focus_stats.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';
```

`main()` içine, mevcut grupların altına:

```dart
  group('rozet merdiveniyle hizalama', () {
    /// `badge_rules.dart`taki dört saat rozetinin eşikleri. Buraya elle
    /// yazılmıyor, kuralın kendisinden okunuyor: eşik orada değişirse bu test
    /// yeni değeri görür ve merdiven hizasızsa düşer.
    final Map<String, int> badgeHourTargets = <String, int>{
      for (final MapEntry<String, BadgeProgress> entry
          in evaluateBadgeProgress(completedFocusSessions: const <PomodoroSession>[]).entries)
        if (const <String>{
          BadgeKeys.tenHours,
          BadgeKeys.fiftyHours,
          BadgeKeys.hundredHours,
          BadgeKeys.twoFiftyHours,
        }.contains(entry.key))
          entry.key: entry.value.target,
    };

    test('dört saat rozetinin hepsi bir kademe eşiğine düşüyor', () {
      final Set<int> ladderThresholds =
          kFlameTierLadder.map((FlameTier t) => t.thresholdHours).toSet();

      expect(badgeHourTargets.length, 4, reason: 'saat rozeti sayısı değişmiş');
      badgeHourTargets.forEach((String key, int target) {
        expect(
          ladderThresholds,
          contains(target),
          reason: '$key rozeti ${target}sa eşiğinde ama merdivende o basamak yok',
        );
      });
    });

    test('rozetin açıldığı anda kademe de atlanıyor', () {
      badgeHourTargets.forEach((String key, int target) {
        final FlameTierStatus atThreshold = flameTierFor(target * 3600);
        final FlameTierStatus justBefore = flameTierFor(target * 3600 - 1);
        expect(
          atThreshold.tier.index,
          justBefore.tier.index + 1,
          reason: '$key eşiğinde ($target sa) kademe atlamıyor',
        );
      });
    });
  });

  group('tek kaynak — kademe ve rozet aynı saati sayıyor', () {
    /// [count] saatlik tamamlanmış odak geçmişi; günde üç adet 60 dakikalık
    /// seans. Dağılımın önemi yok, toplamın var.
    List<PomodoroSession> hours(int count) => <PomodoroSession>[
          for (int i = 0; i < count; i++)
            PomodoroSession(
              id: i + 1,
              type: SessionType.focus,
              startedAt: DateTime.utc(2026, 3, 1 + i ~/ 3, 6 + i % 3),
              plannedDurationSec: 3600,
              completed: true,
              breakExtensions: 0,
            ),
        ];

    test('FocusStats ve badge_rules aynı listede aynı saati veriyor', () {
      for (final int count in <int>[0, 1, 9, 10, 62, 100, 251]) {
        final List<PomodoroSession> sessions = hours(count);

        final int statsHours = flameTierFor(
          calculateFocusStats(sessions: sessions, nowUtc: DateTime.utc(2026, 6, 1)).cumulativeSeconds,
        ).cumulativeHours;

        final int badgeHours =
            evaluateBadgeProgress(completedFocusSessions: sessions)[BadgeKeys.hundredHours]!.current;

        expect(statsHours, badgeHours, reason: '$count saatlik geçmişte iki sayaç ayrışıyor');
      }
    });
  });
```

- [ ] **Step 2: Run test — it should pass immediately**

Run: `flutter test test/domain/flame/flame_tier_test.dart`
Expected: PASS. Bu bir karakterizasyon testi — Task 1'in merdiveni zaten hizalı olduğu için yeşil geçmeli.

- [ ] **Step 3: Prove the test can fail**

`kFlameTierLadder`'da `thresholdHours: 100` değerini geçici olarak `110` yap.

Run: `flutter test test/domain/flame/flame_tier_test.dart`
Expected: FAIL — "hundredHours rozeti 100sa eşiğinde ama merdivende o basamak yok".

Değeri `100`'e geri al ve testi tekrar çalıştır.
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add test/domain/flame/flame_tier_test.dart
git commit -m "Kademe-rozet hizalamasini ve tek saat kaynagini testle civile"
```

---

## Task 3: `flameTierProvider`

**Files:**
- Create: `lib/domain/flame/flame_providers.dart`
- Test: `test/domain/flame/flame_providers_test.dart`

- [ ] **Step 1: Write the failing test**

`test/domain/flame/flame_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/flame/flame_providers.dart';
import 'package:focussayac/domain/flame/flame_tier.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

/// [count] saatlik tamamlanmış odak geçmişi.
List<PomodoroSession> _hours(int count) => <PomodoroSession>[
      for (int i = 0; i < count; i++)
        PomodoroSession(
          id: i + 1,
          type: SessionType.focus,
          startedAt: DateTime.utc(2026, 3, 1 + i ~/ 3, 6 + i % 3),
          plannedDurationSec: 3600,
          completed: true,
          breakExtensions: 0,
        ),
    ];

/// `Stream.value` tek abonelikli: yayın denetleyicisinin aksine Riverpod geç
/// abone olsa da olayı düşürmüyor (`streak_protection_badge_test.dart` tuzağı).
ProviderContainer _containerWith(List<PomodoroSession> sessions) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      allSessionsProvider.overrideWith((Ref ref) => Stream<List<PomodoroSession>>.value(sessions)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('geçmiş boşken K1', () async {
    final ProviderContainer container = _containerWith(const <PomodoroSession>[]);
    await container.read(allSessionsProvider.future);
    expect(container.read(flameTierProvider).tier.index, 1);
  });

  test('62 saatlik geçmiş K6, sonraki kademeye 38 saat', () async {
    final ProviderContainer container = _containerWith(_hours(62));
    await container.read(allSessionsProvider.future);

    final FlameTierStatus status = container.read(flameTierProvider);
    expect(status.tier.index, 6);
    expect(status.cumulativeHours, 62);
    expect(status.hoursRemaining, 38);
  });

  test('akış yüklenirken K1e düşüyor, patlamıyor', () {
    // `allSessionsProvider` ilk değerini yayınlamadan okunursa ekran yine de
    // çizilebilmeli — `focusStatsProvider`ın `?? const []` davranışı.
    final ProviderContainer container = _containerWith(_hours(62));
    expect(container.read(flameTierProvider).tier.index, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/flame/flame_providers_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:focussayac/domain/flame/flame_providers.dart'".

- [ ] **Step 3: Write the implementation**

`lib/domain/flame/flame_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stats/stats_providers.dart';
import 'flame_tier.dart';

/// Meşale avatarının o anki kademesi. `focusStatsProvider`ı okuyor, yani
/// Ekran 04, Ekran 03 ve widget anlık görüntüsü aynı `allSessionsProvider`
/// akışından besleniyor — üç yüzeyin sayısı birbirinden sapamaz.
final Provider<FlameTierStatus> flameTierProvider = Provider<FlameTierStatus>((Ref ref) {
  return flameTierFor(ref.watch(focusStatsProvider).cumulativeSeconds);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/flame/`
Expected: PASS — Task 1, 2, 3'ün tüm testleri.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/flame/flame_providers.dart test/domain/flame/flame_providers_test.dart
git commit -m "flameTierProvider"
```

---

## Task 4: `FlameWidget` — taşıma ve iki eksenli API

Bu görevin tek kritik davranışı: **seans yoğunluğu boyutu değiştirmez.**

**Files:**
- Create: `lib/core/widgets/flame_widget.dart`
- Delete: `lib/features/focus_session/widgets/flame_widget.dart`
- Test: `test/core/widgets/flame_widget_test.dart`

- [ ] **Step 1: Write the failing test**

`test/core/widgets/flame_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/theme/app_theme.dart';
import 'package:focussayac/core/widgets/flame_widget.dart';
import 'package:focussayac/domain/flame/flame_tier.dart';

const double _kBox = 98;

Future<void> _pump(
  WidgetTester tester, {
  required FlameTier tier,
  double intensity = 0,
  bool flickering = false,
  bool desaturated = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Center(
          child: FlameWidget(
            tier: tier,
            intensity: intensity,
            flickering: flickering,
            desaturated: desaturated,
            boxHeight: _kBox,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Kademe ölçeğini taşıyan **en dıştaki** `Transform` — titreşim dönüşümü
/// içeride, kare kare değişen o.
double _tierScale(WidgetTester tester) {
  final Transform outer = tester
      .widgetList<Transform>(find.descendant(
        of: find.byType(FlameWidget),
        matching: find.byType(Transform, skipOffstage: false),
      ))
      .first;
  return outer.transform.getMaxScaleOnAxis();
}

void main() {
  final FlameTier k1 = kFlameTierLadder.first;
  final FlameTier k6 = kFlameTierLadder[5];
  final FlameTier k10 = kFlameTierLadder.last;

  testWidgets('kademe ölçeği uygulanıyor', (WidgetTester tester) async {
    await _pump(tester, tier: k1);
    expect(_tierScale(tester), closeTo(k1.scale, 1e-6));

    await _pump(tester, tier: k10);
    expect(_tierScale(tester), closeTo(k10.scale, 1e-6));
  });

  testWidgets('seans yoğunluğu BOYUTU değiştirmiyor', (WidgetTester tester) async {
    // Kalıcılık vaadinin tamamı bu testte: iki eksen ayrı kanallarda.
    await _pump(tester, tier: k6, intensity: 0);
    final double resting = _tierScale(tester);

    await _pump(tester, tier: k6, intensity: 1);
    expect(_tierScale(tester), closeTo(resting, 1e-6));
  });

  testWidgets('yüksek kademe düşük kademeden büyük', (WidgetTester tester) async {
    await _pump(tester, tier: k1);
    final double small = _tierScale(tester);
    await _pump(tester, tier: k10);
    expect(_tierScale(tester), greaterThan(small));
  });

  testWidgets('flickering false iken titreşim tikleyicisi çalışmıyor',
      (WidgetTester tester) async {
    // `pumpAndSettle` sonsuz tekrarlı bir animasyonda zaman aşımına düşer;
    // düşmemesi tikleyicinin gerçekten durduğunu kanıtlıyor.
    await _pump(tester, tier: k6, flickering: false);
    await tester.pumpAndSettle();
    expect(find.byType(FlameWidget), findsOneWidget);
  });

  testWidgets('desaturated alevi ColorFiltered ile soluyor', (WidgetTester tester) async {
    await _pump(tester, tier: k6, desaturated: true);
    expect(
      find.descendant(of: find.byType(FlameWidget), matching: find.byType(ColorFiltered)),
      findsOneWidget,
    );
  });

  testWidgets('iki RepaintBoundary korunuyor', (WidgetTester tester) async {
    // SPEC.md §6 kural 5 / DECISIONS.md:811 — dıştaki 72px sayacı ayırıyor,
    // içteki Transformu bileşikleştiriyor.
    await _pump(tester, tier: k6, flickering: true);
    expect(
      find.descendant(of: find.byType(FlameWidget), matching: find.byType(RepaintBoundary)),
      findsAtLeastNWidgets(2),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/widgets/flame_widget_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:focussayac/core/widgets/flame_widget.dart'".

- [ ] **Step 3: Write the implementation**

`lib/core/widgets/flame_widget.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/flame/flame_tier.dart';

/// Meşale avatarı. **İki ayrı eksen, ayrı kanallar:**
///
/// - **Kademe** (kalıcı): boyut oranı, kor yatağı, kıvılcımlar, hâle.
///   Kümülatif odak saatinden gelir, asla küçülmez.
/// - **Seans** (geçici): çekirdek parlaklığı, titreşim genliği, kıvılcım
///   yoğunluğu. Seans bitince alev kademenin dinlenme hâline döner.
///
/// Seans [intensity]si **boyutu değiştirmiyor**. Sebep: K9→K10 arası oran
/// farkı %6; seans şişmesi eklenseydi iki eksen birbirine karışır, "kademe
/// atladım mı?" sorusu belirsizleşirdi.
///
/// Titreşimin sayısal keyframe değerleri prototipte yok (`_ds_bundle.js`
/// içinde derlenmiş); sinüs tabanlı salınım + gerilme + eğim olarak
/// yorumlandı (SPEC.md §0 kural 5, DECISIONS.md:272).
class FlameWidget extends StatefulWidget {
  const FlameWidget({
    required this.tier,
    required this.boxHeight,
    this.intensity = 0,
    this.flickering = false,
    this.desaturated = false,
    super.key,
  });

  final FlameTier tier;

  /// Yüzeyin verdiği taban ölçü: odak ekranı 98, rozet kartı 120, widget ~64.
  /// Kademe oranı bunun içinde uygulanır.
  final double boxHeight;

  /// Seans ilerlemesi 0→1. Yalnızca parlaklık/titreşim/kıvılcım kanallarına
  /// bağlı.
  final double intensity;

  /// Titreşim tikleyicisi çalışsın mı. Duraklatılmış seansta ve seans dışı
  /// yüzeylerde `false` — süresiz açık kalabilen bir ekranda saniyede 60 kare
  /// çizmenin sebebi yok (DECISIONS.md:816).
  final bool flickering;

  /// Duraklatılmış seans: doygunluk 0 (SPEC.md §5.5).
  final bool desaturated;

  @override
  State<FlameWidget> createState() => _FlameWidgetState();
}

class _FlameWidgetState extends State<FlameWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _flick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void initState() {
    super.initState();
    _syncFlick();
  }

  @override
  void didUpdateWidget(FlameWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFlick();
  }

  void _syncFlick() {
    if (widget.flickering && !_flick.isAnimating) {
      _flick.repeat();
    } else if (!widget.flickering && _flick.isAnimating) {
      _flick.stop();
    }
  }

  @override
  void dispose() {
    _flick.dispose();
    super.dispose();
  }

  static const ColorFilter _desaturate = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final double intensity = widget.intensity.clamp(0.0, 1.0);

    Widget flame = AnimatedBuilder(
      animation: _flick,
      builder: (BuildContext context, Widget? child) {
        // Genlik seansla büyüyor: dinlenen alev hafif, tam ısınmış alev canlı
        // oynuyor. Taban 0.45, çünkü tamamen durgun bir alev ölü görünüyor.
        final double amplitude = 0.45 + 0.55 * intensity;
        final double t = _flick.value * 2 * math.pi;
        return Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..translateByDouble(math.sin(t) * 3 * amplitude, 0.0, 0.0, 1.0)
            ..scaleByDouble(1.0, 1 + math.sin(t * 1.3) * 0.045 * amplitude, 1.0, 1.0)
            ..setEntry(0, 1, math.sin(t * 0.7) * 0.05 * amplitude),
          child: child,
        );
      },
      // İçteki sınır: alevin şekli hiç değişmiyor, yalnızca üstündeki
      // `Transform` değişiyor. Sınır sayesinde `Transform` bileşikleşiyor ve
      // kare başına iş, hazır katmanın matrisini güncellemeye iniyor.
      child: RepaintBoundary(
        child: _FlameShape(tier: widget.tier, intensity: intensity),
      ),
    );

    if (widget.desaturated) {
      flame = ColorFiltered(colorFilter: _desaturate, child: flame);
    }

    // Dıştaki sınır: bu olmadan `Transform`un her karedeki `markNeedsPaint`i
    // en yakın üst sınıra kadar çıkıyor — o sınır Ekran 03'te alevle aynı
    // katmanda duran 72px sayaç metnini de kapsıyor.
    return RepaintBoundary(
      child: SizedBox(
        height: widget.boxHeight,
        child: Transform.scale(
          scale: widget.tier.scale,
          alignment: Alignment.bottomCenter,
          child: Align(alignment: Alignment.bottomCenter, child: flame),
        ),
      ),
    );
  }
}

/// Alevin gövdesi. Ölçüler tam kademe (K10) içindir; küçük kademeler dıştaki
/// `Transform.scale` ile küçülür — tek çizim yolu, tek raster.
class _FlameShape extends StatelessWidget {
  const _FlameShape({required this.tier, required this.intensity});

  final FlameTier tier;
  final double intensity;

  /// Gövdenin közden aleve gradyanı. Koyu temada prototipin değerleri birebir.
  /// Açık temada krem uç (#FFF3D8) zeminle 1.02:1 kontrasta düşüyordu —
  /// alevin tepesi sayfaya karışıyordu; uç ember'ın kendisine çekiliyor.
  static const List<Color> _darkBody = <Color>[
    Color(0xFF7A2F0C),
    Color(0xFFFFB03A),
    Color(0xFFFFF3D8),
  ];
  static const List<Color> _lightBody = <Color>[
    Color(0xFF7A2F0C),
    Color(0xFFE8880F),
    Color(0xFFFFB03A),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Çekirdek seansla parlıyor: dinlenirken yarı saydam, tam odakta opak.
    final double coreAlpha = 0.62 + 0.33 * intensity;

    return SizedBox(
      width: 64,
      height: 98,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          if (tier.haloOpacity > 0)
            Positioned(
              bottom: -10,
              child: IgnorePointer(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        const Color(0xFFFFB03A).withValues(alpha: tier.haloOpacity),
                        Colors.transparent,
                      ],
                      stops: const <double>[0, 0.72],
                    ),
                  ),
                ),
              ),
            ),
          if (tier.emberBase)
            Positioned(
              bottom: 0,
              child: Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0x007A2F0C), Color(0xFFCC5A10), Color(0x007A2F0C)],
                  ),
                ),
              ),
            ),
          Container(
            width: 44,
            height: 86,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isDark ? _darkBody : _lightBody,
                stops: const <double>[0, 0.56, 1],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(22, 58),
                topRight: Radius.elliptical(22, 58),
                bottomLeft: Radius.elliptical(20, 27),
                bottomRight: Radius.elliptical(20, 27),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            child: Container(
              width: 18,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAF0).withValues(alpha: coreAlpha),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.elliptical(9, 28),
                  topRight: Radius.elliptical(9, 28),
                  bottomLeft: Radius.elliptical(9, 17),
                  bottomRight: Radius.elliptical(9, 17),
                ),
              ),
            ),
          ),
          // Kıvılcımlar deterministik konumda: rastgelelik kare kare zıplama
          // yaratır ve widget testini kararsızlaştırırdı.
          for (int i = 0; i < tier.sparkCount; i++)
            Positioned(
              bottom: 74.0 + i * 7,
              left: 22.0 + (i.isEven ? -13 : 13) + i * 1.5,
              child: IgnorePointer(
                child: Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFFD79A)
                        .withValues(alpha: (0.35 + 0.45 * intensity).clamp(0.0, 1.0)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Delete the old file**

```bash
git rm lib/features/focus_session/widgets/flame_widget.dart
```

- [ ] **Step 5: Run tests to verify**

Run: `flutter test test/core/widgets/flame_widget_test.dart`
Expected: PASS — 6 test.

Run: `flutter analyze`
Expected: `focus_session_screen.dart` içinde import/tanımsız ad hatası. Task 5 düzeltecek.

- [ ] **Step 6: Commit**

```bash
git add lib/core/widgets/flame_widget.dart test/core/widgets/flame_widget_test.dart
git commit -m "FlameWidget core/widgets altina tasindi, kademe ve seans eksenleri ayrildi"
```

---

## Task 5: Odak ekranını yeni API'ye bağla

**Files:**
- Modify: `lib/features/focus_session/focus_session_screen.dart` (import bloğu + satır 445-448)
- Test: `test/features/focus_session/focus_session_screen_test.dart`

- [ ] **Step 1: Update the test's import and add the new test**

Import bloğunda:

```dart
// Sil:
import 'package:focussayac/features/focus_session/widgets/flame_widget.dart';
// Ekle:
import 'package:focussayac/core/widgets/flame_widget.dart';
import 'package:focussayac/domain/flame/flame_tier.dart';
```

`main()` içine:

```dart
  testWidgets('alev kademe tabanını taşıyor', (WidgetTester tester) async {
    // Kalıcılık vaadi: 62 saatlik geçmişte alev K6dan başlar; seans
    // ilerlemesi ne olursa olsun K6nın ölçeğinde kalır.
    await _pumpFocusSession(tester, sessions: _hours(62));

    final FlameWidget flame = tester.widget<FlameWidget>(_flame);
    expect(flame.tier.index, 6);
    expect(flame.tier.scale, kFlameTierLadder[5].scale);
  });
```

> **Not:** `_pumpFocusSession` ve `_hours` bu dosyada zaten var mı kontrol et.
> Yoksa `test/features/badges/badge_progress_test.dart:17-28` ve `:33-55`
> kalıbını uyarla: `allSessionsProvider`ı `Stream.value(sessions)` ile
> override et, `localizedTestApp` ile sar. `_flame` finder'ı dosyada zaten var
> (satır 120).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/focus_session/focus_session_screen_test.dart`
Expected: FAIL — derleme hatası, `FlameWidget`in `running`/`progress` parametreleri yok.

- [ ] **Step 3: Write the implementation**

`lib/features/focus_session/focus_session_screen.dart` — import bloğunda:

```dart
// Sil:
import 'widgets/flame_widget.dart';
// Ekle (mevcut import sıralamasına uygun yere):
import '../../core/widgets/flame_widget.dart';
import '../../domain/flame/flame_providers.dart';
```

Satır 445-448'i şununla değiştir:

```dart
                        SizedBox(
                          height: 106,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FlameWidget(
                              // Kademe kalıcı: seans bitince alev buraya
                              // döner, asla altına inmez.
                              tier: ref.watch(flameTierProvider).tier,
                              boxHeight: 98,
                              intensity: progress,
                              flickering: running,
                              desaturated: !running,
                            ),
                          ),
                        ),
```

> **Not:** Bu `build` metodunun `ref`e erişimi var mı kontrol et. Yoksa en
> yakın `Consumer` sarmalayıcısını kullan ya da kademeyi `ref`i olan üst
> gövdede okuyup parametre olarak indir.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/focus_session/`
Expected: PASS — yeni test dahil; mevcut `_flameFlickTransform` testi de geçmeli.

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/features/focus_session/focus_session_screen.dart test/features/focus_session/focus_session_screen_test.dart
git commit -m "Odak ekraninin alevi kalici kademe tabanina baglandi"
```

---

## Task 6: Kademe adları ve metinler (ARB)

**Files:**
- Modify: `lib/l10n/app_tr.arb`
- Modify: `lib/domain/flame/flame_tier.dart`
- Test: `test/domain/flame/flame_tier_test.dart`

- [ ] **Step 1: Add the ARB keys**

`lib/l10n/app_tr.arb` — `"badgeTwoFiftyHoursRule"` satırından sonra, aynı girintiyle:

```json
  "flameTier1Name": "Kıvılcım",
  "flameTier2Name": "Köz",
  "flameTier3Name": "Kandil",
  "flameTier4Name": "Fener",
  "flameTier5Name": "Meşale",
  "flameTier6Name": "Ocak",
  "flameTier7Name": "Şenlik Ateşi",
  "flameTier8Name": "Harman Ateşi",
  "flameTier9Name": "Volkan",
  "flameTier10Name": "Güneş",
  "flameTierKicker": "MEŞALEN",
  "flameTopTier": "En üst kademe",
  "flameNextTierHours": "Sonraki kademeye {hours} saat",
  "@flameNextTierHours": {
    "description": "Ekran 04 kahraman kartının alt satırı. Saat, sonraki kademe eşiğine kalan tam saattir (aşağı yuvarlanmış kümülatif odak saatinden).",
    "placeholders": { "hours": { "type": "int" } }
  },
  "flameHoursCounter": "{current} / {target} sa",
  "@flameHoursCounter": {
    "description": "Kahraman karttaki çıplak sayaç. Rozet kartlarındaki '61/100' ile aynı mantık ama birim burada yazılı, çünkü kartta birimi söyleyen bir kural metni yok.",
    "placeholders": {
      "current": { "type": "int" },
      "target": { "type": "int" }
    }
  },
  "flameAvatarSemantics": "{name}, {index}. kademe. {current} saat / {target} saat.",
  "@flameAvatarSemantics": {
    "description": "Kahraman kartın ekran okuyucu karşılığı — kart tek bir semantik düğüm.",
    "placeholders": {
      "name": { "type": "String" },
      "index": { "type": "int" },
      "current": { "type": "int" },
      "target": { "type": "int" }
    }
  },
```

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: Hatasız tamamlanır.

Run: `grep -c "flameTier" lib/l10n/gen/app_localizations.dart`
Expected: 10'dan büyük bir sayı.

- [ ] **Step 3: Add `name()` to `FlameTier`**

`lib/domain/flame/flame_tier.dart` — dosyanın başına:

```dart
import '../../l10n/gen/app_localizations.dart';
```

`FlameTier` sınıfının içine, `haloOpacity` alanından sonra:

```dart
  /// Ad ARB'den — katalog `const` kalsın diye alan değil metot
  /// (`BadgeDefinition.name` ile aynı gerekçe).
  String name(AppLocalizations l10n) => switch (index) {
        1 => l10n.flameTier1Name,
        2 => l10n.flameTier2Name,
        3 => l10n.flameTier3Name,
        4 => l10n.flameTier4Name,
        5 => l10n.flameTier5Name,
        6 => l10n.flameTier6Name,
        7 => l10n.flameTier7Name,
        8 => l10n.flameTier8Name,
        9 => l10n.flameTier9Name,
        10 => l10n.flameTier10Name,
        _ => throw ArgumentError.value(index, 'index', 'Bilinmeyen kademe'),
      };
```

- [ ] **Step 4: Write a test that every tier has a name**

`test/domain/flame/flame_tier_test.dart` — importa ekle:

```dart
import '../../support/localized_test_app.dart';
```

`main()` sonuna:

```dart
  test('her kademenin ARB karşılığı var ve boş değil', () {
    // `name()` bilinmeyen indekste fırlatıyor; bu test kataloğun tamamını
    // dolaşarak eksik ARB anahtarını yakalıyor.
    for (final FlameTier tier in kFlameTierLadder) {
      expect(tier.name(testL10n), isNotEmpty, reason: 'K${tier.index} adsız');
    }
  });
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/domain/flame/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_tr.arb lib/domain/flame/flame_tier.dart test/domain/flame/flame_tier_test.dart
git commit -m "Kademe adlari ve kart metinleri ARBde"
```

---

## Task 7: Ekran 04 kahraman kartı

**Karar:** Karttaki alev **titremiyor** (`flickering: false`). Tasarım belgesi
titremesini öngörüyordu ama `test/features/badges/badge_progress_test.dart:54`
ve `badge_unlock_dialog_test.dart` `pumpAndSettle` kullanıyor — sonsuz tekrarlı
bir tikleyici o testleri zaman aşımına düşürürdü. Durağan portre kimlik için
zaten daha doğru ve pil için bedava. Spec Task 14'te güncelleniyor.

**Files:**
- Create: `lib/features/badges/widgets/flame_avatar_card.dart`
- Modify: `lib/features/badges/badges_screen.dart`
- Test: `test/features/badges/flame_avatar_card_test.dart`

- [ ] **Step 1: Write the failing test**

`test/features/badges/flame_avatar_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/core/widgets/flame_widget.dart';
import 'package:focussayac/domain/badges/badge_providers.dart';
import 'package:focussayac/domain/pomodoro/pomodoro_stats_providers.dart';
import 'package:focussayac/features/badges/badges_screen.dart';
import 'package:focussayac/services/storage/app_database.dart';
import 'package:focussayac/services/storage/storage_enums.dart';

import '../../support/localized_test_app.dart';

int _id = 0;

/// [count] saatlik tamamlanmış odak geçmişi — günde üç adet 60 dakikalık seans.
List<PomodoroSession> _hours(int count) => <PomodoroSession>[
      for (int i = 0; i < count; i++)
        PomodoroSession(
          id: ++_id,
          type: SessionType.focus,
          startedAt: DateTime.utc(2026, 3, 1 + i ~/ 3, 6 + i % 3),
          plannedDurationSec: 3600,
          completed: true,
          breakExtensions: 0,
        ),
    ];

Future<void> _pumpBadges(WidgetTester tester, {required List<PomodoroSession> sessions}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSessionsProvider.overrideWith((Ref ref) => Stream<List<PomodoroSession>>.value(sessions)),
        unlockedBadgesProvider.overrideWith((Ref ref) => Stream<List<UserBadge>>.value(const <UserBadge>[])),
      ],
      child: localizedTestApp(const BadgesScreen()),
    ),
  );
  // Kart durağan olduğu için `pumpAndSettle` burada takılmamalı — bu testin
  // sessiz ikinci işlevi tam olarak bunu doğrulamak.
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('62 saatte K6 kartı, sayaç ve kalan saat', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(62));

    expect(find.text('Ocak'), findsOneWidget);
    expect(find.text('62 / 100 sa'), findsOneWidget);
    expect(find.text('Sonraki kademeye 38 saat'), findsOneWidget);
    expect(find.byType(FlameWidget), findsOneWidget);
  });

  testWidgets('geçmiş boşken K1 kartı çiziliyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: const <PomodoroSession>[]);

    expect(find.text('Kıvılcım'), findsOneWidget);
    expect(find.text('0 / 1 sa'), findsOneWidget);
    expect(find.text('Sonraki kademeye 1 saat'), findsOneWidget);
  });

  testWidgets('en üst kademede kalan saat yerine "En üst kademe"',
      (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(420));

    expect(find.text('Güneş'), findsOneWidget);
    expect(find.text('En üst kademe'), findsOneWidget);
    expect(find.textContaining('Sonraki kademeye'), findsNothing);
  });

  testWidgets('karttaki alev titremiyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(62));
    expect(tester.widget<FlameWidget>(find.byType(FlameWidget)).flickering, isFalse);
  });

  testWidgets('rozet ızgarası bozulmadan duruyor', (WidgetTester tester) async {
    await _pumpBadges(tester, sessions: _hours(62));
    expect(find.text('ROZETLER'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/badges/flame_avatar_card_test.dart`
Expected: FAIL — "Actual: _TextFinder:<zero widgets with text 'Ocak'>".

- [ ] **Step 3: Write the implementation**

`lib/features/badges/widgets/flame_avatar_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/flame_widget.dart';
import '../../../domain/flame/flame_providers.dart';
import '../../../domain/flame/flame_tier.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Ekran 04'ün kahraman kartı — kalıcı kimlik. Rozet ızgarası "ne başardım"
/// diyor, bu kart "ben kimim" diyor.
///
/// Alev burada **titremiyor**: ekran seans dışı bir yüzey ve sonsuz tekrarlı
/// bir tikleyici hem pili hem `pumpAndSettle` kullanan ekran testlerini
/// yakardı. Durağan portre kimlik için zaten daha doğru.
class FlameAvatarCard extends ConsumerWidget {
  const FlameAvatarCard({super.key});

  /// Kartın alev kutusu — odak ekranından (98) büyük, çünkü burada alev
  /// sayfanın kahramanı, sayaç metninin yanındaki dekor değil.
  static const double boxHeight = 120;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppColors colors = Theme.of(context).extension<AppColors>()!;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FlameTierStatus status = ref.watch(flameTierProvider);

    // En üst kademede hedef yok; sayaç kullanıcının kendi toplamını gösterir
    // ("400 / 400 sa" donmuş bir sayı olurdu).
    final int target = status.nextTier?.thresholdHours ?? status.cumulativeHours;

    return Semantics(
      container: true,
      label: l10n.flameAvatarSemantics(
        status.tier.name(l10n),
        status.tier.index,
        status.cumulativeHours,
        target,
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: colors.surfaceCardSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.flameTierKicker,
                style: AppTypography.kicker(
                    fontSize: AppTextSize.kicker, color: colors.neutral600),
              ),
              const SizedBox(height: 10),
              Center(
                child: FlameWidget(
                  tier: status.tier,
                  boxHeight: boxHeight,
                  flickering: false,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                status.tier.name(l10n),
                style: AppTypography.display(
                    fontSize: AppTextSize.titleLg, color: colors.text),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          children: <Widget>[
                            DecoratedBox(decoration: BoxDecoration(color: colors.fillSubtle)),
                            FractionallySizedBox(
                              widthFactor: status.ratioInTier,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: <Color>[colors.emberDim, colors.ember],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.flameHoursCounter(status.cumulativeHours, target),
                    style: AppTypography.label(
                      fontSize: AppTextSize.sm,
                      weight: FontWeight.w600,
                      color: colors.neutral400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                status.isTopTier
                    ? l10n.flameTopTier
                    : l10n.flameNextTierHours(status.hoursRemaining!),
                style: AppTypography.body(
                    fontSize: AppTextSize.sm, color: colors.neutral500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/badges/badges_screen.dart` — import ekle:

```dart
import 'widgets/flame_avatar_card.dart';
```

Satır 123'teki `const SizedBox(height: 22),` ile `Expanded(` arasına:

```dart
                  RiseIn(
                    delay: RiseIn.step * 2,
                    child: const FlameAvatarCard(),
                  ),
                  const SizedBox(height: 22),
```

Satır 140'taki ızgara gecikmesini bir basamak kaydır:

```dart
                                    // Başlık, ilerleme çubuğu ve kahraman kart
                                    // ilk üç basamağı aldığı için ızgara
                                    // dördüncüden devam ediyor.
                                    delay: RiseIn.step * (index + 3),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/badges/`
Expected: PASS — yeni 5 test **ve** mevcut `badge_progress_test.dart` / `badge_unlock_dialog_test.dart`.

Mevcut testler düşerse sebebi büyük ihtimalle taşma (kart ekranı uzattı):
`_pumpBadges` içindeki `physicalSize` yüksekliğini artır ya da düşen testin
aradığı widget'ı `skipOffstage: false` ile bul — ızgara zaten
`SingleChildScrollView` içinde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/badges/ test/features/badges/flame_avatar_card_test.dart
git commit -m "Ekran 04e kalici avatar kahraman karti"
```

---

## Task 8: Anlık görüntüye `cumulativeFocusSeconds`

**Files:**
- Modify: `lib/domain/widgets/home_widget_snapshot.dart`
- Modify: `lib/services/widgets/home_widget_sync.dart`
- Test: `test/domain/widgets/home_widget_snapshot_test.dart`

- [ ] **Step 1: Write the failing test**

`test/domain/widgets/home_widget_snapshot_test.dart` — `main()` içine:

```dart
  test('kümülatif odak saniyesi payloadda', () {
    // Widget kademeyi KENDİSİ hesaplıyor; Dart yalnızca ham saniyeyi yazıyor
    // (`FocusWidgetSnapshot.kt` "türetilmiş değer Dart'tan okunmaz" kuralı).
    final HomeWidgetSnapshot snapshot = HomeWidgetSnapshot.noExam(
      streak: 3,
      todayMinutes: 50,
      todayPomodoros: 2,
      weeklyMinutes: const <int>[0, 0, 0, 0, 0, 25, 50],
      sessionActive: false,
      cumulativeFocusSeconds: 223200,
      updatedAtUtc: DateTime.utc(2026, 9, 12),
    );

    expect(snapshot.toPayload()[HomeWidgetSnapshot.keyCumulativeFocusSeconds], 223200);
    expect(
      HomeWidgetSnapshot.payloadKeys,
      contains(HomeWidgetSnapshot.keyCumulativeFocusSeconds),
    );
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/widgets/home_widget_snapshot_test.dart`
Expected: FAIL — "No named parameter with the name 'cumulativeFocusSeconds'".

- [ ] **Step 3: Write the implementation**

`lib/domain/widgets/home_widget_snapshot.dart`:

1. Ana yapıcıya `required this.cumulativeFocusSeconds,` ekle.
2. `noExam` fabrikasına `required int cumulativeFocusSeconds,` parametresi ve gövdesinde `cumulativeFocusSeconds: cumulativeFocusSeconds,` aktarımı ekle.
3. `sessionActive` alanından sonra:

```dart
  /// Tüm zamanların tamamlanmış odak süresi (saniye) — meşale widget'ının tek
  /// girdisi. **Kademe, kalan saat ve oran burada yok, bilinçli olarak:**
  /// üçü de Kotlin tarafında merdivenden yeniden hesaplanıyor
  /// (`FlameTierLadder.kt`). Merdiven zaten çizim için orada bulunmak zorunda;
  /// türetilmiş değeri ayrıca göndermek ikinci bir gerçek kaynağı olurdu.
  final int cumulativeFocusSeconds;
```

4. `toPayload()` haritasına: `keyCumulativeFocusSeconds: cumulativeFocusSeconds,`
5. Anahtar sabiti: `static const String keyCumulativeFocusSeconds = 'cumulativeFocusSeconds';`
6. `payloadKeys` listesine `keyCumulativeFocusSeconds,` ekle.

`lib/services/widgets/home_widget_sync.dart` — `homeWidgetSnapshotProvider`
içinde `final int todayMinutes = ...` satırının altına:

```dart
  final int cumulativeFocusSeconds = stats.cumulativeSeconds;
```

ve iki `HomeWidgetSnapshot` çağrısının (`noExam` ve normal) ikisine de
`cumulativeFocusSeconds: cumulativeFocusSeconds,` ekle.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/domain/widgets/ test/services/widgets/`
Expected: PASS. `home_widget_service_test.dart` düşerse oradaki sahte anlık
görüntü çağrılarına da yeni argümanı ekle.

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/domain/widgets/home_widget_snapshot.dart lib/services/widgets/home_widget_sync.dart test/
git commit -m "Widget payloaduna kumulatif odak saniyesi"
```

---

## Task 9: Kotlin merdiveni ve senkron testi

**Files:**
- Create: `android/app/src/main/kotlin/com/focussayac/focussayac/widget/FlameTierLadder.kt`
- Modify: `android/.../widget/FocusWidgetSnapshot.kt`
- Test: `test/android/flame_tier_sync_test.dart`

- [ ] **Step 1: Write the failing test**

`test/android/flame_tier_sync_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:focussayac/domain/flame/flame_tier.dart';

/// Meşale widget'ı Dart merdivenine erişemediği için merdiven Kotlin'de bir
/// kez daha tanımlı. Bu test iki kopyanın ayrışmasını yakalar — palet senkron
/// testinin (`focus_palette_sync_test.dart`) aynı gerekçeyle kurulmuş kardeşi.
///
/// Seçilen mimarinin bilinen tek zayıf noktası buydu (bkz.
/// docs/superpowers/specs/2026-09-12-mesale-kademe-avatari-design.md, Riskler).
void main() {
  const String kotlinPath =
      'android/app/src/main/kotlin/com/focussayac/focussayac/widget/FlameTierLadder.kt';

  /// `FlameTier(index = 6, thresholdHours = 50, scale = 0.72f, emberBase = true, sparkCount = 2, haloOpacity = 0.0f)`
  /// satırlarını okur. Biçim değişirse test düşer — bu kasıtlı: satır düzeni
  /// sözleşmenin parçası.
  List<Map<String, String>> readKotlinLadder() {
    final File file = File(kotlinPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$kotlinPath bulunamadi - Kotlin merdiveni kaldirilmis olabilir',
    );

    final RegExp pattern = RegExp(
      r'FlameTier\(\s*index\s*=\s*(\d+),\s*'
      r'thresholdHours\s*=\s*(\d+),\s*'
      r'scale\s*=\s*([\d.]+)f,\s*'
      r'emberBase\s*=\s*(true|false),\s*'
      r'sparkCount\s*=\s*(\d+),\s*'
      r'haloOpacity\s*=\s*([\d.]+)f\s*\)',
    );

    return <Map<String, String>>[
      for (final RegExpMatch m in pattern.allMatches(file.readAsStringSync()))
        <String, String>{
          'index': m.group(1)!,
          'thresholdHours': m.group(2)!,
          'scale': m.group(3)!,
          'emberBase': m.group(4)!,
          'sparkCount': m.group(5)!,
          'haloOpacity': m.group(6)!,
        },
    ];
  }

  test('Kotlin merdiveni Dart merdiveniyle birebir aynı', () {
    final List<Map<String, String>> kotlin = readKotlinLadder();

    expect(
      kotlin.length,
      kFlameTierLadder.length,
      reason: 'Kotlin merdiveni ${kotlin.length} kademe, Dart ${kFlameTierLadder.length}',
    );

    for (int i = 0; i < kFlameTierLadder.length; i++) {
      final FlameTier dart = kFlameTierLadder[i];
      final Map<String, String> kt = kotlin[i];

      expect(int.parse(kt['index']!), dart.index, reason: 'K${dart.index} index sapmış');
      expect(int.parse(kt['thresholdHours']!), dart.thresholdHours,
          reason: 'K${dart.index} eşiği sapmış');
      expect(double.parse(kt['scale']!), closeTo(dart.scale, 1e-6),
          reason: 'K${dart.index} ölçeği sapmış');
      expect(kt['emberBase'] == 'true', dart.emberBase,
          reason: 'K${dart.index} kor yatağı sapmış');
      expect(int.parse(kt['sparkCount']!), dart.sparkCount,
          reason: 'K${dart.index} kıvılcım sayısı sapmış');
      expect(double.parse(kt['haloOpacity']!), closeTo(dart.haloOpacity, 1e-6),
          reason: 'K${dart.index} hâle opaklığı sapmış');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/android/flame_tier_sync_test.dart`
Expected: FAIL — "FlameTierLadder.kt bulunamadi - Kotlin merdiveni kaldirilmis olabilir".

- [ ] **Step 3: Write the implementation**

`android/app/src/main/kotlin/com/focussayac/focussayac/widget/FlameTierLadder.kt`:

```kotlin
package com.focussayac.focussayac.widget

import com.focussayac.focussayac.R

/**
 * Mesale kademe merdiveninin Kotlin aynasi. Kaynak:
 * lib/domain/flame/flame_tier.dart -> kFlameTierLadder
 *
 * ONEMLI: Asagidaki FlameTier(...) satirlarinin bicimi sozlesmenin parcasi.
 * test/android/flame_tier_sync_test.dart bu satirlari duzenli ifadeyle
 * ayristirip Dart tablosuyla karsilastiriyor; argumanlari yeniden siralamak
 * ya da satira bolmek testi dusurur.
 */
data class FlameTier(
    val index: Int,
    val thresholdHours: Int,
    val scale: Float,
    val emberBase: Boolean,
    val sparkCount: Int,
    val haloOpacity: Float,
)

/** Bir anin kademe durumu - Dart'taki FlameTierStatus ile ayni alanlar. */
data class FlameTierStatus(
    val tier: FlameTier,
    val nextTier: FlameTier?,
    val hoursRemaining: Int?,
    val ratioInTier: Float,
    val cumulativeHours: Int,
) {
    val isTopTier: Boolean get() = nextTier == null
}

object FlameTierLadder {

    val TIERS: List<FlameTier> = listOf(
        FlameTier(index = 1, thresholdHours = 0, scale = 0.35f, emberBase = false, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 2, thresholdHours = 1, scale = 0.42f, emberBase = false, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 3, thresholdHours = 3, scale = 0.50f, emberBase = false, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 4, thresholdHours = 10, scale = 0.58f, emberBase = true, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 5, thresholdHours = 25, scale = 0.65f, emberBase = true, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 6, thresholdHours = 50, scale = 0.72f, emberBase = true, sparkCount = 2, haloOpacity = 0.0f),
        FlameTier(index = 7, thresholdHours = 100, scale = 0.80f, emberBase = true, sparkCount = 3, haloOpacity = 0.0f),
        FlameTier(index = 8, thresholdHours = 175, scale = 0.87f, emberBase = true, sparkCount = 3, haloOpacity = 0.18f),
        FlameTier(index = 9, thresholdHours = 250, scale = 0.94f, emberBase = true, sparkCount = 4, haloOpacity = 0.26f),
        FlameTier(index = 10, thresholdHours = 400, scale = 1.0f, emberBase = true, sparkCount = 5, haloOpacity = 0.34f),
    )

    /** Kademe adlari - ARB'deki flameTier{N}Name ile birebir ayni kelimeler. */
    fun nameResFor(index: Int): Int = when (index) {
        1 -> R.string.widget_flame_tier_1
        2 -> R.string.widget_flame_tier_2
        3 -> R.string.widget_flame_tier_3
        4 -> R.string.widget_flame_tier_4
        5 -> R.string.widget_flame_tier_5
        6 -> R.string.widget_flame_tier_6
        7 -> R.string.widget_flame_tier_7
        8 -> R.string.widget_flame_tier_8
        9 -> R.string.widget_flame_tier_9
        else -> R.string.widget_flame_tier_10
    }

    /**
     * Dart'taki `flameTierFor` ile birebir ayni kural: saat ASAGI yuvarlanir
     * (`floor(sn/3600)`), negatif girdi sifira duser.
     */
    fun statusFor(cumulativeSeconds: Int): FlameTierStatus {
        val hours = if (cumulativeSeconds <= 0) 0 else cumulativeSeconds / 3600

        var position = 0
        for (i in 1 until TIERS.size) {
            if (hours >= TIERS[i].thresholdHours) position = i
        }

        val tier = TIERS[position]
        val next = TIERS.getOrNull(position + 1)
            ?: return FlameTierStatus(tier, null, null, 1f, hours)

        val span = next.thresholdHours - tier.thresholdHours
        return FlameTierStatus(
            tier = tier,
            nextTier = next,
            hoursRemaining = next.thresholdHours - hours,
            ratioInTier = ((hours - tier.thresholdHours).toFloat() / span).coerceIn(0f, 1f),
            cumulativeHours = hours,
        )
    }
}
```

`FocusWidgetSnapshot.kt` — `sessionActive` alanından sonra:

```kotlin
    /** Tum zamanlarin tamamlanmis odak suresi (saniye) - mesale widget'inin girdisi. */
    val cumulativeFocusSeconds: Int,
```

ve `load()` içindeki yapıcı çağrısına:

```kotlin
                cumulativeFocusSeconds = all.int("cumulativeFocusSeconds"),
```

> **Not:** `R.string.widget_flame_tier_*` kaynakları Task 10'da ekleniyor.
> Bu görevde Kotlin **derlenmeyecek**; senkron testi salt metin okuduğu için
> geçer. Derleme doğrulaması Task 10 Step 6'da.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/android/`
Expected: PASS — hem palet hem merdiven senkron testi.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/focussayac/focussayac/widget/ test/android/flame_tier_sync_test.dart
git commit -m "Kotlin kademe merdiveni ve Dart senkron testi"
```

---

## Task 10: `FlameRenderer`, sağlayıcı ve kaynaklar

**Files:**
- Create: `android/.../widget/FlameRenderer.kt`, `android/.../widget/FlameWidgetProvider.kt`
- Create: `res/layout/widget_flame.xml`, `res/xml/widget_flame_info.xml`, `res/drawable/widget_preview_flame.xml`
- Modify: `res/values/strings.xml`, `AndroidManifest.xml`, `widget/BaseFocusWidgetProvider.kt`, `widget/WidgetRoutes.kt`

- [ ] **Step 1: Add the strings**

`android/app/src/main/res/values/strings.xml` — mevcut widget metinlerinin yanına:

```xml
    <!-- Kademe adlari: lib/l10n/app_tr.arb -> flameTier{N}Name ile birebir ayni kelimeler. -->
    <string name="widget_flame_tier_1">Kıvılcım</string>
    <string name="widget_flame_tier_2">Köz</string>
    <string name="widget_flame_tier_3">Kandil</string>
    <string name="widget_flame_tier_4">Fener</string>
    <string name="widget_flame_tier_5">Meşale</string>
    <string name="widget_flame_tier_6">Ocak</string>
    <string name="widget_flame_tier_7">Şenlik Ateşi</string>
    <string name="widget_flame_tier_8">Harman Ateşi</string>
    <string name="widget_flame_tier_9">Volkan</string>
    <string name="widget_flame_tier_10">Güneş</string>
    <!-- ARB: flameTierKicker / flameNextTierHours / flameTopTier -->
    <string name="widget_flame_tag">MEŞALEN</string>
    <string name="widget_flame_next">Sonraki: %1$d sa</string>
    <string name="widget_flame_top">En üst kademe</string>
    <string name="widget_flame_label">Meşale</string>
    <string name="widget_flame_description">Biriken odak saatinle büyüyen meşalen</string>
```

- [ ] **Step 2: Write the renderer**

`android/app/src/main/kotlin/com/focussayac/focussayac/widget/FlameRenderer.kt`:

```kotlin
package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader

/**
 * Kademe alevini cizer - lib/core/widgets/flame_widget.dart icindeki
 * _FlameShape mantiginin widget olcegine indirilmis hali.
 *
 * Seans ekseni burada YOK: widget suren seansi gostermiyor, kimligi
 * gosteriyor. Alev her zaman kademenin dinlenme halinde.
 */
object FlameRenderer {

    // Dart tarafindaki _darkBody duraklari. Alevin gradyani dekoratif ve kendi
    // kutusunda duruyor; Dart'taki `_lightBody` duzeltmesi METIN kontrasti
    // icindi, burada karsiligi yok.
    private const val BODY_ROOT = 0xFF7A2F0C.toInt()
    private const val BODY_MID = 0xFFFFB03A.toInt()
    private const val BODY_TIP = 0xFFFFF3D8.toInt()
    private const val CORE = 0xFFFFFAF0.toInt()
    private const val SPARK = 0xFFFFD79A.toInt()
    private const val EMBER = 0xFFCC5A10.toInt()

    fun render(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        tier: FlameTier,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Dart'taki 64x98 kutunun oranlari korunuyor; kademe olcegi kutunun
        // icinde uygulaniyor (Transform.scale'in karsiligi).
        val bodyHeight = heightPx * tier.scale
        val bodyWidth = bodyHeight * (44f / 86f)
        val centerX = widthPx / 2f
        val bottom = heightPx.toFloat()
        val top = bottom - bodyHeight

        if (tier.haloOpacity > 0f) {
            val haloY = bottom - bodyHeight * 0.45f
            val haloR = bodyHeight * 0.75f
            paint.shader = RadialGradient(
                centerX,
                haloY,
                haloR,
                withAlpha(BODY_MID, (tier.haloOpacity * 255).toInt()),
                Color.TRANSPARENT,
                Shader.TileMode.CLAMP,
            )
            canvas.drawCircle(centerX, haloY, haloR, paint)
            paint.shader = null
        }

        if (tier.emberBase) {
            paint.color = withAlpha(EMBER, 0xB3)
            val emberWidth = bodyWidth * 0.92f
            val emberHeight = bodyHeight * 0.11f
            canvas.drawOval(
                RectF(centerX - emberWidth / 2f, bottom - emberHeight, centerX + emberWidth / 2f, bottom),
                paint,
            )
        }

        paint.shader = LinearGradient(
            centerX, bottom, centerX, top,
            intArrayOf(BODY_ROOT, BODY_MID, BODY_TIP),
            floatArrayOf(0f, 0.56f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRoundRect(
            RectF(centerX - bodyWidth / 2f, top, centerX + bodyWidth / 2f, bottom),
            bodyWidth / 2f,
            bodyHeight * 0.42f,
            paint,
        )
        paint.shader = null

        // Ic cekirdek - govdenin icinde kaldigi icin her iki temada da ayni.
        paint.color = withAlpha(CORE, 0xF2)
        val coreWidth = bodyWidth * (18f / 44f)
        val coreHeight = bodyHeight * (46f / 86f)
        val coreBottom = bottom - bodyHeight * 0.14f
        canvas.drawRoundRect(
            RectF(centerX - coreWidth / 2f, coreBottom - coreHeight, centerX + coreWidth / 2f, coreBottom),
            coreWidth / 2f,
            coreHeight * 0.4f,
            paint,
        )

        // Kivilcimlar deterministik konumda - rastgelelik her yenilemede
        // widget'i zipatirdi.
        paint.color = withAlpha(SPARK, 0xCC)
        val sparkRadius = bodyWidth * 0.08f
        for (i in 0 until tier.sparkCount) {
            val offsetX = if (i % 2 == 0) -bodyWidth * 0.6f else bodyWidth * 0.6f
            val y = top - bodyHeight * 0.06f * i - sparkRadius
            if (y > 0f) canvas.drawCircle(centerX + offsetX, y, sparkRadius, paint)
        }

        return bitmap
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}
```

- [ ] **Step 3: Write the layout**

`android/app/src/main/res/layout/widget_flame.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!--
  Mesale widget (2x2). Ust: MESALEN kicker. Orta: kademe alevi.
  Alt: kademe adi, ilerleme seridi ve sonraki kademeye kalan saat.
-->
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_flame_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_surface"
    android:orientation="vertical"
    android:padding="14dp">

    <TextView
        android:id="@+id/widget_flame_tag"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:fontFamily="@font/michroma_regular"
        android:letterSpacing="0.26"
        android:text="@string/widget_flame_tag"
        android:textColor="@color/focus_ember"
        android:textSize="8sp" />

    <ImageView
        android:id="@+id/widget_flame_image"
        android:src="@drawable/widget_preview_flame"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_marginTop="6dp"
        android:layout_weight="1"
        android:contentDescription="@string/widget_flame_label"
        android:scaleType="fitCenter" />

    <TextView
        android:id="@+id/widget_flame_tier"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="6dp"
        android:ellipsize="end"
        android:fontFamily="@font/space_grotesk_700"
        android:maxLines="1"
        android:textColor="@color/focus_text"
        android:textSize="15sp" />

    <ProgressBar
        android:id="@+id/widget_flame_progress"
        style="?android:attr/progressBarStyleHorizontal"
        android:layout_width="match_parent"
        android:layout_height="4dp"
        android:layout_marginTop="5dp"
        android:max="100"
        android:progressTint="@color/focus_ember" />

    <TextView
        android:id="@+id/widget_flame_next"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="5dp"
        android:ellipsize="end"
        android:fontFamily="@font/inter_500"
        android:maxLines="1"
        android:textColor="@color/focus_neutral_400"
        android:textSize="10sp" />
</LinearLayout>
```

- [ ] **Step 4: Write the provider**

`android/app/src/main/kotlin/com/focussayac/focussayac/widget/FlameWidgetProvider.kt`:

```kotlin
package com.focussayac.focussayac.widget

import android.widget.RemoteViews
import com.focussayac.focussayac.R

/**
 * Mesale widget (2x2) - geri sayim degil, kimlik. Biriken odak saatiyle
 * buyuyen kademe alevi ve sonraki kademeye kalan saat. Dokununca rozetler
 * ekranini acar; kalan saat orada tam kartiyla duruyor.
 */
class FlameWidgetProvider : BaseFocusWidgetProvider() {

    override val layoutId: Int = R.layout.widget_flame
    override val rootId: Int = R.id.widget_flame_root

    // Sinav durumundan bagimsiz: mesale sinava degil kullaniciya ait.
    override fun route(render: WidgetRenderContext): String = WidgetRoutes.BADGES

    override fun bind(render: WidgetRenderContext, views: RemoteViews) {
        val status = FlameTierLadder.statusFor(render.snapshot.cumulativeFocusSeconds)
        val context = render.context

        views.setImageViewBitmap(
            R.id.widget_flame_image,
            FlameRenderer.render(
                context = context,
                widthPx = render.px(FLAME_WIDTH_DP),
                heightPx = render.px(FLAME_HEIGHT_DP),
                tier = status.tier,
            ),
        )
        views.setTextViewText(
            R.id.widget_flame_tier,
            context.getString(FlameTierLadder.nameResFor(status.tier.index)),
        )
        views.setProgressBar(
            R.id.widget_flame_progress,
            100,
            (status.ratioInTier * 100).toInt(),
            false,
        )
        views.setTextViewText(
            R.id.widget_flame_next,
            if (status.isTopTier) {
                context.getString(R.string.widget_flame_top)
            } else {
                context.getString(R.string.widget_flame_next, status.hoursRemaining)
            },
        )
    }

    private companion object {
        const val FLAME_WIDTH_DP = 60f
        const val FLAME_HEIGHT_DP = 64f
    }
}
```

- [ ] **Step 5: Register the provider, route, resources and manifest entry**

`BaseFocusWidgetProvider.kt` — `PROVIDERS` listesine ekle:

```kotlin
            FlameWidgetProvider::class.java,
```

`WidgetRoutes.kt` — `EXAM_EXPIRED` satırının altına:

```kotlin
    /** Mesale widget: kalici avatarin tam karti Ekran 04'te. */
    const val BADGES = "/badges"
```

`res/xml/widget_flame_info.xml` — `widget_streak_info.xml`'i kopyala, şunları değiştir:
`android:initialLayout="@layout/widget_flame"`,
`android:previewLayout="@layout/widget_flame"`,
`android:label="@string/widget_flame_label"`,
`android:description="@string/widget_flame_description"`.
`minWidth`/`minHeight`/`resizeMode`/`updatePeriodMillis` aynen kalsın.

`res/drawable/widget_preview_flame.xml` — `widget_preview_spark.xml`'i kopyala,
içindeki şekli tek bir ember renkli oval yap (yalnızca seçici önizlemesi;
gerçek çizim çalışma zamanında bitmap'ten geliyor).

`AndroidManifest.xml` — mevcut `StreakWidgetProvider` receiver bloğunu kopyala
ve iki adı değiştir:

```xml
        <receiver
            android:name=".widget.FlameWidgetProvider"
            android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/widget_flame_info" />
        </receiver>
```

> **Not:** `android:exported` ve diğer nitelikleri dosyadaki mevcut
> receiver'lardan birebir kopyala; yukarıdaki blok kalıbı gösteriyor.

- [ ] **Step 6: Verify the build**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL. Kotlin derleme hatası varsa `R.string.*` / `R.id.*`
adlarının Step 1 ve Step 3'tekilerle birebir aynı olduğunu kontrol et.

Run: `flutter test test/android/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add android/
git commit -m "Altinci widget: Mesale (2x2) kademe alevi ve kalan saat"
```

---

## Task 11: Widget dokunuşunu `/badges`'e bağla

**Files:**
- Modify: `lib/services/widgets/widget_launch_handler.dart:64-66`
- Test: `test/services/widgets/widget_launch_handler_test.dart` (yoksa oluştur)

- [ ] **Step 1: Write the failing test**

Önce mevcut bir dokunuş testi var mı bak:

```bash
ls test/services/widgets/
```

Varsa ona ekle; yoksa `test/features/countdown/countdown_navigation_test.dart`
içindeki yönlendirme kalıbını uyarla (`appRouterProvider` + `HomeWidget`
tıklama akışı). Testin çekirdeği:

```dart
  testWidgets('meşale widgetına dokunuş rozetler ekranını açıyor',
      (WidgetTester tester) async {
    // `/badges` tanınmayan yol olarak kalırsa kullanıcı geri sayıma düşer —
    // widget'ın vaat ettiği ekran açılmaz.
    await _tapWidgetUri(tester, Uri.parse('focussayac://widget/badges'));
    expect(find.byType(BadgesScreen), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/widgets/`
Expected: FAIL — `BadgesScreen` yerine `CountdownScreen` bulunur (`default` dalı).

- [ ] **Step 3: Write the implementation**

`lib/services/widgets/widget_launch_handler.dart` — `case RoutePaths.stats:`
satırının yanına ekle:

```dart
      case RoutePaths.stats:
      case RoutePaths.badges:
      case RoutePaths.examExpired:
        router.go(path);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/widgets/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/widgets/widget_launch_handler.dart test/services/widgets/
git commit -m "Mesale widget dokunusu rozetler ekranini aciyor"
```

---

## Task 12: Tam test geçişi ve analiz

**Files:** yok — doğrulama görevi.

- [ ] **Step 1: Run the full suite**

Run: `flutter test`
Expected: Tüm testler PASS. Düşen varsa düzelt — özellikle:
- `focus_session_screen_test.dart` (alev API'si değişti)
- `badge_progress_test.dart` / `badge_unlock_dialog_test.dart` (ekrana kart eklendi)
- `home_widget_service_test.dart` (payload büyüdü)

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Verify the release build**

Run: `flutter build apk --release`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "Tam test gecisi"
```

---

## Task 13: Emülatörde görsel doğrulama

Kotlin tarafında birim testi yok; `FlameRenderer` yalnızca gözle doğrulanabilir.

- [ ] **Step 1: Install on the emulator**

Run: `flutter install`

- [ ] **Step 2: Check the tier avatar on Screen 04**

Rozetler sekmesini aç. Doğrula:
- Kahraman kart ızgaranın üstünde, alev kesilmemiş/taşmamış
- Kademe adı, sayaç ve kalan saat satırı okunuyor
- Açık ve koyu temada alevin ucu zemine karışmıyor

- [ ] **Step 3: Check the flame during a session**

Odak seansı başlat. Doğrula:
- Alev seans başında **kademe boyutunda** (küçük başlayıp büyümüyor)
- Seans ilerledikçe çekirdek parlıyor ve titreşim canlanıyor, **boyut sabit**
- Duraklatınca alev soluyor ve donuyor
- Seans bitince alev kademe boyutunda kalıyor, küçülmüyor

- [ ] **Step 4: Add and check the widget**

Ana ekrana Meşale widget'ını ekle. Doğrula:
- Alev, kademe adı, şerit ve "Sonraki: X sa" görünüyor
- Dokununca uygulama **Rozetler** ekranında açılıyor
- Bir seans tamamlandığında widget yenileniyor

- [ ] **Step 5: Record if anything looks wrong**

Kare/animasyon şüphesi varsa `adb shell screenrecord` + `ffmpeg` ile kare kare
bak — `adb` PATH'te değil, tam yolla çağır.

---

## Task 14: Belgeleri güncelle

**Files:**
- Modify: `docs/superpowers/specs/2026-09-12-mesale-kademe-avatari-design.md`
- Modify: `SPEC.md` (§5.5), `DECISIONS.md`, `ROADMAP.md`

- [ ] **Step 1: Correct the spec's flicker decision**

Tasarım belgesinde "Rozet kartındaki avatar da hafif titrer" diyen paragrafı
şununla değiştir:

```markdown
Rozet kartındaki avatar **titremiyor** (`flickering: false`). Uygulama
sırasında çıkan kısıt: `test/features/badges/badge_progress_test.dart` ve
`badge_unlock_dialog_test.dart` `pumpAndSettle` kullanıyor, sonsuz tekrarlı
bir tikleyici o testleri zaman aşımına düşürür. Durağan portre kimlik için
zaten daha doğru ve pil için bedava.
```

- [ ] **Step 2: Update SPEC.md §5.5**

Mevcut "`progress` 0→1 ile alev büyür" cümlesini şununla değiştir:

```markdown
### 5.5 Meşale
Alevin **boyutu** kümülatif odak saatinden gelen kademeden (`flame_tier.dart`,
10 basamak, 0–400 sa) gelir ve asla küçülmez. Seans `progress`i 0→1 yalnızca
çekirdek parlaklığını, titreşim genliğini ve kıvılcım yoğunluğunu sürer.
Duraklıyken `ColorFiltered` ile doygunluk 0 ve titreşim durur.
Kademe eşikleri saat rozetlerini (10/50/100/250) içerir.
```

- [ ] **Step 3: Add a DECISIONS.md section**

Dosyanın sonuna yeni bir faz başlığı aç ve şunları yaz:
- Seans ekseninin boyuttan ayrılma gerekçesi (K9→K10 farkı %6)
- Rozet merdiveniyle hizalama kararı ve elenen "rozetleri yut" alternatifinin
  `badgeByKey()` fırlatma riski
- Merdivenin Kotlin'de ikinci kez tanımlanması ve senkron testi
- `cumulativeFocusSeconds`ın ham gönderilme gerekçesi
- Rozet kartındaki alevin titrememesi ve `pumpAndSettle` kısıtı

- [ ] **Step 4: Add a ROADMAP.md entry**

Tamamlanan iş listesine kademe avatarını ekle; mevcut girdilerin biçimini izle.

- [ ] **Step 5: Commit**

```bash
git add SPEC.md DECISIONS.md ROADMAP.md docs/
git commit -m "Kademe avatari kararlari belgelendi"
```

---

## Öz-inceleme notları

**Spec kapsamı:** Tasarımın her bölümünün bir görevi var — merdiven (T1),
hizalama (T2), sağlayıcı (T3), iki eksen (T4), odak ekranı (T5), metinler (T6),
kahraman kart (T7), payload (T8), Kotlin merdiven + senkron (T9), renderer +
widget (T10), rota (T11), doğrulama (T12–13), belgeler (T14).

**Spec'ten tek sapma:** Rozet kartındaki alev titremiyor. Gerekçe Task 7'de,
spec düzeltmesi Task 14 Step 1'de.

**Tip tutarlılığı:** `FlameTier` alanları (`index`, `thresholdHours`, `scale`,
`emberBase`, `sparkCount`, `haloOpacity`) Dart (T1), senkron testi (T9) ve
Kotlin (T9) tarafında aynı adlarla. `FlameTierStatus` alanları (`tier`,
`nextTier`, `hoursRemaining`, `ratioInTier`, `cumulativeHours`, `isTopTier`)
Dart (T1), kart (T7) ve Kotlin (T9–T10) tarafında aynı. `FlameWidget`
parametreleri (`tier`, `boxHeight`, `intensity`, `flickering`, `desaturated`)
T4'te tanımlanıp T5 ve T7'de aynı adlarla çağrılıyor.

**Bilinen sıra bağımlılıkları:**
- T1'de `FlameTier.name()` yazılmıyor (ARB anahtarları yok); T6 ekliyor.
- T9'daki `nameResFor` T10'un string kaynaklarına dayanıyor; Kotlin derlemesi
  T10 Step 6'da doğrulanıyor.
