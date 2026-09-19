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
    private const val CORNER_RATIO = 0.26f

    /** Sifir gunun tabani: grafigin yuksekliginin bu kadari. */
    private const val BASELINE_RATIO = 0.06f

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
        // Yaricap bilerek kucuk. barWidth/2 denenmisti: butun gunler sifirken
        // sutun yuksekligi genisligine esitleniyor ve yuvarlatilmis
        // dikdortgen tam daireye donusuyordu; ImageView fitXY ile gerince de
        // ovallesiyordu. Sutunlar sutun gibi okunmali.
        val radius = barWidth * CORNER_RATIO
        // Odak yapilmamis gun bosluk degil, ince bir taban birakir: bos hafta
        // "veri yok" degil "sifir" olarak okunmali.
        //
        // Pay grafigin YUKSEKLIGINDEN aliniyor - ROADMAP madde 39. Onceden
        // `radius * 2f` idi, yani sutun GENISLIGINE bagliydi ve genis sutunlu
        // yerlesimde tabani bir sutun boyuna cikariyordu: panoramada
        // (140x22dp) taban yuksekligin %32'si oluyor, 120 dakikalik bir
        // haftada 20 dakikalik gun ile hic odaklanilmamis gun AYNI
        // ciziliyordu. Grafik sessizce yaniltiyordu; hicbir test kosmadigi
        // icin gorulmemisti.
        val minHeight = heightPx * BASELINE_RATIO

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
