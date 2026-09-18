package com.focussayac.focussayac.widget

import android.graphics.Bitmap
import android.graphics.Color
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * `RingRenderer`in zaman yayi - ROADMAP madde 33.
 *
 * Widget halkasi `CountdownRingPainter`in portu ve ayni kusuru tasiyordu:
 * Cap.ROUND'un geride biraktigi seritte SweepGradient turu tamamlayip son
 * durakta (koz) orneklenıyordu. Dart tarafindaki karsiligi
 * `test/features/countdown/countdown_ring_start_test.dart`; iki kosum ayni
 * iddiayi tutuyor, yoksa widget ile Ekran 02 ayni halkayi farkli boyar.
 *
 * `FlameRenderer` gibi sharedTest sozlesmesi YOK ve cihaz kosumu yok: iddia
 * cizim yolunun varligi degil, golgelendiricinin renk matematigi - o da
 * Robolectric'in NATIVE Skia'sinda cihazdakiyle ayni cikiyor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class RingRendererRobolectricTest {

    private companion object {
        /** VIEW_BOX ile birebir: olcek 1, sayilar dogrudan prototipin sayilari. */
        const val SIZE = 316
        const val CENTER = SIZE / 2f
        const val TRACK_RADIUS = 130f
        const val TRACK_STROKE = 9f

        /** Yayin baslangici: 12 yonu. */
        const val START_DEG = -90.0
    }

    private val bitmap: Bitmap by lazy {
        RingRenderer.render(
            context = ApplicationProvider.getApplicationContext(),
            sizePx = SIZE,
            progressRatio = 0.25f,
            accentColor = 0xFFFFB03A.toInt(),
            centerText = "128",
            labelText = "GUN",
            muted = false,
            // Gunluk yay kapali: iddia yalnizca zaman yayina baksin.
            todayRatio = 0f,
            habitColor = 0xFF4FE0B4.toInt(),
        )
    }

    @Test
    fun `yayin baslangicinda koz lekesi yok`() {
        // Baslangicin gerisi: 20 derece geriden 2 derece ileriye, izin iki
        // kenari arasinda. Kozun kirmizisi (255,176,58) mavisinden 197 fazla,
        // gokyuzu (99,180,255) eksi tarafta; getPixel on-carpilmamis donduruyor,
        // yani yumusatilmis kenar pikselleri de gercek renklerini veriyor.
        var worst = 0
        var worstDeg = 0.0
        var worstPixel = 0
        var degrees = -20.0
        while (degrees <= 2.0) {
            var radius = TRACK_RADIUS - TRACK_STROKE
            while (radius <= TRACK_RADIUS + TRACK_STROKE) {
                val pixel = pixelAt(degrees, radius)
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

    @Test
    fun `iki uc da yuvarlak kaliyor`() {
        // Hem kabul olcutu (bitis ucu yuvarlak kalacak) hem de yukaridaki
        // iddianin bos yere yesil olmadiginin kaniti: yay gercekten cizilmis.
        val capProbeDeg = Math.toDegrees((2.5f / TRACK_RADIUS).toDouble())
        assertTrue(
            "baslangic ucu duzlesmis",
            Color.alpha(pixelAt(-capProbeDeg, TRACK_RADIUS)) > 200,
        )
        assertTrue(
            "bitis ucu duzlesmis",
            Color.alpha(pixelAt(90.0 + capProbeDeg, TRACK_RADIUS)) > 200,
        )
    }

    /** Halkanin merkezinden, 12 yonunden [degrees] sapmis, [radius] uzaktaki piksel. */
    private fun pixelAt(degrees: Double, radius: Float): Int {
        val radians = Math.toRadians(START_DEG + degrees)
        val x = (CENTER + radius * cos(radians)).roundToInt().coerceIn(0, SIZE - 1)
        val y = (CENTER + radius * sin(radians)).roundToInt().coerceIn(0, SIZE - 1)
        return bitmap.getPixel(x, y)
    }
}
