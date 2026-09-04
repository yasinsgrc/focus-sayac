package com.focussayac.focussayac.widget

import android.content.SharedPreferences
import android.graphics.Color
import kotlin.math.max

/**
 * Dart'in `HomeWidgetSnapshot`'inin Kotlin tarafindaki okuyucusu. Anahtarlar
 * `lib/domain/widgets/home_widget_snapshot.dart` ile birebir ayni.
 *
 * Kalan gun ve oran BURADA hesaplanir, Dart'tan okunmaz: uygulama gunlerce
 * acilmasa bile widget dogru sayiyi gosterir.
 */
data class FocusWidgetSnapshot(
    val hasActiveExam: Boolean,
    val examName: String,
    val examSubtitle: String,
    val targetUtcMillis: Long,
    val accentColor: Int?,
    val streak: Int,
    val todayMinutes: Int,
    val weeklyMinutes: List<Int>,
    val sessionActive: Boolean,
) {
    enum class State { NO_EXAM, COUNTING, TODAY, EXPIRED }

    /** Sayac asla negatife dusmez - Dart'taki `remainingDuration` ile ayni kural. */
    fun remainingMillis(nowMillis: Long): Long = max(0L, targetUtcMillis - nowMillis)

    fun daysLeft(nowMillis: Long): Int = (remainingMillis(nowMillis) / DAY_MS).toInt()

    /** Gun artigindan kalan tam saat - Serit widget'inin ikinci sayisi. */
    fun hoursLeft(nowMillis: Long): Int =
        ((remainingMillis(nowMillis) % DAY_MS) / HOUR_MS).toInt()

    /**
     * `lib/domain/countdown/countdown_math.dart` ile birebir ayni formul:
     * `clamp(1 - days/400, 0.06, 1)`.
     */
    fun progressRatio(nowMillis: Long): Float =
        (1f - daysLeft(nowMillis) / 400f).coerceIn(0.06f, 1f)

    fun state(nowMillis: Long): State = when {
        !hasActiveExam -> State.NO_EXAM
        targetUtcMillis <= nowMillis -> State.EXPIRED
        daysLeft(nowMillis) == 0 -> State.TODAY
        else -> State.COUNTING
    }

    companion object {
        private const val DAY_MS = 86_400_000L
        private const val HOUR_MS = 3_600_000L
        const val WEEKLY_LENGTH = 7

        /**
         * [widgetData] home_widget eklentisinin paylasilan tercihleri -
         * HomeWidgetProvider.onUpdate tarafindan hazir veriliyor.
         */
        fun load(widgetData: SharedPreferences): FocusWidgetSnapshot {
            // prefs.all uzerinden okunuyor cunku Dart int degeri platform
            // kanalindan Integer ya da Long olarak gelebiliyor (32 bite
            // sigip sigmadigina gore). Number uzerinden coerce etmek ikisini
            // de guvenle karsiliyor; getInt/getLong biri icin
            // ClassCastException atardi.
            val all: Map<String, Any?> = widgetData.all

            return FocusWidgetSnapshot(
                hasActiveExam = all.bool("hasActiveExam"),
                examName = all.str("examName"),
                examSubtitle = all.str("examSubtitle"),
                targetUtcMillis = all.long("targetUtcMillis"),
                accentColor = parseColorOrNull(all.str("accentHex")),
                streak = all.int("streak"),
                todayMinutes = all.int("todayMinutes"),
                weeklyMinutes = parseWeekly(all.str("weeklyMinutes")),
                sessionActive = all.bool("sessionActive"),
            )
        }

        private fun parseColorOrNull(hex: String): Int? = try {
            if (hex.isBlank()) null else Color.parseColor(hex)
        } catch (_: IllegalArgumentException) {
            // Bozuk hex widget'i cizilmez yapmamali; cagiran notr renge duser.
            null
        }

        /** Her zaman 7 elemana normalize edilir - cizici sabit uzunluk bekler. */
        private fun parseWeekly(raw: String): List<Int> {
            val parsed = raw.split(',').mapNotNull { it.trim().toIntOrNull() }
            return List(WEEKLY_LENGTH) { index ->
                val offset = parsed.size - WEEKLY_LENGTH + index
                if (offset in parsed.indices) parsed[offset] else 0
            }
        }

        private fun Map<String, Any?>.str(key: String): String = this[key] as? String ?: ""
        private fun Map<String, Any?>.bool(key: String): Boolean = this[key] as? Boolean ?: false
        private fun Map<String, Any?>.int(key: String): Int = (this[key] as? Number)?.toInt() ?: 0
        private fun Map<String, Any?>.long(key: String): Long = (this[key] as? Number)?.toLong() ?: 0L
    }
}
