package com.focussayac.focussayac.widget

import android.widget.RemoteViews
import com.focussayac.focussayac.R

/**
 * Serit widget (4x1) - ana ekranin alt sirasi icin dar bir seride sinav adi,
 * kalan gun/saat ve doluluk cubugu.
 */
class StripWidgetProvider : BaseFocusWidgetProvider() {

    override val layoutId: Int = R.layout.widget_strip
    override val rootId: Int = R.id.widget_strip_root

    override fun bind(render: WidgetRenderContext, views: RemoteViews) {
        views.setTextViewText(R.id.widget_strip_exam, render.examLine())
        views.setTextViewText(R.id.widget_strip_value, render.compactRemaining())
        views.setTextColor(
            R.id.widget_strip_value,
            if (render.muted) render.palette.neutral500 else render.accent,
        )
        views.setImageViewBitmap(
            R.id.widget_strip_bar,
            StripRenderer.render(
                context = render.context,
                widthPx = render.px(BAR_WIDTH_DP),
                heightPx = render.px(BAR_HEIGHT_DP),
                ratio = if (render.muted) 0f else render.ratio,
                accentColor = render.accent,
            ),
        )
    }

    private companion object {
        // Cubuk scaleType fitXY ile gerildigi icin genislik yalnizca en
        // oranini belirliyor; gercek piksel genisligini ImageView veriyor.
        const val BAR_WIDTH_DP = 240f
        const val BAR_HEIGHT_DP = 6f
    }
}
