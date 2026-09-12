package com.focussayac.focussayac.widget

import android.widget.RemoteViews
import com.focussayac.focussayac.R

/**
 * Mesale widget (2x2) - geri sayim degil, kimlik. Biriken odak saatiyle
 * buyuyen kademe alevi ve sonraki kademeye kalan saat. Dokununca rozetler
 * ekranini acar; kalan saat orada tam kartiyla duruyor.
 */
class FlameWidgetProvider : BaseFocusWidgetProvider() {

    override val layoutId: Int = R.layout.widget_flame
    override val rootId: Int = R.id.widget_flame_root

    // Sinav durumundan bagimsiz: mesale sinava degil kullaniciya ait.
    override fun route(render: WidgetRenderContext): String = WidgetRoutes.BADGES

    override fun bind(render: WidgetRenderContext, views: RemoteViews) {
        val status = FlameTierLadder.statusFor(render.snapshot.cumulativeFocusSeconds)
        val context = render.context

        views.setImageViewBitmap(
            R.id.widget_flame_image,
            FlameRenderer.render(
                context = context,
                widthPx = render.px(FLAME_WIDTH_DP),
                heightPx = render.px(FLAME_HEIGHT_DP),
                tier = status.tier,
            ),
        )
        views.setTextViewText(
            R.id.widget_flame_tier,
            context.getString(FlameTierLadder.nameResFor(status.tier.index)),
        )
        views.setProgressBar(
            R.id.widget_flame_progress,
            100,
            (status.ratioInTier * 100).toInt(),
            false,
        )
        views.setTextViewText(
            R.id.widget_flame_next,
            if (status.isTopTier) {
                context.getString(R.string.widget_flame_top)
            } else {
                context.getString(R.string.widget_flame_next, status.hoursRemaining)
            },
        )
    }

    private companion object {
        const val FLAME_WIDTH_DP = 60f
        const val FLAME_HEIGHT_DP = 64f
    }
}
