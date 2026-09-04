package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader

/**
 * Serit widget'inin yatay doluluk cubugu. Halkanin dairesel ilerlemesiyle
 * ayni orani (progressRatio) tasir, yalnizca duz cizgiye acilmis halidir.
 *
 * Dolgu, sinavin accent renginden ember rengine giden bir gradyan: sinav
 * yaklastikca cubugun ucu isiniyor.
 */
object StripRenderer {

    fun render(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        ratio: Float,
        accentColor: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val palette = FocusPalette(context)
        val radius = heightPx / 2f

        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(palette.text, 0x12)
        }
        canvas.drawRoundRect(
            RectF(0f, 0f, widthPx.toFloat(), heightPx.toFloat()),
            radius,
            radius,
            track,
        )

        // Dolgu genisligi en az bir yuvarlak uc kadar: cok kucuk oranlarda
        // cubuk tamamen kayboluyordu.
        val fillWidth = (widthPx * ratio.coerceIn(0f, 1f)).coerceAtLeast(heightPx.toFloat())
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                0f,
                0f,
                fillWidth,
                0f,
                accentColor,
                palette.ember,
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRoundRect(RectF(0f, 0f, fillWidth, heightPx.toFloat()), radius, radius, fill)
        return bitmap
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}
