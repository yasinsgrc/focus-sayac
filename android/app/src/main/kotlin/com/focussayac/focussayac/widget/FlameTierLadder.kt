package com.focussayac.focussayac.widget

import com.focussayac.focussayac.R

/**
 * Mesale kademe merdiveninin Kotlin aynasi. Kaynak:
 * lib/domain/flame/flame_tier.dart -> kFlameTierLadder
 *
 * ONEMLI: Asagidaki FlameTier(...) satirlarinin bicimi sozlesmenin parcasi.
 * test/android/flame_tier_sync_test.dart bu satirlari duzenli ifadeyle
 * ayristirip Dart tablosuyla karsilastiriyor; argumanlari yeniden siralamak
 * ya da satira bolmek testi dusurur.
 */
data class FlameTier(
    val index: Int,
    val thresholdHours: Int,
    val scale: Float,
    val emberBase: Boolean,
    val sparkCount: Int,
    val haloOpacity: Float,
)

/** Bir anin kademe durumu - Dart'taki FlameTierStatus ile ayni alanlar. */
data class FlameTierStatus(
    val tier: FlameTier,
    val nextTier: FlameTier?,
    val hoursRemaining: Int?,
    val ratioInTier: Float,
    val cumulativeHours: Int,
) {
    val isTopTier: Boolean get() = nextTier == null
}

object FlameTierLadder {

    val TIERS: List<FlameTier> = listOf(
        FlameTier(index = 1, thresholdHours = 0, scale = 0.35f, emberBase = false, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 2, thresholdHours = 1, scale = 0.42f, emberBase = false, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 3, thresholdHours = 3, scale = 0.50f, emberBase = false, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 4, thresholdHours = 10, scale = 0.58f, emberBase = true, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 5, thresholdHours = 25, scale = 0.65f, emberBase = true, sparkCount = 0, haloOpacity = 0.0f),
        FlameTier(index = 6, thresholdHours = 50, scale = 0.72f, emberBase = true, sparkCount = 2, haloOpacity = 0.0f),
        FlameTier(index = 7, thresholdHours = 100, scale = 0.80f, emberBase = true, sparkCount = 3, haloOpacity = 0.0f),
        FlameTier(index = 8, thresholdHours = 175, scale = 0.87f, emberBase = true, sparkCount = 3, haloOpacity = 0.18f),
        FlameTier(index = 9, thresholdHours = 250, scale = 0.94f, emberBase = true, sparkCount = 4, haloOpacity = 0.26f),
        FlameTier(index = 10, thresholdHours = 400, scale = 1.0f, emberBase = true, sparkCount = 5, haloOpacity = 0.34f),
    )

    /** Kademe adlari - ARB'deki flameTier{N}Name ile birebir ayni kelimeler. */
    fun nameResFor(index: Int): Int = when (index) {
        1 -> R.string.widget_flame_tier_1
        2 -> R.string.widget_flame_tier_2
        3 -> R.string.widget_flame_tier_3
        4 -> R.string.widget_flame_tier_4
        5 -> R.string.widget_flame_tier_5
        6 -> R.string.widget_flame_tier_6
        7 -> R.string.widget_flame_tier_7
        8 -> R.string.widget_flame_tier_8
        9 -> R.string.widget_flame_tier_9
        else -> R.string.widget_flame_tier_10
    }

    /**
     * Dart'taki `flameTierFor` ile birebir ayni kural: saat ASAGI yuvarlanir
     * (`floor(sn/3600)`), negatif girdi sifira duser.
     */
    fun statusFor(cumulativeSeconds: Int): FlameTierStatus {
        val hours = if (cumulativeSeconds <= 0) 0 else cumulativeSeconds / 3600

        var position = 0
        for (i in 1 until TIERS.size) {
            if (hours >= TIERS[i].thresholdHours) position = i
        }

        val tier = TIERS[position]
        val next = TIERS.getOrNull(position + 1)
            ?: return FlameTierStatus(tier, null, null, 1f, hours)

        val span = next.thresholdHours - tier.thresholdHours
        return FlameTierStatus(
            tier = tier,
            nextTier = next,
            hoursRemaining = next.thresholdHours - hours,
            ratioInTier = ((hours - tier.thresholdHours).toFloat() / span).coerceIn(0f, 1f),
            cumulativeHours = hours,
        )
    }
}
