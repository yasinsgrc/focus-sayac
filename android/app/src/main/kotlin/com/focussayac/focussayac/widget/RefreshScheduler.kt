package com.focussayac.focussayac.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Widget tazeleme alarmi.
 *
 * AppWidgetProviderInfo.updatePeriodMillis kullanilmiyor: sistem onu en iyi
 * ihtimalle 30 dakikada bir ve garantisiz tetikliyor. Widget saat basinda
 * degisen bir sayi gosterdigi icin (kalan gun/saat) saat basina hizalanmis
 * kendi alarmimiz daha dogru ve daha ucuz.
 *
 * Alarm KESIN degil (setInexactRepeating degil, set + yeniden kurma):
 * birkac dakikalik sapma widget icin onemsiz, kesin alarm ise Android 12+
 * icinde SCHEDULE_EXACT_ALARM gerektirip pil kisitlamalarina takiliyor.
 */
object RefreshScheduler {

    const val ACTION_REFRESH = "com.focussayac.focussayac.widget.ACTION_REFRESH"

    private const val REQUEST_CODE = 7311
    private const val HOUR_MS = 3_600_000L

    /** Bir sonraki tam saate alarm kurar. Var olan alarmin uzerine yazar. */
    fun armNextHour(context: Context) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.set(AlarmManager.RTC, nextHourBoundary(), pendingIntent(context))
    }

    fun cancel(context: Context) {
        val alarmManager =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.cancel(pendingIntent(context))
    }

    private fun nextHourBoundary(): Long {
        val calendar = Calendar.getInstance().apply {
            add(Calendar.HOUR_OF_DAY, 1)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        // Saat sinirina cok yakin uyandiysak bir sonraki saate kay: aksi
        // halde alarm gecmise kurulup aninda tekrar tetiklenebiliyor.
        val target = calendar.timeInMillis
        return if (target - System.currentTimeMillis() < 60_000L) target + HOUR_MS else target
    }

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, FocusWidgetRefreshReceiver::class.java).apply {
            action = ACTION_REFRESH
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, REQUEST_CODE, intent, flags)
    }
}
