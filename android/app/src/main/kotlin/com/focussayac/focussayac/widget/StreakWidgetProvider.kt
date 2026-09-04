package com.focussayac.focussayac.widget

import android.widget.RemoteViews
import com.focussayac.focussayac.R

/**
 * Seri widget (2x2) - geri sayim degil, alismanlik. Seri, bugunku odak ve
 * son 7 gunun sutunlari. Dokununca istatistik ekranini acar.
 */
class StreakWidgetProvider : BaseFocusWidgetProvider() {

    override val layoutId: Int = R.layout.widget_streak
    override val rootId: Int = R.id.widget_streak_root

    override fun route(render: WidgetRenderContext): String = WidgetRoutes.STATS

    override fun bind(render: WidgetRenderContext, views: RemoteViews) {
        views.setTextViewText(R.id.widget_streak_value, render.streakLine())
        views.setTextViewText(R.id.widget_streak_today, render.todayLine())
        views.setImageViewBitmap(
            R.id.widget_streak_spark,
            SparkRenderer.render(
                context = render.context,
                widthPx = render.px(SPARK_WIDTH_DP),
                heightPx = render.px(SPARK_HEIGHT_DP),
                values = render.snapshot.weeklyMinutes,
                accentColor = render.palette.ember,
            ),
        )
        // Sinav satiri geri sayimin ozeti: seri widget da olsa hangi hedefe
        // calisildigi gorunur kalmali.
        views.setTextViewText(
            R.id.widget_streak_exam,
            if (render.state == FocusWidgetSnapshot.State.COUNTING) {
                render.examLine() + SEPARATOR + render.compactRemaining()
            } else {
                render.examLine()
            },
        )
    }

    private companion object {
        const val SPARK_WIDTH_DP = 84f
        const val SPARK_HEIGHT_DP = 26f
        const val SEPARATOR = " · "
    }
}
