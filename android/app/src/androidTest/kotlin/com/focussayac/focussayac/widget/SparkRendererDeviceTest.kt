package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import org.junit.Test
import org.junit.runner.RunWith

/**
 * `SparkRenderer`in emulator/cihaz kosumu - ROADMAP madde 39.
 *
 * Iddialar `SparkRendererContract`ta, Robolectric kosumuyla ayni dosyada.
 * Kanit dokumu de burada: uc renderer'in cizdigi bitmap'ler PNG olarak
 * cihaza yaziliyor, `adb pull` ile `.verify/m39_*.png` olarak aliniyor.
 * Ekran goruntusu degil, cizim yollarinin cikitisinin kendisi.
 */
@RunWith(AndroidJUnit4::class)
class SparkRendererDeviceTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun yediSutunIkiYerlesimdeDeYerinde() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            SparkRendererContract.verifyLayout(
                SparkRendererContract.render(context, layout, SparkRendererContract.VALUES),
                layout,
            )
        }
    }

    @Test
    fun sutunYukseklikleriGununOdaginiGosteriyor() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            SparkRendererContract.verifyHeights(
                SparkRendererContract.render(context, layout, SparkRendererContract.VALUES),
                layout,
                SparkRendererContract.VALUES,
            )
        }
    }

    @Test
    fun bosHaftaTabanBirakiyor() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            val bitmap =
                SparkRendererContract.render(context, layout, SparkRendererContract.EMPTY_WEEK)
            SparkRendererContract.verifyLayout(bitmap, layout)
            SparkRendererContract.verifyHeights(bitmap, layout, SparkRendererContract.EMPTY_WEEK)
        }
    }

    @Test
    fun bugunGecmisGunlerdenAyriliyor() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            SparkRendererContract.verifyTodayStandsOut(
                SparkRendererContract.render(context, layout, SparkRendererContract.VALUES),
                layout,
            )
        }
    }

    /** Uc renderer'in kanit dokumu - madde 39'un emulator izi. */
    @Test
    fun rendererPngleriniDok() {
        val dir = File(context.getExternalFilesDir(null), "m39").apply { mkdirs() }

        RingRendererContract.RATIO_PERCENTS.forEach { percent ->
            dump(dir, "m39_halka_%$percent", RingRendererContract.render(context, percent / 100f))
        }
        dump(dir, "m39_halka_sessiz", RingRendererContract.render(context, 0.75f, muted = true))
        dump(
            dir,
            "m39_halka_gunluk",
            RingRendererContract.render(context, 0.25f, todayRatio = 0.5f),
        )

        StripRendererContract.RATIO_PERCENTS.forEach { percent ->
            dump(dir, "m39_serit_%$percent", StripRendererContract.render(context, percent / 100f))
        }
        dump(dir, "m39_serit_%0", StripRendererContract.render(context, 0f))

        SparkRendererContract.LAYOUTS.forEach { layout ->
            dump(
                dir,
                "m39_sutun_${layout.name}",
                SparkRendererContract.render(context, layout, SparkRendererContract.VALUES),
            )
            dump(
                dir,
                "m39_sutun_${layout.name}_bos",
                SparkRendererContract.render(context, layout, SparkRendererContract.EMPTY_WEEK),
            )
        }
    }

    private fun dump(dir: File, name: String, bitmap: Bitmap) {
        File(dir, "$name.png").outputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
    }
}
