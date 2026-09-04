package com.focussayac.focussayac.widget

import android.widget.RemoteViews
import com.focussayac.focussayac.R

/**
 * Halka widget (2x2) - kac gun kaldi sorusunun en kisa cevabi.
 * Govde tek bitmap; altta sinav adi.
 */
class RingWidgetProvider : BaseFocusWidgetProvider() {

    override val layoutId: Int = R.layout.widget_ring
    override val rootId: Int = R.id.widget_ring_root

    override fun bind(render: WidgetRenderContext, views: RemoteViews) {
        views.setImageViewBitmap(
            R.id.widget_ring_image,
            RingRenderer.render(
                context = render.context,
                sizePx = render.px(RING_SIZE_DP),
                progressRatio = render.ratio,
                accentColor = render.accent,
                centerText = render.dayText(),
                labelText = render.statusLabel(),
                muted = render.muted,
            ),
        )
        views.setTextViewText(R.id.widget_ring_exam, render.examLine())
        views.setTextColor(
            R.id.widget_ring_exam,
            if (render.muted) render.palette.neutral500 else render.palette.neutral300,
        )
    }

    private companion object {
        /**
         * Bitmap her zaman sabit dp cizilip ImageView icinde olceklenir.
         * RemoteViews islem sinirinda (yaklasik 1 MB) kalmak icin cozunurluk
         * ekran yogunlugundan bagimsiz tutuluyor.
         */
        const val RING_SIZE_DP = 104f
    }
}
