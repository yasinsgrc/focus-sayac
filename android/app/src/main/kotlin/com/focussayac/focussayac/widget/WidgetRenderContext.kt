package com.focussayac.focussayac.widget

import android.content.Context
import com.focussayac.focussayac.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Tek bir cizim gecisinin turetilmis degerleri. Bes saglayici da ayni
 * gun/oran/renk/metin kararlarini paylassin diye burada bir kez hesaplaniyor:
 * ayni sayinin iki widget icinde farkli cikmasi mumkun olmasin.
 */
class WidgetRenderContext(
    val context: Context,
    val snapshot: FocusWidgetSnapshot,
    val nowMillis: Long,
    val palette: FocusPalette,
) {
    val state: FocusWidgetSnapshot.State = snapshot.state(nowMillis)

    /** Sinav secilmemisken ve sinav gectiginde widget sesini kisar. */
    val muted: Boolean =
        state == FocusWidgetSnapshot.State.NO_EXAM || state == FocusWidgetSnapshot.State.EXPIRED

    val accent: Int =
        if (muted) palette.neutralAccent else snapshot.accentColor ?: palette.accent400

    val daysLeft: Int = snapshot.daysLeft(nowMillis)
    val hoursLeft: Int = snapshot.hoursLeft(nowMillis)
    val ratio: Float = snapshot.progressRatio(nowMillis)

    /** Halkanin ortasindaki buyuk rakam. Sinav secilmemisken sayi degil, tire. */
    fun dayText(): String =
        if (state == FocusWidgetSnapshot.State.NO_EXAM) EM_DASH else daysLeft.toString()

    /** Rakamin altindaki kicker - durumun adi. */
    fun statusLabel(): String = context.getString(
        when (state) {
            FocusWidgetSnapshot.State.NO_EXAM -> R.string.widget_no_exam_title
            FocusWidgetSnapshot.State.EXPIRED -> R.string.widget_expired_title
            FocusWidgetSnapshot.State.TODAY -> R.string.widget_today
            FocusWidgetSnapshot.State.COUNTING -> R.string.widget_days_left
        }
    )

    /** Sinav adi satiri; sinav secilmemisken cagriya donusur. */
    fun examLine(): String = when (state) {
        FocusWidgetSnapshot.State.NO_EXAM -> context.getString(R.string.widget_pick_exam)
        else -> snapshot.examName
    }

    /** Serit widget icin kompakt deger: 147g 06s, ya da durumun adi. */
    fun compactRemaining(): String = when (state) {
        FocusWidgetSnapshot.State.COUNTING ->
            String.format(TR, "%dg %02ds", daysLeft, hoursLeft)
        else -> statusLabel()
    }

    /** Panorama kartinin ikinci satiri: sinav gunu. */
    fun examDateLine(): String {
        if (!snapshot.hasActiveExam) return context.getString(R.string.widget_no_exam_title)
        return SimpleDateFormat("d MMMM y", TR).format(Date(snapshot.targetUtcMillis))
    }

    /** Seri rozeti: 12 gun seri. */
    fun streakLine(): String = context.getString(R.string.widget_streak_days, snapshot.streak)

    /** Bugunku odak: 75 dk. */
    fun todayLine(): String = context.getString(R.string.widget_minutes, snapshot.todayMinutes)

    fun px(dp: Float): Int = context.widgetPx(dp).toInt()

    private companion object {
        const val EM_DASH = "–"
        val TR: Locale = Locale("tr", "TR")
    }
}
