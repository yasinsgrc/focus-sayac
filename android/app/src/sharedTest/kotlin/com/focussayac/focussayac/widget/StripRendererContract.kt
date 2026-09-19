package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import kotlin.math.abs

/**
 * `StripRenderer` cizim yolunun sozlesmesi. ROADMAP madde 39; tasarim:
 * docs/superpowers/specs/2026-09-19-kotlin-renderer-dogrulama-design.md
 *
 * Kalip madde 31'den: iddialar burada, iki kosum evi de bu dosyayi derliyor.
 *
 * Serit halkanin dairesel ilerlemesinin duz cizgiye acilmis hali, yani
 * sinanan sey de ayni: **dolgunun ucu nerede duruyor**. Sonda cubugun orta
 * satirini tariyor; iz 0x12 alfayla, dolgu opak ciziliyor, 0x80 esigi ikisini
 * ayiriyor.
 */
object StripRendererContract {

    /** Uretimdeki olcu: StripWidgetProvider 240x6dp istiyor (~2.6x yogunluk). */
    const val WIDTH_PX = 630
    const val HEIGHT_PX = 15

    /** Iz ile dolguyu ayiran esik. */
    private const val DRAWN = 0x80

    /**
     * Sinav rengi bilerek SOGUK. Dolgunun gradyani accent -> koz gidiyor;
     * yonu ancak iki ucun sicakligi birbirine karsi olculunce gorunuyor.
     * Kozun kendisi paletten geliyor ve iki temada da sicak
     * (#FFA35D00 / #FFFFB03A), yani iddia niteleyiciden bagimsiz.
     */
    private val ACCENT = 0xFF63B4FF.toInt()

    /** Merdiven: oran yuzde olarak, bitmap'e. */
    val RATIO_PERCENTS = listOf(5, 25, 50, 75, 100)

    fun render(context: Context, ratio: Float): Bitmap = StripRenderer.render(
        context = context,
        widthPx = WIDTH_PX,
        heightPx = HEIGHT_PX,
        ratio = ratio,
        accentColor = ACCENT,
    )

    fun renderLadder(context: Context): Map<Int, Bitmap> =
        RATIO_PERCENTS.associateWith { render(context, it / 100f) }

    /**
     * 1. Cizim gercekten oldu ve iz cubugun bir ucundan digerine kesintisiz:
     * dolgunun nerede bittigi ancak izin her yerde durdugu bilinirse bir sey
     * ifade ediyor.
     */
    fun verifyTrack(bitmap: Bitmap) {
        assertEquals("genislik", WIDTH_PX, bitmap.width)
        assertEquals("yukseklik", HEIGHT_PX, bitmap.height)

        val midY = HEIGHT_PX / 2
        for (x in 2 until WIDTH_PX - 2) {
            val alpha = Color.alpha(bitmap.getPixel(x, midY))
            assertTrue("iz $x pikselinde kopuk (alfa $alpha)", alpha > 8)
        }
    }

    /**
     * 2. Dolgunun ucu orana bagli. Halkanin merdiveniyle ayni iddia, duz
     * cizgide: yuzde kac soylenirse cubugun o kadari doluyor.
     */
    fun verifyFillLadder(bitmaps: Map<Int, Bitmap>) {
        assertEquals("merdiven basamagi", RATIO_PERCENTS.size, bitmaps.size)

        val failures = mutableListOf<String>()
        RATIO_PERCENTS.forEach { percent ->
            val expected = WIDTH_PX * (percent / 100f)
            val measured = fillWidth(bitmaps.getValue(percent))
            if (abs(measured - expected) > 2f) {
                failures += "%$percent dolgu: beklenen ~${expected.toInt()} px, olculen $measured px"
            }
        }
        if (failures.isNotEmpty()) {
            throw AssertionError(failures.joinToString(separator = "\n", prefix = "\n"))
        }

        val widths = RATIO_PERCENTS.map { fillWidth(bitmaps.getValue(it)) }
        widths.zipWithNext().forEachIndexed { i, (shorter, longer) ->
            assertTrue(
                "%${RATIO_PERCENTS[i]} -> %${RATIO_PERCENTS[i + 1]} dolgu uzamiyor " +
                    "($shorter -> $longer)",
                longer > shorter,
            )
        }
    }

    /**
     * 3. Cok kucuk oranlarda dolgu kaybolmuyor: en az bir yuvarlak uc kadar
     * kaliyor. Renderer'in kendi sozu; oran sifirken de gecerli, cunku
     * `StripWidgetProvider` sinav secilmemisken 0 gonderiyor ve serit o zaman
     * bos bir izle degil, bir kapakla duruyor.
     */
    fun verifyMinimumFill(context: Context) {
        listOf(0f, 0.001f).forEach { ratio ->
            val measured = fillWidth(render(context, ratio))
            assertTrue(
                "oran $ratio: dolgu ${measured}px, beklenen ~$HEIGHT_PX px (bir kapak)",
                abs(measured - HEIGHT_PX) <= 2f,
            )
        }
    }

    /**
     * 4. Gradyanin yonu: dolgu sinav renginde basliyor, kozda bitiyor -
     * "sinav yaklastikca cubugun ucu isiniyor".
     */
    fun verifyGradientDirection(bitmap: Bitmap) {
        val midY = HEIGHT_PX / 2
        val left = warmth(bitmap.getPixel(4, midY))
        val right = warmth(bitmap.getPixel(WIDTH_PX - 5, midY))
        assertTrue(
            "dolgu kozda bitmiyor (bas $left, son $right)",
            right - left > 100,
        )
    }

    /** Orta satirda dolgunun bittigi piksel + 1 - yani dolgunun genisligi. */
    private fun fillWidth(bitmap: Bitmap): Float {
        val midY = bitmap.height / 2
        for (x in bitmap.width - 1 downTo 0) {
            if (Color.alpha(bitmap.getPixel(x, midY)) >= DRAWN) return (x + 1).toFloat()
        }
        return 0f
    }

    private fun warmth(pixel: Int): Int = Color.red(pixel) - Color.blue(pixel)
}
