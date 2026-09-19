package com.focussayac.focussayac.widget

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `FocusWidgetSnapshot`in haftalik hedef turetmeleri - ROADMAP madde 41.
 *
 * Halkanin emek yayi oranini ve tonunu Dart'tan okumuyor, bu iki fonksiyondan
 * turetiyor. Robolectric gerekmiyor: fonksiyonlar saf, Android'e dokunmuyor.
 *
 * Dart tarafindaki ikizi `WeeklyGoalProgress` (`ratio`, `isOff`, `isReached`);
 * kurallar birebir ayni olmak zorunda, yoksa widget ile Ekran 02 ayni hafta
 * icin farkli bir yay cizer.
 */
class FocusWidgetSnapshotTest {

    private fun snapshot(goalSeconds: Int, focusedSeconds: Int) = FocusWidgetSnapshot(
        hasActiveExam = true,
        examName = "YKS 2026",
        examSubtitle = "Temel Yeterlilik",
        targetUtcMillis = 1_781_000_000_000L,
        accentColor = null,
        streak = 12,
        todayMinutes = 75,
        todayPomodoros = 3,
        weeklyMinutes = List(FocusWidgetSnapshot.WEEKLY_LENGTH) { 25 },
        sessionActive = false,
        cumulativeFocusSeconds = 3600,
        weeklyGoalSeconds = goalSeconds,
        weeklyFocusedSeconds = focusedSeconds,
    )

    @Test
    fun `hedef kapaliyken oran null, sifir degil`() {
        // Bos bir yay "hedefinin %0'indasin" derdi; kullanicinin koydugu bir
        // hedef yok, o yuzden yay hic cizilmiyor.
        assertNull(snapshot(goalSeconds = 0, focusedSeconds = 7200).weeklyEffortRatio())
        assertFalse(snapshot(goalSeconds = 0, focusedSeconds = 7200).weeklyGoalReached())
    }

    @Test
    fun `hedef acik ve bos hafta sifir oran verir`() {
        // `null` degil `0f`: hedef var, yayin izi duruyor, yalnizca yay bos.
        assertEquals(0f, snapshot(goalSeconds = 36_000, focusedSeconds = 0).weeklyEffortRatio())
    }

    @Test
    fun `oran odagin hedefe bolumu`() {
        val ratio = snapshot(goalSeconds = 36_000, focusedSeconds = 15_000).weeklyEffortRatio()
        assertEquals(15_000f / 36_000f, ratio!!, 0.0001f)
    }

    @Test
    fun `hedefi asan hafta 1'de kirpilir`() {
        // Hedefini uce katlayan kullanicida yay kendi rayini tasmasin diye.
        assertEquals(1f, snapshot(goalSeconds = 36_000, focusedSeconds = 120_000).weeklyEffortRatio())
    }

    @Test
    fun `sinir dahil - tam tutturan hafta ulasilmis sayilir`() {
        assertTrue(snapshot(goalSeconds = 36_000, focusedSeconds = 36_000).weeklyGoalReached())
        assertFalse(snapshot(goalSeconds = 36_000, focusedSeconds = 35_940).weeklyGoalReached())
    }

    @Test
    fun `ulasilmislik orandan okunamaz - kirpma ikisini ayirir`() {
        // Oran 1.0'da kirpili: hedefi tam tutturmakla asmak ayni sayi. Bu
        // yuzden `weeklyGoalReached` ayri bir soru, payload da oran degil iki
        // ham operand tasiyor.
        val exact = snapshot(goalSeconds = 36_000, focusedSeconds = 36_000)
        val over = snapshot(goalSeconds = 36_000, focusedSeconds = 72_000)
        assertEquals(exact.weeklyEffortRatio(), over.weeklyEffortRatio())
        assertTrue(exact.weeklyGoalReached() && over.weeklyGoalReached())
    }
}
