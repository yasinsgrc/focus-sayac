package com.focussayac.focussayac.widget

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * `RingRenderer`in cihazsiz kapisi - ROADMAP madde 33 (koz lekesi) ve
 * madde 39 (sozlesme + cihaz kosumu).
 *
 * Madde 33'te bu dosya tek iddiayi kendi icinde tutuyordu ve cihazda hic
 * kosmuyordu; madde 39 iddialari `RingRendererContract`a tasidi, boylece ayni
 * govdeyi `RingRendererDeviceTest` de derliyor. `@GraphicsMode` Robolectric'e
 * ozel oldugu icin sozlesmede degil burada.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class RingRendererRobolectricTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `iz halkasi kesintisiz`() {
        RingRendererContract.verifyTrack(RingRendererContract.render(context, 0.25f))
    }

    @Test
    fun `ilerleme yayi orana bagli`() {
        RingRendererContract.verifyProgressLadder(RingRendererContract.renderLadder(context))
    }

    @Test
    fun `gradyan gokyuzunden koza gidiyor`() {
        RingRendererContract.verifyGradientDirection(RingRendererContract.render(context, 0.9f))
    }

    @Test
    fun `yayin baslangicinda koz lekesi yok`() {
        RingRendererContract.verifyNoEmberAtStart(RingRendererContract.render(context, 0.25f))
    }

    @Test
    fun `iki uc da yuvarlak kaliyor`() {
        RingRendererContract.verifyRoundCaps(RingRendererContract.render(context, 0.25f))
    }

    @Test
    fun `sinav secilmemisken yay yok`() {
        RingRendererContract.verifyMutedHasNoArc(
            RingRendererContract.render(context, 0.75f, muted = true),
        )
    }

    @Test
    fun `gunun dongusu ayri bir yay`() {
        RingRendererContract.verifyHabitArc(
            withHabit = RingRendererContract.render(context, 0.25f, todayRatio = 0.5f),
            withoutHabit = RingRendererContract.render(context, 0.25f),
        )
    }

    @Test
    fun `emek yayi orana bagli`() {
        RingRendererContract.verifyEffortLadder(
            RingRendererContract.renderEffortLadder(context),
        )
    }

    @Test
    fun `hedef kapaliyken emek yayi da izi de yok`() {
        RingRendererContract.verifyEffortOffDrawsNothing(
            goalOff = RingRendererContract.render(context, 0.25f),
            goalOnEmpty = RingRendererContract.render(context, 0.25f, effortRatio = 0f),
        )
    }

    @Test
    fun `emek yayi kendi rengini tasiyor`() {
        RingRendererContract.verifyEffortColor(
            ember = RingRendererContract.render(context, 0.25f, effortRatio = 0.5f),
            mint = RingRendererContract.renderMintEffort(context),
        )
    }

    @Test
    fun `zaman yayi emek yayindan etkilenmiyor`() {
        RingRendererContract.verifyTimeArcUnaffected(
            RingRendererContract.renderEffortStates(context),
        )
    }

    @Test
    fun `ortadaki yazi ize girmiyor`() {
        RingRendererContract.verifyCenterTextFits(context)
    }
}
