package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import com.focussayac.focussayac.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * `RingRenderer` cizim yolunun sozlesmesi. ROADMAP madde 39; tasarim:
 * docs/superpowers/specs/2026-09-19-kotlin-renderer-dogrulama-design.md
 *
 * Kalip madde 31'den: iddialar burada tek yerde, iki kosum evi de (src/test
 * Robolectric NATIVE, src/androidTest cihaz) bu dosyayi derliyor.
 *
 * Madde 33'un koz lekesi iddiasi da buraya tasindi - orada yalnizca
 * Robolectric kosuyordu, artik cihaz da ayni sondaya bakiyor.
 *
 * Iddialar altin goruntu DEGIL. Iki ekseni var: **alfa** (iz 0x12, kesikli
 * cember 0x59, cizilen yaylar 0xFF - 0x80 esigi ikisini ayiriyor) ve
 * **sicaklik** (kirmizi eksi mavi), ikisi de tema niteleyicisinden bagimsiz:
 * halkanin gradyani `RingRenderer`da duz hex, palet degil.
 */
object RingRendererContract {

    /** Uretimdeki olcu: RingWidgetProvider 104dp istiyor (~2.6x yogunluk). */
    const val SIZE_PX = 273

    /** Yayin baslangici: 12 yonu. Butun aci sondalari buradan saat yonunde. */
    private const val START_DEG = -90.0

    // RingRenderer'in VIEW_BOX geometrisi uretim olcegine tasinmis hali;
    // sondalar halkanin neresine bakacagini buradan biliyor.
    private const val SCALE = SIZE_PX / 316f
    private const val CENTER = SIZE_PX / 2f
    private const val TRACK_RADIUS = 130f * SCALE
    private const val DASHED_RADIUS = 112f * SCALE
    private const val TRACK_STROKE = 9f * SCALE
    private const val HABIT_STROKE = 5f * SCALE

    /** Ortadaki yazinin carpmamasi gereken sinir: izin IC kenari. */
    private const val INNER_EDGE = TRACK_RADIUS - TRACK_STROKE / 2f

    /** Cizilen yay ile izi/kesikli cemberi ayiran esik. */
    private const val DRAWN = 0x80

    /**
     * Sinav rengi bilerek SOGUK: gunluk yayin yesili ve merkez yazisi ancak
     * koza karsi olculebiliyor. Uretimde bu renk kullanicidan geliyor,
     * sozlesme rengin kendisini degil yerlesimini siniyor.
     */
    private val ACCENT = 0xFF63B4FF.toInt()
    private val HABIT = 0xFF4FE0B4.toInt()

    /** Merdiven: oran yuzde olarak, bitmap'e. */
    val RATIO_PERCENTS = listOf(10, 25, 50, 75, 90, 100)

    fun render(
        context: Context,
        ratio: Float,
        muted: Boolean = false,
        todayRatio: Float = 0f,
        centerText: String = "128",
        labelText: String = "GUN",
    ): Bitmap = RingRenderer.render(
        context = context,
        sizePx = SIZE_PX,
        progressRatio = ratio,
        accentColor = ACCENT,
        centerText = centerText,
        labelText = labelText,
        muted = muted,
        todayRatio = todayRatio,
        habitColor = HABIT,
    )

    fun renderLadder(context: Context): Map<Int, Bitmap> =
        RATIO_PERCENTS.associateWith { render(context, it / 100f) }

    /**
     * 1. Cizim gercekten oldu ve iz halkasi kesintisiz: yayin nerede bittigi
     * ancak izin her yerde durdugu bilinirse bir sey ifade ediyor.
     */
    fun verifyTrack(bitmap: Bitmap) {
        assertEquals("genislik", SIZE_PX, bitmap.width)
        assertEquals("yukseklik", SIZE_PX, bitmap.height)

        var degrees = 0.0
        while (degrees < 360.0) {
            val alpha = Color.alpha(pixelAt(bitmap, degrees, TRACK_RADIUS))
            assertTrue("iz halkasi $degrees derecede kopuk (alfa $alpha)", alpha > 8)
            degrees += 5.0
        }
    }

    /**
     * 2. Ilerleme yayinin uzunlugu orana bagli. Konumdan degil **kaplamadan**
     * okunuyor: cizilen aci orani orana esit. Yuvarlak uclar iki yanda
     * strokeWidth/2 kadar tasiyor, beklenen deger o payi tasiyor.
     */
    fun verifyProgressLadder(bitmaps: Map<Int, Bitmap>) {
        assertEquals("merdiven basamagi", RATIO_PERCENTS.size, bitmaps.size)
        val capSpan = 2.0 * Math.toDegrees((TRACK_STROKE / 2f / TRACK_RADIUS).toDouble()) / 360.0

        val failures = mutableListOf<String>()
        RATIO_PERCENTS.forEach { percent ->
            val expected = (percent / 100.0 + capSpan).coerceAtMost(1.0)
            val measured = drawnFraction(bitmaps.getValue(percent), TRACK_RADIUS)
            if (abs(measured - expected) > 0.02) {
                failures += "%$percent yay: beklenen ~${fmt(expected)}, olculen ${fmt(measured)}"
            }
        }
        if (failures.isNotEmpty()) {
            throw AssertionError(failures.joinToString(separator = "\n", prefix = "\n"))
        }

        // Merdiven monoton: iki basamak ayni yayi cizmiyorsa oran gercekten
        // geciyor demektir.
        val fractions = RATIO_PERCENTS.map { drawnFraction(bitmaps.getValue(it), TRACK_RADIUS) }
        fractions.zipWithNext().forEachIndexed { i, (shorter, longer) ->
            assertTrue(
                "%${RATIO_PERCENTS[i]} -> %${RATIO_PERCENTS[i + 1]} yay uzamiyor " +
                    "(${fmt(shorter)} -> ${fmt(longer)})",
                longer > shorter,
            )
        }
    }

    /**
     * 3. Gradyan Ekran 02'nin dilini konusuyor: yay gokyuzunde basliyor, kozda
     * bitiyor. Ters cevrilse ya da tek renge dusse widget ile Ekran 02 ayni
     * halkayi farkli boyardi.
     */
    fun verifyGradientDirection(bitmap: Bitmap) {
        val start = warmthAt(bitmap, 5.0, TRACK_RADIUS)
        val end = warmthAt(bitmap, 320.0, TRACK_RADIUS)
        assertTrue("yayin basi soguk degil (sicaklik $start)", start < -40)
        assertTrue("yayin sonu sicak degil (sicaklik $end)", end > 40)
    }

    /**
     * 4. Yayin baslangicinda koz lekesi yok - madde 33'un kusuru.
     *
     * Cap.ROUND baslangic ucunu strokeWidth/2 kadar geriye tasiyor; SweepGradient
     * orada turu tamamlayip son durakta (koz) orneklendigi icin mavi yayin tam
     * basinda turuncu bir leke kaliyordu. Sonda baslangicin 20 derece gerisinden
     * 2 derece ilerisine, izin iki kenari arasinda tariyor.
     */
    fun verifyNoEmberAtStart(bitmap: Bitmap) {
        var worst = -255
        var worstDeg = 0.0
        var worstPixel = 0
        var degrees = -20.0
        while (degrees <= 2.0) {
            var radius = TRACK_RADIUS - TRACK_STROKE
            while (radius <= TRACK_RADIUS + TRACK_STROKE) {
                val pixel = pixelAt(bitmap, degrees, radius)
                val warmth = Color.red(pixel) - Color.blue(pixel)
                if (warmth > worst) {
                    worst = warmth
                    worstDeg = degrees
                    worstPixel = pixel
                }
                radius += 0.5f
            }
            degrees += 0.25
        }

        // 12'lik pay yuvarlamaya birakildi; leke oradayken bu sayi 190'in ustunde.
        assertTrue(
            "$worstDeg derecede sicak piksel: #${Integer.toHexString(worstPixel)}",
            worst < 12,
        )
    }

    /**
     * 5. Iki uc da yuvarlak. Hem kabul olcutu hem de 4. iddianin bos yere
     * yesil olmadiginin kaniti: yay gercekten cizilmis.
     */
    fun verifyRoundCaps(bitmap: Bitmap) {
        val capProbeDeg = Math.toDegrees((2.5f * SCALE / TRACK_RADIUS).toDouble())
        assertTrue(
            "baslangic ucu duzlesmis",
            Color.alpha(pixelAt(bitmap, -capProbeDeg, TRACK_RADIUS)) > 200,
        )
        assertTrue(
            "bitis ucu duzlesmis",
            Color.alpha(pixelAt(bitmap, 90.0 + capProbeDeg, TRACK_RADIUS)) > 200,
        )
    }

    /**
     * 6. Sinav secilmemisken yay hic cizilmiyor - `muted` izi birakiyor, yayi
     * almiyor. Widget'in "sesini kismasi" bu.
     */
    fun verifyMutedHasNoArc(bitmap: Bitmap) {
        verifyTrack(bitmap)
        val drawn = drawnFraction(bitmap, TRACK_RADIUS)
        assertEquals("sinav yokken yay cizilmis", 0.0, drawn, 0.0)
    }

    /**
     * 7. Gunun dongusu ayri bir yay: kesikli cemberin uzerinde, orani kadar ve
     * kendi renginde. Geri sayim yayinin gradyanini tasisaydi hangisinin sinav
     * hangisinin gun oldugu okunmazdi.
     */
    fun verifyHabitArc(withHabit: Bitmap, withoutHabit: Bitmap) {
        val capSpan = 2.0 * Math.toDegrees((HABIT_STROKE / 2f / DASHED_RADIUS).toDouble()) / 360.0
        val drawn = drawnFraction(withHabit, DASHED_RADIUS)
        assertTrue(
            "gunluk yay orani tutmuyor: beklenen ~${fmt(0.5 + capSpan)}, olculen ${fmt(drawn)}",
            abs(drawn - (0.5 + capSpan)) <= 0.02,
        )

        val pixel = pixelAt(withHabit, 90.0, DASHED_RADIUS)
        assertTrue(
            "gunluk yay yesil degil: #${Integer.toHexString(pixel)}",
            Color.green(pixel) > Color.red(pixel) && Color.green(pixel) > Color.blue(pixel),
        )

        val idle = drawnFraction(withoutHabit, DASHED_RADIUS)
        assertEquals("pomodoro yokken gunluk yay cizilmis", 0.0, idle, 0.0)
    }

    /**
     * 8. Ortadaki yazi her uzunlukta izin icinde kaliyor. `counterSizeFor`
     * puntoyu karakter sayisina gore kuculttugunu soyluyor; sinanan sey o soz.
     * Kicker'lar uygulamanin kendi dizgeleri - ceviri uzadiginda bu iddia duser.
     *
     * `muted` bilerek: yay yokken 0x80 ustundeki tek cizim yazinin kendisi
     * (iz 0x12, dis tel 0x17, kesikli cember 0x59).
     */
    fun verifyCenterTextFits(context: Context) {
        val labels = listOf(
            R.string.widget_days_left,
            R.string.widget_today,
            R.string.widget_no_exam_title,
            R.string.widget_expired_title,
        ).map(context::getString)
        val counters = listOf("–", "8", "88", "128", "1280")

        val failures = mutableListOf<String>()
        counters.forEach { counter ->
            labels.forEach { label ->
                val bitmap = render(
                    context = context,
                    ratio = 0f,
                    muted = true,
                    centerText = counter,
                    labelText = label,
                )
                val reach = inkReach(bitmap)
                if (reach >= INNER_EDGE) {
                    failures += "\"$counter\" / \"$label\" ize giriyor: murekkep " +
                        "${fmt(reach.toDouble())} px, iz kenari ${fmt(INNER_EDGE.toDouble())} px"
                }
            }
        }
        if (failures.isNotEmpty()) {
            throw AssertionError(failures.joinToString(separator = "\n", prefix = "\n"))
        }
    }

    /**
     * [radius] cemberinde cizilmis (0x80 ustu) acilarin orani. Yarim derecelik
     * adimla tariyor: %1'lik bir yay bile birkac ornekte gorunuyor.
     */
    private fun drawnFraction(bitmap: Bitmap, radius: Float): Double {
        val steps = 720
        var hits = 0
        for (step in 0 until steps) {
            val degrees = step * 360.0 / steps
            if (Color.alpha(pixelAt(bitmap, degrees, radius)) >= DRAWN) hits++
        }
        return hits.toDouble() / steps
    }

    /** Merkezden en uzak "murekkep" pikselinin uzakligi. */
    private fun inkReach(bitmap: Bitmap): Float {
        var reach = 0f
        for (y in 0 until bitmap.height) {
            for (x in 0 until bitmap.width) {
                if (Color.alpha(bitmap.getPixel(x, y)) < DRAWN) continue
                val distance = hypot(x + 0.5f - CENTER, y + 0.5f - CENTER)
                if (distance > reach) reach = distance
            }
        }
        return reach
    }

    private fun warmthAt(bitmap: Bitmap, degrees: Double, radius: Float): Int {
        val pixel = pixelAt(bitmap, degrees, radius)
        return Color.red(pixel) - Color.blue(pixel)
    }

    /** Halkanin merkezinden, 12 yonunden [degrees] sapmis, [radius] uzaktaki piksel. */
    private fun pixelAt(bitmap: Bitmap, degrees: Double, radius: Float): Int {
        val radians = Math.toRadians(START_DEG + degrees)
        val x = (CENTER + radius * cos(radians)).roundToInt().coerceIn(0, bitmap.width - 1)
        val y = (CENTER + radius * sin(radians)).roundToInt().coerceIn(0, bitmap.height - 1)
        return bitmap.getPixel(x, y)
    }

    private fun fmt(value: Double): String = ((value * 1000).roundToInt() / 1000.0).toString()
}
