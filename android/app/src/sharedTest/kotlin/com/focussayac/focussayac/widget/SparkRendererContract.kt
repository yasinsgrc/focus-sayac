package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * `SparkRenderer` cizim yolunun sozlesmesi. ROADMAP madde 39; tasarim:
 * docs/superpowers/specs/2026-09-19-kotlin-renderer-dogrulama-design.md
 *
 * Kalip madde 31'den: iddialar burada, iki kosum evi de bu dosyayi derliyor.
 *
 * Sparkline bir **grafik**, yani sozu tek: sutunun yuksekligi gunun odagini
 * gosterecek. Iddialar da bunun uzerine kurulu - kac sutun var, nerede
 * duruyorlar, yukseklikleri degerlerle ayni oranda mi, bugun ayirt ediliyor mu.
 *
 * Iki yerlesim var ve ikisi de sinaniyor: seri widget'i dar ve yuksek
 * (84x26dp), panorama genis ve alcak (140x22dp). Sutun genisligi orandan
 * geldigi icin ikisi ayni kodda farkli geometri uretiyor.
 */
object SparkRendererContract {

    /** SparkRenderer'in kendi sabiti; sutun sayisi haftanin gunu kadar. */
    private const val BAR_COUNT = 7

    /**
     * Sifir gunun tabani grafigin bu kadarini gecmemeli. Renderer'in kendi
     * sozu "ince bir taban cizgisi" - pay yuvarlamaya ve kenar yumusatmaya
     * birakildi, iddia orani siniyor.
     */
    private const val BASELINE_LIMIT = 0.12f

    /** Sutun yuksekligi ile deger arasindaki kabul edilen sapma. */
    private const val HEIGHT_TOLERANCE = 0.05f

    private val ACCENT = 0xFFFFB03A.toInt()

    /** Yedi gunun artan degerleri: her sutun bir oncekinden yuksek olmali. */
    val VALUES = listOf(0, 20, 40, 60, 80, 100, 120)

    /** Hic odak yapilmamis hafta. */
    val EMPTY_WEEK = List(BAR_COUNT) { 0 }

    /** Uretimdeki iki olcu (~2.6x yogunluk). */
    data class Layout(val name: String, val widthPx: Int, val heightPx: Int)

    val LAYOUTS = listOf(
        // StreakWidgetProvider: 84x26dp
        Layout("seri", 220, 68),
        // PanoramaWidgetProvider: 140x22dp
        Layout("panorama", 367, 57),
    )

    fun render(context: Context, layout: Layout, values: List<Int>): Bitmap =
        SparkRenderer.render(
            context = context,
            widthPx = layout.widthPx,
            heightPx = layout.heightPx,
            values = values,
            accentColor = ACCENT,
        )

    /**
     * 1. Yedi sutun var, yerlerinde duruyor ve son sutun kareden tasmiyor.
     * Sutunlar en alt satirdaki ayri murekkep oberkleriyle sayiliyor -
     * renderer'in yerlesim formulunu tekrar etmek testi duzeltmenin aynasina
     * cevirirdi.
     */
    fun verifyLayout(bitmap: Bitmap, layout: Layout) {
        assertEquals("${layout.name} genisligi", layout.widthPx, bitmap.width)
        assertEquals("${layout.name} yuksekligi", layout.heightPx, bitmap.height)

        val runs = inkRuns(bitmap, bitmap.height - 1)
        assertEquals("${layout.name} sutun sayisi", BAR_COUNT, runs.size)

        val gap = layout.widthPx * 0.055f
        val barWidth = (layout.widthPx - gap * (BAR_COUNT - 1)) / BAR_COUNT
        runs.forEachIndexed { index, run ->
            val expected = index * (barWidth + gap) + barWidth / 2f
            val measured = (run.first + run.last) / 2f
            assertTrue(
                "${layout.name} ${index + 1}. sutunun merkezi kaymis: " +
                    "beklenen ~${expected.roundToInt()}, olculen ${measured.roundToInt()}",
                abs(measured - expected) <= 3f,
            )
        }
    }

    /**
     * 2. Sutun yuksekligi gunun degerini gosteriyor. Sifir gun bosluk degil
     * **ince** bir taban birakiyor: bos hafta "veri yok" degil "sifir" olarak
     * okunmali, ama taban da bir gunun odagi gibi gorunmemeli.
     */
    fun verifyHeights(bitmap: Bitmap, layout: Layout, values: List<Int>) {
        val maxValue = (values.maxOrNull() ?: 0).coerceAtLeast(1)
        val failures = mutableListOf<String>()

        for (index in 0 until BAR_COUNT) {
            val value = values.getOrElse(index) { 0 }
            val height = barHeight(bitmap, layout, index)
            val drawn = height / layout.heightPx

            if (value == 0) {
                if (height < 2f) {
                    failures += "${layout.name} ${index + 1}. gun (0 dk) hic cizilmemis"
                }
                if (drawn > BASELINE_LIMIT) {
                    failures += "${layout.name} ${index + 1}. gun (0 dk) taban degil sutun: " +
                        "grafigin %${(drawn * 100).roundToInt()}'i, sinir %${(BASELINE_LIMIT * 100).roundToInt()}"
                }
                continue
            }

            val expected = value.toFloat() / maxValue
            if (abs(drawn - expected) > HEIGHT_TOLERANCE) {
                failures += "${layout.name} ${index + 1}. gun ($value dk) yanlis yukseklikte: " +
                    "beklenen %${(expected * 100).roundToInt()}, cizilen %${(drawn * 100).roundToInt()}"
            }
        }

        if (failures.isNotEmpty()) {
            throw AssertionError(failures.joinToString(separator = "\n", prefix = "\n"))
        }
    }

    /**
     * 3. Bugun (son sutun) tam accent renginde, gecmis gunler ayni rengin
     * solgun hali - grafik "bugun neredeyim" sorusunu da yanitliyor.
     */
    fun verifyTodayStandsOut(bitmap: Bitmap, layout: Layout) {
        val alphas = (0 until BAR_COUNT).map { alphaAtBar(bitmap, layout, it) }
        assertTrue("${layout.name} bugun solgun (alfa ${alphas.last()})", alphas.last() > 200)
        alphas.dropLast(1).forEachIndexed { index, alpha ->
            assertTrue(
                "${layout.name} ${index + 1}. gun bugunden ayrilmiyor (alfa $alpha)",
                alpha in 40..140,
            )
        }
    }

    /** [index] sutununun orta sutununda murekkebin basladigi yerden tabana. */
    private fun barHeight(bitmap: Bitmap, layout: Layout, index: Int): Float {
        val x = barCenterX(layout, index)
        for (y in 0 until bitmap.height) {
            if (Color.alpha(bitmap.getPixel(x, y)) > 0) return (bitmap.height - y).toFloat()
        }
        return 0f
    }

    private fun alphaAtBar(bitmap: Bitmap, layout: Layout, index: Int): Int =
        Color.alpha(bitmap.getPixel(barCenterX(layout, index), bitmap.height - 2))

    private fun barCenterX(layout: Layout, index: Int): Int {
        val gap = layout.widthPx * 0.055f
        val barWidth = (layout.widthPx - gap * (BAR_COUNT - 1)) / BAR_COUNT
        return (index * (barWidth + gap) + barWidth / 2f)
            .roundToInt()
            .coerceIn(0, layout.widthPx - 1)
    }

    /** [y] satirindaki birbirine bitisik murekkep araliklari. */
    private fun inkRuns(bitmap: Bitmap, y: Int): List<IntRange> {
        val runs = mutableListOf<IntRange>()
        var start = -1
        for (x in 0 until bitmap.width) {
            val inked = Color.alpha(bitmap.getPixel(x, y)) > 0
            if (inked && start < 0) {
                start = x
            } else if (!inked && start >= 0) {
                runs += start until x
                start = -1
            }
        }
        if (start >= 0) runs += start until bitmap.width
        return runs
    }
}
