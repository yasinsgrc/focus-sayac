package com.focussayac.focussayac.widget

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith

/**
 * `RingRenderer`in emulator/cihaz kosumu - ROADMAP madde 39.
 *
 * Madde 33'un koz lekesi iddiasi yalnizca Robolectric'te kosuyordu; halkanin
 * gradyani gercek grafik yiginda da ayni yerde orneklenmeli, o yuzden artik
 * cihaz da ayni sondaya bakiyor.
 *
 * Iddialar `RingRendererContract`ta, Robolectric kosumuyla ayni dosyada.
 */
@RunWith(AndroidJUnit4::class)
class RingRendererDeviceTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun izHalkasiKesintisiz() {
        RingRendererContract.verifyTrack(RingRendererContract.render(context, 0.25f))
    }

    @Test
    fun ilerlemeYayiOranaBagli() {
        RingRendererContract.verifyProgressLadder(RingRendererContract.renderLadder(context))
    }

    @Test
    fun gradyanGokyuzundenKozaGidiyor() {
        RingRendererContract.verifyGradientDirection(RingRendererContract.render(context, 0.9f))
    }

    @Test
    fun yayinBaslangicindaKozLekesiYok() {
        RingRendererContract.verifyNoEmberAtStart(RingRendererContract.render(context, 0.25f))
    }

    @Test
    fun ikiUcDaYuvarlakKaliyor() {
        RingRendererContract.verifyRoundCaps(RingRendererContract.render(context, 0.25f))
    }

    @Test
    fun sinavSecilmemiskenYayYok() {
        RingRendererContract.verifyMutedHasNoArc(
            RingRendererContract.render(context, 0.75f, muted = true),
        )
    }

    @Test
    fun gununDongusuAyriBirYay() {
        RingRendererContract.verifyHabitArc(
            withHabit = RingRendererContract.render(context, 0.25f, todayRatio = 0.5f),
            withoutHabit = RingRendererContract.render(context, 0.25f),
        )
    }

    @Test
    fun ortadakiYaziIzeGirmiyor() {
        RingRendererContract.verifyCenterTextFits(context)
    }
}
