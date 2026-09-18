package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import java.io.File
import org.junit.Test
import org.junit.runner.RunWith

/**
 * `FlameRenderer`in emulator/cihaz kosumu - ROADMAP madde 31.
 *
 * Madde 23'ten kalan bosluk widget'i ana ekrana koyarak kapanamiyordu
 * (`appwidget` kabuk komutu yalnizca `grantbind` destekliyor, `cmd appwidget`
 * yok). Bu test cizim yolunu gercek grafik yiginda dogrudan cagiriyor.
 *
 * Iddialar `FlameRendererContract`ta, Robolectric kosumuyla ayni dosyada.
 */
@RunWith(AndroidJUnit4::class)
class FlameRendererDeviceTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun onKademeninCizimYoluKosuyorVeMerdivenleUyusuyor() {
        FlameRendererContract.verifyAllTiers(FlameRendererContract.renderAll(context))
    }

    @Test
    fun alevKademeKademeBuyuyor() {
        FlameRendererContract.verifyLadder(FlameRendererContract.renderAll(context))
    }

    /**
     * Kanit dokumu: on bitmap PNG olarak cihaza yaziliyor, `adb pull` ile
     * `.verify/m31_k*.png` olarak aliniyor. Ekran goruntusu degil,
     * `FlameRenderer` cikitisinin kendisi.
     */
    @Test
    fun kademePngleriniDok() {
        val dir = File(context.getExternalFilesDir(null), "m31").apply { mkdirs() }
        FlameRendererContract.renderAll(context).forEach { (index, bitmap) ->
            File(dir, "m31_k$index.png").outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
        }
    }
}
