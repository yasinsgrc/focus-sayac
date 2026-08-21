# FocusSayaç — Flutter App Design (v1, Android-first)

## Purpose

Turn the FocusSayaç design prototype (`FocusSayac Prototip.dc.html`, Nocturne design
system) into a working Flutter app: an exam countdown + Pomodoro focus timer for
students preparing for Turkish national exams (YKS, KPSS, LGS, ALES).

v1 target: a functional, store-ready Android app (Google Play). iOS/App Store is a
later phase — Flutter code is cross-platform from day one, but building, signing, and
submitting an iOS binary requires Xcode on macOS, which isn't available in this
environment. That phase starts once a Mac is available.

## Product decisions (locked in during brainstorming)

- **No accounts, no backend.** All data lives on-device (matches the prototype's own
  copy: "Tüm veriler cihazında kalır").
- **Monetization:** free app with a banner ad (AdMob) on the Stats screen, plus a
  one-time "Pro" in-app purchase that removes ads. Badges always unlock through
  achievement, never payment.
- **Scope:** all 8 prototype screens ship in v1 — Onboarding, Countdown, Pomodoro,
  Badges, Story Card, Stats, Settings, Empty State.

## Architecture

- Flutter, feature-first structure:
  `lib/features/{onboarding,countdown,pomodoro,badges,story_card,stats,settings}/`,
  with shared code in `lib/core/` (Nocturne design tokens/theme, routing, database).
- State management: **Riverpod**.
- Local persistence: **Drift** (typed SQLite). Chosen over Hive/Isar because the
  stats screen needs relational aggregation (weekly totals, streaks, completion %)
  that's awkward to hand-roll over a NoSQL box store, and Drift has the most mature
  long-term maintenance story of the three options considered.

## Data model (Drift tables)

- **Exam** — `id, name, subtitle, date, icon, isPreset, isActive`. Seeded with 4
  presets matching the prototype (YKS, KPSS, LGS, ALES); users can add their own via
  "Kendi sınavımı ekle".
- **PomodoroSession** — `id, examId, type(focus|shortBreak|longBreak), startedAt,
  completedAt, plannedDurationSec, completed`. Cycle: 4 focus sessions per long break,
  matching the prototype's "ODAK · 3/4" indicator and 4-dot progress row.
- **UserBadge** — `badgeKey, unlockedAt`. The 7 badges themselves (name, rule, icon)
  are a static catalog in code, not DB rows — the DB only tracks which are unlocked
  and when:
  1. İlk Kıvılcım — first completed pomodoro
  2. Odak Meşalesi — 4 pomodoros in one day
  3. Sabah Yıldızı — a session started before 08:00
  4. Gece Nöbeti — a session started after 23:00
  5. Haftalık Seri — 7-day streak
  6. Maraton — 8 pomodoros in one day
  7. 100 Saat Kulübü — 100 cumulative focus hours
- **Settings** — single row: `focusMinutes, shortBreakMinutes, longBreakMinutes,
  notificationsEnabled, soundEnabled, hapticEnabled, isPremium, selectedTemplateIndex,
  activeExamId`. Defaults: 25/5/15 minutes (matches the prototype's settings sliders).

Stats (weekly chart, total focus hours, daily average, longest streak, completion %,
most productive hour range) are **not** a separate stored table — they're computed
on demand via SQL queries over `PomodoroSession`. Data volume is small (single local
user), so a materialized aggregate table would add sync complexity for no real
benefit.

**Streak definition:** a day counts toward the streak if it has ≥1 completed focus
session. The streak is the count of consecutive such days ending today or yesterday
(a streak stays "alive" through the current day until midnight passes with no
session).

## Timer strategy

The countdown displayed in-app is always recomputed from `startedAt + plannedDuration`
against the wall clock — never a decrementing in-memory counter — so it can't drift
when the app is backgrounded and resumed.

When a session starts, a local notification is scheduled for its end time
(`flutter_local_notifications`, using `zonedSchedule`). On Android 12+, this needs the
exact-alarm permission, requested during onboarding (matches the prototype's
"Tam zamanlı alarm" permission card). The screen is kept awake during an active
session via `wakelock_plus`, matching the prototype's hint text ("Ekran açık kalır ·
bitişte bildirim kurulu").

This avoids running a persistent foreground service — simpler to implement and an
easier Play Store review (no need to justify continuous background execution).

## Ads & Premium

- One banner ad placement: the Stats screen, exactly where the prototype shows the
  "Adaptive banner · 320×50" placeholder. No interstitials in v1 — the prototype
  doesn't call for them, and inserting them wasn't requested.
- `google_mobile_ads` for the banner; `in_app_purchase` for the one-time Pro
  purchase, which sets `Settings.isPremium = true` and hides the ad.
- Story-card templates: the prototype currently defines 3 templates and none of them
  are shown as locked. All 3 ship free in v1. Premium's template benefit is a future
  extension point (additional templates gated behind `isPremium`) — not a v1 feature,
  since there's nothing in the current design to gate.

## Story card export (screen 5)

Render the card widget via `RenderRepaintBoundary` to a 1080×1920 PNG. Three actions,
matching the prototype exactly: share (`share_plus`), save to gallery (`gal`), copy
to clipboard (`pasteboard`).

## Empty state (screen 8)

When the active exam's date has passed, the countdown screen routes to the empty
state automatically. Focus history and badges are preserved (shown in the copy);
"Yeni sınav seç" reopens the exam-picker sheet from screen 2.

## Settings screen content

The prototype renders this list from placeholder data (`sc-for list="{{ settings }}"`)
without specifying real items beyond the three duration sliders (Odak/Kısa
mola/Uzun mola). Proposed real items, since none were specified: Bildirimler, Ses,
Titreşim, Hakkında, Gizlilik Politikası, Uygulamayı Değerlendir — plus "Reklamları
kaldır" wired to the Pro purchase (shown as "Yakında" in the prototype).

## Testing strategy

- Unit tests for the streak/badge-unlock logic and Drift stats queries — pure logic,
  the highest-risk-of-silent-bugs part of the app.
- Widget tests for the critical flows: pomodoro phase transitions (focus → break →
  next focus → long break after 4), and the countdown → empty-state routing when an
  exam date has passed.

## Out of scope for v1

- iOS build/signing/App Store submission (separate phase, needs macOS).
- Cloud sync / accounts.
- Subscription billing (only a one-time Pro purchase).
- Interstitial or rewarded ads.
