package com.focussayac.focussayac.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import androidx.annotation.IdRes
import androidx.annotation.LayoutRes
import com.focussayac.focussayac.MainActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Bes widget icin ortak iskelet: anlik goruntuyu yukler, turetilmis degerleri
 * hesaplar, dokunma niyetini baglar ve bir sonraki saat basi alarmini kurar.
 * Alt siniflarin tek isi kendi yerlesimini doldurmak.
 */
abstract class BaseFocusWidgetProvider : HomeWidgetProvider() {

    @get:LayoutRes
    protected abstract val layoutId: Int

    @get:IdRes
    protected abstract val rootId: Int

    /** Alt sinifin yerlesim doldurma adimi. */
    protected abstract fun bind(render: WidgetRenderContext, views: RemoteViews)

    /**
     * Widget govdesine dokununca acilacak rota. Varsayilan geri sayim;
     * Seri widget istatistik ekranini actigi icin bunu ezer.
     */
    protected open fun route(render: WidgetRenderContext): String = when (render.state) {
        FocusWidgetSnapshot.State.NO_EXAM -> WidgetRoutes.COUNTDOWN_PICK
        FocusWidgetSnapshot.State.EXPIRED -> WidgetRoutes.EXAM_EXPIRED
        else -> WidgetRoutes.COUNTDOWN
    }

    final override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val render = WidgetRenderContext(
            context = context,
            snapshot = FocusWidgetSnapshot.load(widgetData),
            nowMillis = System.currentTimeMillis(),
            palette = FocusPalette(context),
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, layoutId)
            bind(render, views)
            views.setOnClickPendingIntent(rootId, launchIntent(context, route(render)))
            appWidgetManager.updateAppWidget(widgetId, views)
        }

        RefreshScheduler.armNextHour(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Alarm butun widget turleri icin ortak; yalnizca ekranda hicbiri
        // kalmadiginda iptal ediliyor. Tek bir turu kaldirmak digerlerini de
        // dondururdu.
        if (!hasAnyWidget(context)) RefreshScheduler.cancel(context)
    }

    protected fun launchIntent(context: Context, path: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            WidgetRoutes.uri(path),
        )

    private fun hasAnyWidget(context: Context): Boolean {
        val manager = AppWidgetManager.getInstance(context) ?: return false
        return PROVIDERS.any { provider ->
            manager.getAppWidgetIds(ComponentName(context, provider)).isNotEmpty()
        }
    }

    private companion object {
        val PROVIDERS = listOf(
            RingWidgetProvider::class.java,
            StripWidgetProvider::class.java,
            StreakWidgetProvider::class.java,
            QuickFocusWidgetProvider::class.java,
            PanoramaWidgetProvider::class.java,
        )
    }
}
