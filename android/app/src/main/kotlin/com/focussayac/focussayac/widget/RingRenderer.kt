package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.SweepGradient

/**
 * Ekran 02 icindeki CountdownRingPainter
 * (lib/features/countdown/widgets/countdown_ring_painter.dart) sinifinin
 * Kotlin portu. Prototipin viewBox="0 0 316 316" geometrisi birebir korunur:
 * dis hairline r=142, track r=130, kesikli ic cember r=112, stroke 9.
 *
 * Ilerleme yayinin gradyani uygulamayla AYNI (sky -> accent -> ember).
 * Sinavin accentRole rengi halkanin degil, kesikli ic cemberin ve ortadaki
 * etiketin rengidir: widget bir bakista Ekran 02 ile ayni sey olarak
 * taniniyor, sinav rolu de kaybolmuyor.
 */
object RingRenderer {

    private const val VIEW_BOX = 316f
    private const val OUTER_RADIUS = 142f
    private const val TRACK_RADIUS = 130f
    private const val DASHED_RADIUS = 112f
    private const val TRACK_STROKE = 9f

    private const val OUTER_COLOR = 0x17FFFFFF
    private const val TRACK_COLOR = 0x12FFFFFF

    fun render(
        context: Context,
        sizePx: Int,
        progressRatio: Float,
        accentColor: Int,
        centerText: String,
        labelText: String,
        muted: Boolean,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val scale = sizePx / VIEW_BOX
        val cx = sizePx / 2f
        val cy = sizePx / 2f

        val outer = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = OUTER_COLOR
            style = Paint.Style.STROKE
            strokeWidth = 1f * scale
        }
        canvas.drawCircle(cx, cy, OUTER_RADIUS * scale, outer)

        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = TRACK_COLOR
            style = Paint.Style.STROKE
            strokeWidth = TRACK_STROKE * scale
        }
        canvas.drawCircle(cx, cy, TRACK_RADIUS * scale, track)

        if (!muted) {
            drawProgressArc(canvas, cx, cy, TRACK_RADIUS * scale, TRACK_STROKE * scale, progressRatio)
        }

        drawDashedCircle(
            canvas = canvas,
            cx = cx,
            cy = cy,
            radius = DASHED_RADIUS * scale,
            dashLength = 2f * scale,
            gapLength = 12f * scale,
            strokeWidth = 1f * scale,
            color = withAlpha(accentColor, 0x59),
        )

        drawCenterText(context, canvas, cx, cy, sizePx, centerText, labelText, accentColor, muted)
        return bitmap
    }

    private fun drawProgressArc(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        stroke: Float,
        ratio: Float,
    ) {
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        // Prototipin uc duraklikli sweep gradyani; -90 derece dondurulerek
        // yayin baslangicina hizalaniyor (Dart tarafinda GradientRotation).
        val gradient = SweepGradient(
            cx,
            cy,
            intArrayOf(0xFF63B4FF.toInt(), 0xFFB5ABFC.toInt(), 0xFFFFB03A.toInt()),
            floatArrayOf(0f, 0.48f, 1f),
        ).apply {
            setLocalMatrix(Matrix().apply { setRotate(-90f, cx, cy) })
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
            shader = gradient
        }
        canvas.drawArc(rect, -90f, 360f * ratio.coerceIn(0f, 1f), false, paint)
    }

    private fun drawDashedCircle(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        dashLength: Float,
        gapLength: Float,
        strokeWidth: Float,
        color: Int,
    ) {
        val circumference = 2.0 * Math.PI * radius
        val dashCount = (circumference / (dashLength + gapLength)).toInt()
        if (dashCount <= 0) return

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth
        }
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        val anglePerDash = 360f / dashCount
        val dashAngle = anglePerDash * (dashLength / (dashLength + gapLength))
        for (index in 0 until dashCount) {
            canvas.drawArc(rect, index * anglePerDash, dashAngle, false, paint)
        }
    }

    private fun drawCenterText(
        context: Context,
        canvas: Canvas,
        cx: Float,
        cy: Float,
        sizePx: Int,
        centerText: String,
        labelText: String,
        accentColor: Int,
        muted: Boolean,
    ) {
        val palette = FocusPalette(context)

        val counter = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetTypography.counter(context)
            color = if (muted) palette.neutral400 else palette.text
            textAlign = Paint.Align.CENTER
            letterSpacing = WidgetTypography.COUNTER_LETTER_SPACING
            textSize = counterSizeFor(centerText, sizePx)
        }
        // Rakam optik olarak ortalaniyor: salt metrik merkezleme buyuk
        // rakamlarda gorsel olarak yukari kaciyordu.
        val counterOffset = (counter.descent() + counter.ascent()) / 2f
        canvas.drawText(centerText, cx, cy - counterOffset - sizePx * 0.045f, counter)

        if (labelText.isEmpty()) return
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = WidgetTypography.kicker(context)
            color = if (muted) palette.neutral500 else accentColor
            textAlign = Paint.Align.CENTER
            letterSpacing = WidgetTypography.KICKER_LETTER_SPACING
            textSize = sizePx * 0.058f
        }
        canvas.drawText(labelText, cx, cy + sizePx * 0.20f, label)
    }

    /**
     * Uc haneli sayilar iki haneli olanlarla ayni punto ile halkaya
     * sigmiyordu; punto karakter sayisina gore kuculuyor.
     */
    private fun counterSizeFor(text: String, sizePx: Int): Float = when (text.length) {
        1, 2 -> sizePx * 0.34f
        3 -> sizePx * 0.28f
        else -> sizePx * 0.21f
    }

    private fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}
