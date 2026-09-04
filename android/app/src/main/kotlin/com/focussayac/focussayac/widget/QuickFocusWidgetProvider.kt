package com.focussayac.focussayac.widget

import android.widget.RemoteViews
import com.focussayac.focussayac.R

/**
 * Hizli Odak widget (4x2) - tek eylem. Butona dokunmak uygulamayi acip
 * seansi dogrudan baslatir.
 *
 * Seans zaten calisiyorsa yeni seans BASLATMAZ: buton ODAGA DON metnine
 * doner ve odak ekranini acar. Aksi halde widget calisan bir seansi
 * sessizce iptal edip yerine yenisini koyardi.
 */
class QuickFocusWidgetProvider : BaseFocusWidgetProvider() {

    override val layoutId: Int = R.layout.widget_quick_focus
    override val rootId: Int = R.id.widget_quick_root

    override fun bind(render: WidgetRenderContext, views: RemoteViews) {
        views.setTextViewText(R.id.widget_quick_exam, render.examLine())
        views.setTextViewText(
            R.id.widget_quick_days,
            if (render.state == FocusWidgetSnapshot.State.COUNTING) {
                render.compactRemaining()
            } else {
                render.statusLabel()
            },
        )
        views.setTextColor(
            R.id.widget_quick_days,
            if (render.muted) render.palette.neutral500 else render.accent,
        )

        val running = render.snapshot.sessionActive
        views.setTextViewText(
            R.id.widget_quick_button,
            render.context.getString(
                if (running) R.string.widget_resume_button else R.string.widget_focus_button
            ),
        )
        // Calisan seansta hap sakinlesiyor: ember dolgu bir eylem cagrisi,
        // devam eden seans icin yanlis bir vurgu olurdu.
        views.setInt(
            R.id.widget_quick_button,
            "setBackgroundResource",
            if (running) R.drawable.widget_button_muted else R.drawable.widget_button,
        )
        views.setTextColor(
            R.id.widget_quick_button,
            if (running) render.palette.accent400 else render.palette.bg,
        )

        views.setOnClickPendingIntent(
            R.id.widget_quick_button,
            launchIntent(
                render.context,
                if (running) WidgetRoutes.FOCUS else WidgetRoutes.FOCUS_AUTOSTART,
            ),
        )
    }
}
