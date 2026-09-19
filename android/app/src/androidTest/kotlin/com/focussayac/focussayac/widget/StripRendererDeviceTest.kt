package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
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
    fun sinavSecilmemiskenDolguYok() {
        StripRendererContract.verifyMutedHasNoFill(
            StripRendererContract.render(context, 0.75f, muted = true),
        )
    }

    @Test
    fun dolguSinavRengindenKozaGidiyor() {
        StripRendererContract.verifyGradientDirection(StripRendererContract.render(context, 1f))
    }

    /**
     * Kanit dokumu - ROADMAP madde 43, kalip madde 31'den. Iki durum uretim
     * olcusunde (630x15) PNG olarak cihaza yaziliyor, `adb pull` ile
     * `.verify/m43_*.png` olarak aliniyor.
     *
     * Yanina halkanin `m41_e_sinav_yok` dokumu konunca maddenin kapattigi
     * ayrisma okunuyor: iki widget'in bos hali artik ayni sey.
     */
    @Test
    fun bosDurumPngleriniDok() {
        val dir = File(context.getExternalFilesDir(null), "m43").apply { mkdirs() }
        val frames = mapOf(
            "a_serit_bos" to StripRendererContract.render(context, 0.75f, muted = true),
            "b_serit_dolu" to StripRendererContract.render(context, 0.25f),
        )
        frames.forEach { (name, bitmap) ->
            File(dir, "m43_$name.png").outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
        }
    }
}
