package com.focussayac.focussayac.widget

import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * `FlameRenderer`in cihazsiz kapisi - ROADMAP madde 31.
 *
 * NATIVE grafik kipi gercek Bitmap/Canvas/Shader kosturuyor, yani pikseller
 * gercekten ciziliyor ve `getPixel` gercek deger donduruyor. LEGACY kipte
 * cizim yok sayilirdi ve test hicbir sey dogrulamazdi.
 *
 * Iddialarin tamami `FlameRendererContract`ta; ayni dosyayi cihaz testi de
 * derliyor. `@GraphicsMode` Robolectric'e ozel oldugu icin sozlesmede degil
 * burada - boylece androidTest classpath'ine Robolectric girmiyor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class FlameRendererRobolectricTest {

    private val bitmaps by lazy {
        FlameRendererContract.renderAll(ApplicationProvider.getApplicationContext())
    }

    @Test
    fun `on kademenin cizim yolu kosuyor ve merdivenle uyusuyor`() {
        FlameRendererContract.verifyAllTiers(bitmaps)
    }

    @Test
    fun `alev kademe kademe buyuyor`() {
        FlameRendererContract.verifyLadder(bitmaps)
    }
}
