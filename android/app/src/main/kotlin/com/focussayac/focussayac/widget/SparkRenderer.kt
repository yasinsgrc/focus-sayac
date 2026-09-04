package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF

/**
 * Son 7 gunun odak dakikasini minik sutunlarla cizer - Ekran 06 icindeki
 * WeeklyFocusBarPainter mantiginin widget olcegine indirilmis hali.
 *
 * Bugun (son sutun) tam accent renginde, gecmis gunler ayni rengin solgun
 * hali. Odak yapilmamis gun bosluk birakmiyor, ince bir taban cizgisi
 * birakiyor: bos hafta "veri yok" degil "sifir" olarak okunmali.
 */
object SparkRenderer {

    private const val BAR_COUNT = 7
    private const val PAST_ALPHA = 0x4D

    fun render(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        values: List<Int>,
        accentColor: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val gapPx = widthPx * 0.055f
        val barWidth = (widthPx - gapPx * (BAR_COUNT - 1)) / BAR_COUNT
        val radius = barWidth / 2f
        // Bos gunun gorunur kalmasi icin taban: yariciptan kucuk olamaz,
        // yoksa yuvarlatilmis dikdortgen kendini yiyor.
        val minHeight = radius * 2f

        val maxValue = (values.maxOrNull() ?: 0).coerceAtLeast(1)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        for (index in 0 until BAR_COUNT) {
            val value = values.getOrElse(index) { 0 }
            val fraction = value.toFloat() / maxValue
            val barHeight = (heightPx * fraction).coerceAtLeast(minHeight)
            val left = index * (barWidth + gapPx)
            val top = heightPx - barHeight

            val isToday = index == BAR_COUNT - 1
            paint.color = if (isToday) accentColor else withAlpha(accentColor, PAST_ALPHA)
            canvas.drawRoundRect(
                RectF(left, top, left + barWidth, heightPx.toFloat()),
                radius,
                radius,
                paint,
            )
        }
        return bitmap
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}
