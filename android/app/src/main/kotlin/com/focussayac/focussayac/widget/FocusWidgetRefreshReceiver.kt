package com.focussayac.focussayac.widget

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Widget yeniden ciziminin tek tetikleyicisi.
 *
 * Saat basi alarmin yani sira sistemin zaman/saat dilimi olaylarini da
 * dinliyor: kullanici saati elle degistirdiginde ya da yurt disina
 * gectiginde kalan gun sayisi aninda degisiyor, bir sonraki saati beklemek
 * gorunur bir yanlislik olurdu.
 */
class FocusWidgetRefreshReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val manager = AppWidgetManager.getInstance(context) ?: return

        for (providerClass in PROVIDERS) {
            val component = ComponentName(context, providerClass)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isEmpty()) continue

            val update = Intent(context, providerClass).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(update)
        }

        RefreshScheduler.armNextHour(context)
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
