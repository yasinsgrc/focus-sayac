package com.focussayac.focussayac.widget

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * `SparkRenderer`in cihazsiz kapisi - ROADMAP madde 39.
 *
 * Iddialarin tamami `SparkRendererContract`ta; ayni dosyayi cihaz testi de
 * derliyor. Iki uretim yerlesimi (seri widget'i, panorama) ayri ayri
 * kosuluyor: sutun genisligi karenin oranindan geldigi icin ayni kod iki
 * yerlesimde farkli geometri uretiyor.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SparkRendererRobolectricTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    @Test
    fun `yedi sutun iki yerlesimde de yerinde`() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            SparkRendererContract.verifyLayout(
                SparkRendererContract.render(context, layout, SparkRendererContract.VALUES),
                layout,
            )
        }
    }

    @Test
    fun `sutun yukseklikleri gunun odagini gosteriyor`() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            SparkRendererContract.verifyHeights(
                SparkRendererContract.render(context, layout, SparkRendererContract.VALUES),
                layout,
                SparkRendererContract.VALUES,
            )
        }
    }

    @Test
    fun `bos hafta taban birakiyor`() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            val bitmap =
                SparkRendererContract.render(context, layout, SparkRendererContract.EMPTY_WEEK)
            SparkRendererContract.verifyLayout(bitmap, layout)
            SparkRendererContract.verifyHeights(
                bitmap,
                layout,
                SparkRendererContract.EMPTY_WEEK,
            )
        }
    }

    @Test
    fun `bugun gecmis gunlerden ayriliyor`() {
        SparkRendererContract.LAYOUTS.forEach { layout ->
            SparkRendererContract.verifyTodayStandsOut(
                SparkRendererContract.render(context, layout, SparkRendererContract.VALUES),
                layout,
            )
        }
    }
}
