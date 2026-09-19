package com.focussayac.focussayac.widget

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * `StripRenderer`in cihazsiz kapisi - ROADMAP madde 39.
 *
 * NATIVE grafik kipi gercek Bitmap/Canvas/Shader kosturuyor; LEGACY kipte
 * cizim yok sayilir ve test hicbir sey dogrulamazdi.
 *
 * Iddialarin tamami `StripRendererContract`ta; ayni dosyayi cihaz testi de
 * derliyor. `@GraphicsMode` Robolectric'e ozel oldugu icin sozlesmede degil
 * burada.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class StripRendererRobolectricTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val ladder by lazy { StripRendererContract.renderLadder(context) }

    @Test
    fun `iz cubugun iki ucu arasinda kesintisiz`() {
        StripRendererContract.verifyTrack(StripRendererContract.render(context, 0.05f))
    }

    @Test
    fun `dolgunun ucu orana bagli`() {
        StripRendererContract.verifyFillLadder(ladder)
    }

    @Test
    fun `cok kucuk oranda dolgu kaybolmuyor`() {
        StripRendererContract.verifyMinimumFill(context)
    }

    @Test
    fun `dolgu sinav renginden koza gidiyor`() {
        StripRendererContract.verifyGradientDirection(ladder.getValue(100))
    }
}
