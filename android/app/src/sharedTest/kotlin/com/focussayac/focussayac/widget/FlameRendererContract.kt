package com.focussayac.focussayac.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import kotlin.math.abs

/**
 * `FlameRenderer` cizim yolunun sozlesmesi. ROADMAP madde 31; tasarim:
 * docs/superpowers/specs/2026-09-18-flame-renderer-dogrulama-design.md
 *
 * Iki kosum evi de (src/test Robolectric, src/androidTest cihaz) BU dosyayi
 * derliyor - `build.gradle.kts` sharedTest dizinini iki kaynak kumesine de
 * ekliyor. Iddialar burada tek yerde, kosucular ince.
 *
 * Iddialar altin goruntu DEGIL: Robolectric'in native grafigi ile gercek
 * cihazin grafik yigini bayt bayt uzlasmaz. Onun yerine her iddia geometriyi
 * kademe merdivenine (FlameTierLadder) bagliyor.
 */
object FlameRendererContract {

    /** Uretimdeki olcu: FlameWidgetProvider 60x64dp istiyor (~2.6x yogunluk). */
    const val WIDTH_PX = 157
    const val HEIGHT_PX = 168

    /** FlameRenderer'daki 44f/86f govde orani - sonda konumlari buna dayali. */
    private const val BODY_ASPECT = 44f / 86f

    // Alfa esikleri, FlameRenderer'in kendi alfalarindan tureyen sayilar:
    // govde `emberBase` kademelerinde 0xB3 ile modulelenir (paint.color
    // kozdan kaliyor ve shader'i suzuyor), koz 0xB3, cekirdek 0xF2, kivilcim
    // 0xCC. Hale ise en fazla 0.34*255 = 0x57. Esikler haleyi GERCEK
    // cizimlerden ayiracak sekilde secildi.
    private const val SOLID = 0x80
    private const val SPARK_FLOOR = 0xA0
    private const val CLEAR = 0x20

    /** On kademenin bitmap'i - kademe indeksinden (1..10) bitmap'e. */
    fun renderAll(context: Context): Map<Int, Bitmap> =
        FlameTierLadder.TIERS.associate { tier ->
            tier.index to FlameRenderer.render(
                context = context,
                widthPx = WIDTH_PX,
                heightPx = HEIGHT_PX,
                tier = tier,
            )
        }

    /** Tek kademenin butun iddialari. */
    fun verifyTier(bitmap: Bitmap, tier: FlameTier) {
        val label = "K${tier.index}"

        assertEquals("$label genisligi", WIDTH_PX, bitmap.width)
        assertEquals("$label yuksekligi", HEIGHT_PX, bitmap.height)

        val bodyHeight = HEIGHT_PX * tier.scale
        val bodyWidth = bodyHeight * BODY_ASPECT
        val centerX = WIDTH_PX / 2
        val bottom = HEIGHT_PX

        // 1. Cizim gercekten oldu: bos bitmap degil.
        assertTrue("$label hic cizilmemis - bitmap tamamen saydam", opaqueCount(bitmap) > 0)

        // 2. Olcek: govdenin tepesi kademenin `scale`inden geliyor. Merkez
        // sutununda hale de var (K8+) ama hale hep SOLID esiginin altinda,
        // govde her zaman ustunde - esik ikisini ayiriyor.
        val expectedTop = HEIGHT_PX - bodyHeight
        val measuredTop = bodyTop(bitmap)
        assertTrue(
            "$label govde tepesi: beklenen ~${expectedTop.toInt()}, olculen $measuredTop",
            abs(measuredTop - expectedTop) <= 3f,
        )

        // 3. Koz: govdenin dibi cok yuvarlak oldugu icin kozun yanlari
        // govdenin disinda kaliyor. Sonda ovalin orta satirinda, merkezden
        // 0.4*bodyWidth uzakta - orada govde yok (o satirda govdenin yari
        // genisligi 0.25*bodyWidth), koz varsa 0xB3.
        val emberAlpha = alphaAt(
            bitmap,
            centerX + (bodyWidth * 0.4f).toInt(),
            bottom - (bodyHeight * 0.11f / 2f).toInt(),
        )
        if (tier.emberBase) {
            assertTrue("$label koz tabani yok (alfa $emberAlpha)", emberAlpha >= SOLID)
        } else {
            // Negatif yon yalnizca K1-K3'te sinaniyor; onlarin halesi de yok,
            // yani sonda noktasi gercekten bos olmali.
            assertTrue("$label kozsuz olmali ama alfa $emberAlpha", emberAlpha <= CLEAR)
        }

        // 4. Hale: govdenin yaninda, merkezden 0.7*bodyWidth uzakta ve halenin
        // merkez yuksekliginde. Kivilcimlar govdenin ust yarisinda, bu satira
        // inmiyorlar - yani buradaki tek cizim hale.
        val haloAlpha = alphaAt(
            bitmap,
            centerX + (bodyWidth * 0.7f).toInt(),
            bottom - (bodyHeight * 0.45f).toInt(),
        )
        if (tier.haloOpacity > 0f) {
            assertTrue("$label halesi yok (alfa $haloAlpha)", haloAlpha > 8)
        } else {
            assertEquals("$label halesiz olmali", 0, haloAlpha)
        }

        // 5. Kivilcim: govdenin disindaki seritte KAC tane ayri kivilcim
        // gorunuyor. Konumdan bagimsiz - formule degil merdivenin sozune
        // ("K6'dan sonra kivilcimlar") bagli iddia.
        val sparks = countSparkBlobs(bitmap, centerX, bodyWidth)
        assertEquals("$label kivilcim sayisi", tier.sparkCount, sparks)
    }

    /**
     * On kademenin hepsini sinar ve hatalari BIRIKTIRIP tek seferde atar.
     * Ilk hatada durmak "K8 bozuk" derdi; bu haliyle "K8, K9, K10 bozuk"
     * diyor - kademe merdiveninin neresinin kirildigi tek kosumda gorunuyor.
     */
    fun verifyAllTiers(bitmaps: Map<Int, Bitmap>) {
        val failures = mutableListOf<String>()
        FlameTierLadder.TIERS.forEach { tier ->
            try {
                verifyTier(bitmaps.getValue(tier.index), tier)
            } catch (error: AssertionError) {
                failures += error.message ?: "K${tier.index}: mesajsiz hata"
            }
        }
        if (failures.isNotEmpty()) {
            throw AssertionError(failures.joinToString(separator = "\n", prefix = "\n"))
        }
    }

    /** Merdiven boyunca olcek monoton buyuyor - kademeler ayirt edilebilir. */
    fun verifyLadder(bitmaps: Map<Int, Bitmap>) {
        assertEquals("kademe sayisi", 10, bitmaps.size)
        val tops = FlameTierLadder.TIERS.map { bodyTop(bitmaps.getValue(it.index)) }
        tops.zipWithNext().forEachIndexed { i, (lower, higher) ->
            assertTrue(
                "K${i + 1} -> K${i + 2} govde buyumuyor ($lower -> $higher)",
                higher < lower,
            )
        }
    }

    /**
     * Merkez sutununda ilk "dolu" pikselin y'si. Govdenin gradyani opak
     * renklerden kuruluyor, hale ise her zaman yari saydam; SOLID esigi
     * ikisini ayiriyor.
     */
    fun bodyTop(bitmap: Bitmap): Int {
        val x = bitmap.width / 2
        for (y in 0 until bitmap.height) {
            if (alphaAt(bitmap, x, y) >= SOLID) return y
        }
        return bitmap.height
    }

    /**
     * Govdenin disindaki seritte birbirine bagli kivilcim lekelerini sayar.
     * Serit `0.54*bodyWidth`ten disari: govde en fazla `0.5*bodyWidth` genis,
     * koz `0.46*bodyWidth` - ikisi de seride girmiyor. Hale giriyor ama
     * alfasi SPARK_FLOOR'un altinda kaliyor.
     */
    private fun countSparkBlobs(bitmap: Bitmap, centerX: Int, bodyWidth: Float): Int {
        val inner = (bodyWidth * 0.54f).toInt()
        val width = bitmap.width
        val height = bitmap.height

        fun isSpark(x: Int, y: Int) =
            abs(x - centerX) >= inner && alphaAt(bitmap, x, y) >= SPARK_FLOOR

        val seen = HashSet<Int>()
        var blobs = 0
        for (y in 0 until height) {
            for (x in 0 until width) {
                val start = y * width + x
                if (start in seen || !isSpark(x, y)) continue
                blobs++
                // Dort komsulu tasma doldurma - lekenin tamamini isaretle,
                // yoksa ayni kivilcim her pikseliyle yeniden sayilirdi.
                val stack = ArrayDeque<Int>()
                stack.addLast(start)
                seen.add(start)
                while (stack.isNotEmpty()) {
                    val key = stack.removeLast()
                    val cy = key / width
                    val cx = key % width
                    val neighbours = listOf(
                        cx - 1 to cy,
                        cx + 1 to cy,
                        cx to cy - 1,
                        cx to cy + 1,
                    )
                    for ((nx, ny) in neighbours) {
                        if (nx !in 0 until width || ny !in 0 until height) continue
                        val nk = ny * width + nx
                        if (nk in seen || !isSpark(nx, ny)) continue
                        seen.add(nk)
                        stack.addLast(nk)
                    }
                }
            }
        }
        return blobs
    }

    private fun opaqueCount(bitmap: Bitmap): Int {
        var count = 0
        for (y in 0 until bitmap.height) {
            for (x in 0 until bitmap.width) {
                if (alphaAt(bitmap, x, y) > 0) count++
            }
        }
        return count
    }

    private fun alphaAt(bitmap: Bitmap, x: Int, y: Int): Int {
        if (x !in 0 until bitmap.width || y !in 0 until bitmap.height) return 0
        return Color.alpha(bitmap.getPixel(x, y))
    }
}
