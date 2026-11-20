package com.app.odaq.widget

import android.content.Context
import android.graphics.Typeface
import androidx.core.content.res.ResourcesCompat
import com.app.odaq.R

/**
 * Bitmap icine cizilen metinlerin yazi tipleri. Uygulamanin yazi tipi
 * sistemiyle ayni (lib/core/theme/app_typography.dart):
 * Hepsi Poppins (baslik, sayac, kicker, govde).
 *
 * RemoteViews TextView nesneleri fontu android:fontFamily ile dogrudan
 * alabiliyor; burasi yalnizca Canvas uzerine cizilen metinler icin.
 */
object WidgetTypography {
    /** Sayac rakami. Prototipin letter-spacing: -.045em degeri. */
    const val COUNTER_LETTER_SPACING = -0.045f

    /** Kicker etiketi. Prototipin letter-spacing: .26em degeri. */
    const val KICKER_LETTER_SPACING = 0.26f

    fun counter(context: Context): Typeface =
        ResourcesCompat.getFont(context, R.font.poppins_700) ?: Typeface.DEFAULT_BOLD

    fun display(context: Context): Typeface =
        ResourcesCompat.getFont(context, R.font.poppins_500) ?: Typeface.DEFAULT

    fun kicker(context: Context): Typeface =
        ResourcesCompat.getFont(context, R.font.poppins_500) ?: Typeface.DEFAULT

    fun body(context: Context): Typeface =
        ResourcesCompat.getFont(context, R.font.poppins_500) ?: Typeface.DEFAULT
}
