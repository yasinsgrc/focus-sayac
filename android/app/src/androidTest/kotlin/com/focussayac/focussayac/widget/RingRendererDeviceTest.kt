package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
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
    fun emekYayiOranaBagli() {
        RingRendererContract.verifyEffortLadder(
            RingRendererContract.renderEffortLadder(context),
        )
    }

    @Test
    fun hedefKapaliykenEmekYayiDaIziDeYok() {
        RingRendererContract.verifyEffortOffDrawsNothing(
            goalOff = RingRendererContract.render(context, 0.25f),
            goalOnEmpty = RingRendererContract.render(context, 0.25f, effortRatio = 0f),
        )
    }

    @Test
    fun emekYayiKendiRenginiTasiyor() {
        RingRendererContract.verifyEffortColor(
            ember = RingRendererContract.render(context, 0.25f, effortRatio = 0.5f),
            mint = RingRendererContract.renderMintEffort(context),
        )
    }

    @Test
    fun zamanYayiEmekYayindanEtkilenmiyor() {
        RingRendererContract.verifyTimeArcUnaffected(
            RingRendererContract.renderEffortStates(context),
        )
    }

    @Test
    fun ortadakiYaziIzeGirmiyor() {
        RingRendererContract.verifyCenterTextFits(context)
    }

    @Test
    fun izlerIkiTemadaDaZemindenAyriliyor() {
        RingRendererContract.verifyTrackContrast(context)
    }

    /**
     * Kanit dokumu - ROADMAP madde 41, kalip madde 31'den. Dort durum uretim
     * olcusunde (273 px) PNG olarak cihaza yaziliyor, `adb pull` ile
     * `.verify/m41_*.png` olarak aliniyor. Ekran goruntusu degil,
     * `RingRenderer` ciktisinin kendisi: uc yayin birbirine girip girmedigi
     * ancak gercek grafik yiginda bakilarak gorulebilir.
     */
    @Test
    fun emekYayiPngleriniDok() {
        val dir = File(context.getExternalFilesDir(null), "m41").apply { mkdirs() }
        val frames = mapOf(
            "a_hedef_kapali" to RingRendererContract.render(context, 0.25f, todayRatio = 0.5f),
            "b_hedef_bos" to
                RingRendererContract.render(context, 0.25f, todayRatio = 0.5f, effortRatio = 0f),
            "c_hedef_yolda" to
                RingRendererContract.render(context, 0.25f, todayRatio = 0.5f, effortRatio = 0.42f),
            "d_hedef_doldu" to RingRendererContract.renderMintEffort(context),
            "e_sinav_yok" to
                RingRendererContract.render(
                    context,
                    0.75f,
                    muted = true,
                    effortRatio = 0.42f,
                    centerText = "–",
                ),
        )
        frames.forEach { (name, bitmap) ->
            File(dir, "m41_$name.png").outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
        }
    }

    /**
     * Kanit dokumu - ROADMAP madde 44. Ayni halka (hedef acik, hafta bos) iki
     * temada cizilip cihaza yaziliyor, `adb pull` ile `.verify/m44/`'e
     * aliniyor. Kontrast iddiasi sayiyi soyluyor; bu dosyalar o sayinin goze
     * ne yaptigini gosteriyor.
     */
    @Test
    fun izPngleriniDok() {
        val dir = File(context.getExternalFilesDir(null), "m44").apply { mkdirs() }
        RingRendererContract.renderThemes(context).forEach { (name, bitmap) ->
            File(dir, "m44_$name.png").outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
        }
    }
}
