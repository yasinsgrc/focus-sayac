package com.focussayac.focussayac.widget

import android.widget.RemoteViews
import com.focussayac.focussayac.R

/**
 * Panorama widget (4x2) - halka, sinav tarihi, seri ve haftalik sutunlar
 * tek kartta. Ana ekranda tek widget isteyenler icin butun hikaye.
 */
class PanoramaWidgetProvider : BaseFocusWidgetProvider() {

    override val layoutId: Int = R.layout.widget_panorama
    override val rootId: Int = R.id.widget_panorama_root

    override fun bind(render: WidgetRenderContext, views: RemoteViews) {
        views.setImageViewBitmap(
            R.id.widget_panorama_ring,
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
        views.setTextViewText(R.id.widget_panorama_name, render.examLine())
        views.setTextViewText(R.id.widget_panorama_date, render.examDateLine())
        views.setTextViewText(R.id.widget_panorama_streak, render.streakLine())
        views.setImageViewBitmap(
            R.id.widget_panorama_spark,
            SparkRenderer.render(
                context = render.context,
                widthPx = render.px(SPARK_WIDTH_DP),
                heightPx = render.px(SPARK_HEIGHT_DP),
                values = render.snapshot.weeklyMinutes,
                accentColor = render.palette.ember,
            ),
        )
    }

    private companion object {
        const val RING_SIZE_DP = 84f
        const val SPARK_WIDTH_DP = 140f
        const val SPARK_HEIGHT_DP = 22f
    }
}
