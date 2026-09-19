package com.focussayac.focussayac.widget

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith

/**
 * `StripRenderer`in emulator/cihaz kosumu - ROADMAP madde 39.
 *
 * Iddialar `StripRendererContract`ta, Robolectric kosumuyla ayni dosyada.
 */
@RunWith(AndroidJUnit4::class)
class StripRendererDeviceTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun izCubugunIkiUcuArasindaKesintisiz() {
        StripRendererContract.verifyTrack(StripRendererContract.render(context, 0.05f))
    }

    @Test
    fun dolgununUcuOranaBagli() {
        StripRendererContract.verifyFillLadder(StripRendererContract.renderLadder(context))
    }

    @Test
    fun cokKucukOrandaDolguKaybolmuyor() {
        StripRendererContract.verifyMinimumFill(context)
    }

    @Test
    fun dolguSinavRengindenKozaGidiyor() {
        StripRendererContract.verifyGradientDirection(StripRendererContract.render(context, 1f))
    }
}
