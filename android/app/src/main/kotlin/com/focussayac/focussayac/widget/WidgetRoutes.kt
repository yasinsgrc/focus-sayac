package com.focussayac.focussayac.widget

import android.net.Uri

/**
 * Widget dokunuslarinin actigi uygulama rotalari. Degerler
 * lib/core/router/route_paths.dart icindeki RoutePaths ile birebir ayni
 * olmak zorunda; Dart tarafinda WidgetLaunchHandler bu Uri nesnesinin
 * yolunu dogrudan go_router adresine ceviriyor.
 */
object WidgetRoutes {
    private const val SCHEME = "focussayac"
    private const val HOST = "widget"

    const val COUNTDOWN = "/countdown"
    const val STATS = "/stats"
    const val FOCUS = "/focus"
    const val EXAM_EXPIRED = "/exam-expired"

    /** Hizli Odak butonu: uygulamayi acar ve seansi dogrudan baslatir. */
    const val FOCUS_AUTOSTART = "/focus?autostart=1"

    /** Sinav secilmemisken geri sayim ekranini secici acik halde acar. */
    const val COUNTDOWN_PICK = "/countdown?pick=1"

    fun uri(path: String): Uri = Uri.parse("$SCHEME://$HOST$path")
}
