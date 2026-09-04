package com.focussayac.focussayac.widget

import android.content.Context
import androidx.annotation.ColorInt
import com.focussayac.focussayac.R

/**
 * `lib/core/theme/app_colors.dart` icindeki `AppColors.dark()` tokenlarina
 * Kotlin tarafindan erisim.
 *
 * Degerler burada tanimli DEGIL; tek kaynak `res/values/focus_colors.xml`.
 * Boylece palet Android tarafinda tek yerde durur ve
 * `test/android/focus_palette_sync_test.dart` o tek dosyayi Dart paletiyle
 * karsilastirarak sapmayi yakalayabilir.
 */
class FocusPalette(context: Context) {
    @ColorInt val bg: Int = context.getColor(R.color.focus_bg)
    @ColorInt val text: Int = context.getColor(R.color.focus_text)

    @ColorInt val ember: Int = context.getColor(R.color.focus_ember)
    @ColorInt val emberDim: Int = context.getColor(R.color.focus_ember_dim)

    @ColorInt val sky: Int = context.getColor(R.color.focus_sky)

    @ColorInt val neutral300: Int = context.getColor(R.color.focus_neutral_300)
    @ColorInt val neutral400: Int = context.getColor(R.color.focus_neutral_400)
    @ColorInt val neutral500: Int = context.getColor(R.color.focus_neutral_500)
    @ColorInt val neutral700: Int = context.getColor(R.color.focus_neutral_700)

    @ColorInt val accent400: Int = context.getColor(R.color.focus_accent_400)

    @ColorInt val divider: Int = context.getColor(R.color.focus_divider)

    /**
     * Sinav secilmemisken kullanilan sakin vurgu. Accent moru, "izin/bilgi"
     * rolunu tasidigi icin (SPEC 2 "Renk ROL tasir") notr durumun dogal rengi.
     */
    @ColorInt val neutralAccent: Int = accent400
}

/** dp -> px. Widget bitmap'leri piksel cinsinden cizilir. */
fun Context.widgetPx(dp: Float): Float = dp * resources.displayMetrics.density
