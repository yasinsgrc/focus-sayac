package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.SweepGradient
import kotlin.math.sqrt

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

    /** Gunluk pomodoro yayi geri sayim yayindan ince: ikincil bir bilgi. */
    private const val HABIT_STROKE = 5f

    /**
     * Emek ekseni - ROADMAP madde 41, olculeri Ekran 02'den birebir
     * (`CountdownRingPainter._effortRadius` / `_effortStrokeWidth`).
     *
     * Prototipin BOS bandina oturuyor: zaman izinin ic kenari 125.5, kesikli
     * cember 112. Yeniden olculmedi - madde 27 bu sayilari zaten kirmisti ve
     * iki yuzey ayni yay icin ayni yaricapi kullanmak zorunda.
     */
    private const val EFFORT_RADIUS = 119f
    private const val EFFORT_STROKE = 4f

    /**
     * Halkanin icine yazi koyan her seyin sigmasi gereken cember: en icteki
     * DOLU yayin ic kenari. Madde 41'den beri bu, zaman izi (125.5) degil emek
     * yayi. `CountdownRingPainter.innerContentRadius` ile ayni sayi.
     */
    private const val INNER_CONTENT_RADIUS = EFFORT_RADIUS - EFFORT_STROKE / 2f

    /**
     * Gradyani yayin GERISINE kaydiran aci - ROADMAP madde 33.
     *
     * Cap.ROUND baslangic ucunu strokeWidth/2 kadar geriye tasiyor; SweepGradient
     * orada turu tamamlayip son durakta (ember) orneklendigi icin mavi yayin tam
     * basinda turuncu bir leke kaliyordu. Gradyan bu kadar geri cevrilince 0.
     * durak (sky) kapagin altindaki aciyi da kapsiyor, sarma noktasi hic
     * cizilmeyen bir aciya dusuyor. Kapagin 4.5px'ine 2px kenar yumusatma payi
     * ekli.
     *
     * CountdownRingPainter._gradientBackshift ile ayni formul: bu dosya onun
     * portu, ikisi ayrisirsa widget ile Ekran 02 ayni halkayi farkli boyar.
     */
    private val GRADIENT_BACKSHIFT_DEG =
        Math.toDegrees(((TRACK_STROKE / 2f + 2f) / TRACK_RADIUS).toDouble()).toFloat()

    /**
     * `AppColors.fillSubtle` - dis telin ve emek yayinin izinin rengi. Halkanin
     * izleri temadan bagimsiz duz hex (madde 39'un sozlesmesi buna gore kurulu);
     * yalnizca YAYLARIN rengi paletten geliyor.
     */
    private const val FILL_SUBTLE = 0x17FFFFFF
    private const val TRACK_COLOR = 0x12FFFFFF

    /** Kicker'in kullanabilecegi kirisin orani - iz ile arasindaki nefes payi. */
    private const val LABEL_FIT = 0.94f

    fun render(
        context: Context,
        sizePx: Int,
        progressRatio: Float,
        accentColor: Int,
        centerText: String,
        labelText: String,
        muted: Boolean,
        todayRatio: Float,
        habitColor: Int,
        effortRatio: Float?,
        effortColor: Int,
    ): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val scale = sizePx / VIEW_BOX
        val cx = sizePx / 2f
        val cy = sizePx / 2f

        val outer = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = FILL_SUBTLE
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

        // Emek ekseni - ROADMAP madde 41. Zaman yayi sinava 300 gun kalan
        // kullanicida aylarca ~%25'te duruyordu: gecen zamani gosteriyor,
        // harcanan emegi degil. Bu yay her tamamlanan seansta kipirdiyor.
        //
        // `muted` disinda tutuluyor (gunluk yayla ayni gerekce): geri sayim
        // durmus olabilir ama odak birikmeye devam ediyor.
        if (effortRatio != null) {
            drawEffortArc(
                canvas = canvas,
                cx = cx,
                cy = cy,
                radius = EFFORT_RADIUS * scale,
                stroke = EFFORT_STROKE * scale,
                ratio = effortRatio,
                color = effortColor,
            )
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

        // "Bugun kac pomodoro" yayi, kesikli ic cemberin uzerinde. Widget
        // boylece yalnizca "kac gun kaldi" demiyor, "bugun ne yaptim" da
        // soyluyor - kullaniciyi uygulamayi acmaya cagiran sey bu.
        //
        // Sinav secilmemisken bile ciziliyor (`muted` disinda tutuluyor):
        // geri sayim durmus olabilir ama odak birikmeye devam ediyor ve bu
        // halkanin anlattigi sey sinav degil, bugun.
        if (todayRatio > 0f) {
            drawHabitArc(
                canvas = canvas,
                cx = cx,
                cy = cy,
                radius = DASHED_RADIUS * scale,
                stroke = HABIT_STROKE * scale,
                ratio = todayRatio,
                color = habitColor,
            )
        }

        drawCenterText(context, canvas, cx, cy, sizePx, centerText, labelText, accentColor, muted)
        return bitmap
    }

    /**
     * Haftalik hedefin dolulugu. Gradyan YOK: zaman yayi uc duraklik gradyanla
     * dekoratif, emek yayi tek duz tonla anlamsal - ikisi ayni boyayi
     * paylassaydi goz onlari tek bir gostergenin iki parcasi sanirdi.
     *
     * Iz her zaman ciziliyor (yay sifirken bile ekseni gosteriyor), ama sifir
     * uzunluklu yay yuvarlak ucla nokta birakirdi: haftanin basinda halkada
     * aciklanamayan bir leke olurdu.
     */
    private fun drawEffortArc(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        stroke: Float,
        ratio: Float,
        color: Int,
    ) {
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = FILL_SUBTLE
            style = Paint.Style.STROKE
            strokeWidth = stroke
        }
        canvas.drawCircle(cx, cy, radius, track)

        if (ratio <= 0f) return
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawArc(rect, -90f, 360f * ratio.coerceIn(0f, 1f), false, paint)
    }

    /**
     * Gunluk dongunun dolulugu (tamamlanan pomodoro / 4). Geri sayim yayinin
     * gradyanini tasimiyor, tek renk: iki yay ayni dili konussaydi hangisinin
     * sinav hangisinin gun oldugu okunmazdi.
     */
    private fun drawHabitArc(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        radius: Float,
        stroke: Float,
        ratio: Float,
        color: Int,
    ) {
        val rect = RectF(cx - radius, cy - radius, cx + radius, cy + radius)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawArc(rect, -90f, 360f * ratio.coerceIn(0f, 1f), false, paint)
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
        // Ustune GRADIENT_BACKSHIFT_DEG: yuvarlak ucun geride biraktigi seride
        // kozun degil gokyuzunun dusmesi icin (madde 33).
        val gradient = SweepGradient(
            cx,
            cy,
            intArrayOf(0xFF63B4FF.toInt(), 0xFFB5ABFC.toInt(), 0xFFFFB03A.toInt()),
            floatArrayOf(0f, 0.48f, 1f),
        ).apply {
            setLocalMatrix(Matrix().apply { setRotate(-90f - GRADIENT_BACKSHIFT_DEG, cx, cy) })
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
        val baselineOffset = sizePx * 0.20f
        label.textSize *= labelFitFor(label, labelText, sizePx, baselineOffset)
        canvas.drawText(labelText, cx, cy + baselineOffset, label)
    }

    /**
     * Kicker halkanin ICINE yaziliyor, altina degil - ROADMAP madde 39.
     *
     * Punto sabitken uzun durum adlari ("HEDEF SEÇİLMEDİ", "SINAVIN GEÇTİ")
     * bu satirda izin iki yanindan tasip stroke'un uzerine biniyordu; kisa
     * olanlar ("GÜN KALDI", "BUGÜN") sigdigi icin kimse gormemis. Punto
     * olculup kirise sigacak kadar kuculuyor - `counterSizeFor`un rakama
     * yaptiginin ayni, yalniz olcu karakter sayisindan degil metnin
     * kendisinden geliyor (ceviri uzarsa da tutsun diye).
     *
     * Kiris etiketin TABANINDA olculuyor: kicker merkezin altinda duruyor,
     * yani en dar yeri alt kenari.
     *
     * Madde 41: sinir zaman izinin ic kenarindan (125.5) emek yayinin ic
     * kenarina (117) indi. KOSULSUZ iniyor, hedefin acik olmasina baglanmiyor -
     * punto hedefe gore degisseydi kullanici ayari acip kapattiginda widget'in
     * yazisi boy degistirirdi.
     */
    private fun labelFitFor(
        paint: Paint,
        text: String,
        sizePx: Int,
        baselineOffset: Float,
    ): Float {
        val innerEdge = INNER_CONTENT_RADIUS * (sizePx / VIEW_BOX)
        val bottom = baselineOffset + paint.descent()
        val halfChord = sqrt((innerEdge * innerEdge - bottom * bottom).coerceAtLeast(0f))
        val maxWidth = halfChord * 2f * LABEL_FIT
        val measured = paint.measureText(text)
        return if (measured <= maxWidth) 1f else maxWidth / measured
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
