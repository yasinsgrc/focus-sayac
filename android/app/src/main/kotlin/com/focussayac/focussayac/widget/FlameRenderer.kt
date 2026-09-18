package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader

/**
 * Kademe alevini cizer - lib/core/widgets/flame_widget.dart icindeki
 * _FlameShape mantiginin widget olcegine indirilmis hali.
 *
 * Seans ekseni burada YOK: widget suren seansi gostermiyor, kimligi
 * gosteriyor. Alev her zaman kademenin dinlenme halinde.
 */
object FlameRenderer {

    // Dart tarafindaki _darkBody duraklari. Alevin gradyani dekoratif ve kendi
    // kutusunda duruyor; Dart'taki `_lightBody` duzeltmesi METIN kontrasti
    // icindi, burada karsiligi yok.
    private const val BODY_ROOT = 0xFF7A2F0C.toInt()
    private const val BODY_MID = 0xFFFFB03A.toInt()
    private const val BODY_TIP = 0xFFFFF3D8.toInt()
    private const val CORE = 0xFFFFFAF0.toInt()
    private const val SPARK = 0xFFFFD79A.toInt()
    private const val EMBER = 0xFFCC5A10.toInt()

    fun render(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        tier: FlameTier,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Dart'taki 64x98 kutunun oranlari korunuyor; kademe olcegi kutunun
        // icinde uygulaniyor (Transform.scale'in karsiligi).
        val bodyHeight = heightPx * tier.scale
        val bodyWidth = bodyHeight * (44f / 86f)
        val centerX = widthPx / 2f
        val bottom = heightPx.toFloat()
        val top = bottom - bodyHeight

        if (tier.haloOpacity > 0f) {
            val haloY = bottom - bodyHeight * 0.45f
            val haloR = bodyHeight * 0.75f
            paint.shader = RadialGradient(
                centerX,
                haloY,
                haloR,
                withAlpha(BODY_MID, (tier.haloOpacity * 255).toInt()),
                Color.TRANSPARENT,
                Shader.TileMode.CLAMP,
            )
            canvas.drawCircle(centerX, haloY, haloR, paint)
            paint.shader = null
        }

        if (tier.emberBase) {
            paint.color = withAlpha(EMBER, 0xB3)
            val emberWidth = bodyWidth * 0.92f
            val emberHeight = bodyHeight * 0.11f
            canvas.drawOval(
                RectF(centerX - emberWidth / 2f, bottom - emberHeight, centerX + emberWidth / 2f, bottom),
                paint,
            )
        }

        paint.shader = LinearGradient(
            centerX, bottom, centerX, top,
            intArrayOf(BODY_ROOT, BODY_MID, BODY_TIP),
            floatArrayOf(0f, 0.56f, 1f),
            Shader.TileMode.CLAMP,
        )
        canvas.drawRoundRect(
            RectF(centerX - bodyWidth / 2f, top, centerX + bodyWidth / 2f, bottom),
            bodyWidth / 2f,
            bodyHeight * 0.42f,
            paint,
        )
        paint.shader = null

        // Ic cekirdek - govdenin icinde kaldigi icin her iki temada da ayni.
        paint.color = withAlpha(CORE, 0xF2)
        val coreWidth = bodyWidth * (18f / 44f)
        val coreHeight = bodyHeight * (46f / 86f)
        val coreBottom = bottom - bodyHeight * 0.14f
        canvas.drawRoundRect(
            RectF(centerX - coreWidth / 2f, coreBottom - coreHeight, centerX + coreWidth / 2f, coreBottom),
            coreWidth / 2f,
            coreHeight * 0.4f,
            paint,
        )

        // Kivilcimlar deterministik konumda - rastgelelik her yenilemede
        // widget'i zipatirdi.
        //
        // Tepeden YUKARI degil, tepeden ASAGI yigiliyorlar. Dart'ta sekil
        // kutusunun (64x98) tepesinde govdenin (44x86) ustunde 12px hava var,
        // kivilcimlar oraya tasabiliyor; burada `bodyHeight = heightPx * scale`
        // oldugu icin ust kademelerde o hava hic yok - K10'da govde kareyi
        // tamamen dolduruyor, `top` sifira iniyor ve merdivenin en tepesindeki
        // kivilcimlar SESSIZCE kirpiliyordu (K8'de 3'un 2'si, K9'da 4'un 1'i,
        // K10'da 5'in hicbiri cizilmiyordu). Govdenin iki yaninda asagi inen
        // dizilim her olcekte kare icinde kaliyor.
        paint.color = withAlpha(SPARK, 0xCC)
        val sparkRadius = bodyWidth * 0.08f
        for (i in 0 until tier.sparkCount) {
            val offsetX = if (i % 2 == 0) -bodyWidth * 0.6f else bodyWidth * 0.6f
            val y = top + sparkRadius + bodyHeight * 0.08f * i
            if (y > 0f) canvas.drawCircle(centerX + offsetX, y, sparkRadius, paint)
        }

        return bitmap
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}
