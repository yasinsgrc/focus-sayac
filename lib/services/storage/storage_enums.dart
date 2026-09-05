/// Drift `textEnum` sütunlarında kullanılan sabit kümeler. Enum adları
/// veritabanına metin olarak yazılır (`drift`'in `EnumNameConverter`'ı) —
/// bu yüzden bir kez yayınlandıktan sonra üye adları değiştirilmemeli.
library;

/// [PomodoroSession.type] — SPEC.md §4.
enum SessionType { focus, shortBreak, longBreak }

/// [Exam.accentRole] — SPEC.md Ekran 11 vurgu paleti: yalnızca bu beşi.
enum ExamAccentRole { ember, mint, rose, sky, accent }

/// [Exam.source] — SPEC.md §4 üç katmanlı sınav tarihi kaynağı.
enum ExamSourceType { user, remote, seed }

/// [AppSettings.themeMode] — Ekran 07 tema satırı (Faz 17). Flutter'ın
/// `ThemeMode`'u doğrudan saklanmıyor: bu enum depolama sözleşmesi, üye adları
/// veritabanına metin olarak gidiyor ve framework'ün kendi enum'u değişse bile
/// sabit kalmalı.
enum AppThemeMode { system, light, dark }
