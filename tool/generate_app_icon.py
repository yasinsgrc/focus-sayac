"""FocusSayaç marka işaretinden platform ikon kaynaklarını üretir.

Kaynak işaret `assets/logo/FocusMark.dc.html` (tam renk) ve
`assets/logo/FocusMarkMono.dc.html` (tek renk). Geometri 512 birimlik kare
uzayda tanımlı ve uygulamanın kendi çizimleriyle örtüşür: halka
`lib/features/countdown/widgets/countdown_ring_painter.dart`, alev
`lib/features/focus_session/widgets/flame_widget.dart` ölçülerinin 1.909
katıdır (84/44 = 163/86 = 34/18).

Yüzeyler `assets/logo/Görsel Kimlik.dc.html` içindeki 01-06 numaralı
bölümlere karşılık gelir.

Çalıştırma:
    python tool/generate_app_icon.py
"""

from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw

# --- Tasarım uzayı ----------------------------------------------------------

U = 512.0  # işaretin kendi kare uzayı
SS = 4  # süperörnekleme; tüm katmanlar SSx çizilip tek seferde küçültülür

BG = (0x0B, 0x0C, 0x14)  # AppColors.dark().bg
EMBER = (0xFF, 0xB0, 0x3A)

# Halka: yarıçapın %16'sı kalınlık => iç yarıçap dışın %84'ü (mono'da %82).
RING_INNER = 0.84
RING_INNER_MONO = 0.82
RING_START_TURN = -0.25  # "üstten -90°": 9 yönünden başlar
RING_SWEEP_TURN = 0.78

# conic-gradient(from -90deg, ...) durakları, tur cinsinden.
RING_STOPS = (
    (0.00, (0x63, 0xB4, 0xFF)),
    (0.30, (0xB5, 0xAB, 0xFC)),
    (0.60, (0xFF, 0xB0, 0x3A)),
    (0.78, (0xFF, 0xB0, 0x3A)),
)

# İçteki noktalı çember: inset 58px + 3px dotted => merkez yarıçapı 196.5.
DOT_RADIUS = 196.5
DOT_SIZE = 3.0
DOT_PERIOD = 6.0  # CSS `dotted`: nokta kadar boşluk
DOT_COLOR = EMBER + (int(round(0.42 * 255)),)

# Alev gövdesi: 84x163, alt kenarı tuvalin altından 174 birim yukarıda.
FLAME_W, FLAME_H = 84.0, 163.0
FLAME_BOTTOM = 174.0
FLAME_RADII = ((42.0, 110.0), (42.0, 110.0), (38.0, 51.0), (38.0, 51.0))  # TL TR BR BL
FLAME_STOPS = (
    (0.00, (0x7A, 0x2F, 0x0C)),
    (0.56, (0xFF, 0xB0, 0x3A)),
    (1.00, (0xFF, 0xF3, 0xD8)),
)

# Alev çekirdeği: 34x87, gövde kutusunun altından 23 birim yukarıda.
CORE_W, CORE_H = 34.0, 87.0
CORE_BOTTOM = 23.0
CORE_RADII = ((17.0, 53.0), (17.0, 53.0), (17.0, 32.0), (17.0, 32.0))
CORE_COLOR = (0xFF, 0xFA, 0xF0, int(round(0.95 * 255)))

TRACK_COLOR = (0xFF, 0xFF, 0xFF, int(round(0.10 * 255)))

# Zemin: ember radyal gradyan (adaptive background ile aynı formül).
GLOW_CENTER = (0.50, 0.52)
GLOW_RADIUS = 0.62
GLOW_ALPHA = 0.18

# İşaretin tuval içindeki oranı (Görsel Kimlik 01/02/03).
LEGACY_MARK = 0.76  # eski kare simge
ADAPTIVE_MARK = 72.0 / 108.0  # 108 dp katmanda 72 dp güvenli alan
NOTIFICATION_MARK = 0.92
PLAY_MARK = 0.76

DENSITIES = ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")
SCALES = (1.0, 1.5, 2.0, 3.0, 4.0)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")


# --- Yardımcılar ------------------------------------------------------------


def _lerp_stops(stops, t):
    """`stops` üzerinde t konumundaki rengi doğrusal ara değerle bulur."""
    if t <= stops[0][0]:
        return stops[0][1]
    if t >= stops[-1][0]:
        return stops[-1][1]
    for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
        if p0 <= t <= p1:
            f = 0.0 if p1 == p0 else (t - p0) / (p1 - p0)
            return tuple(c0[i] + (c1[i] - c0[i]) * f for i in range(3))
    return stops[-1][1]


def _rounded_polygon(box, radii, steps=96):
    """CSS `border-radius` (eliptik köşeli) dikdörtgeni çokgene çevirir.

    `radii` sırası CSS'teki gibi TL, TR, BR, BL; her biri (rx, ry).
    """
    x0, y0, x1, y1 = box
    (tl, tr, br, bl) = radii
    pts = []

    def arc(cx, cy, rx, ry, a0, a1):
        for i in range(steps + 1):
            a = math.radians(a0 + (a1 - a0) * i / steps)
            pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))

    arc(x1 - tr[0], y0 + tr[1], tr[0], tr[1], -90, 0)  # sağ üst
    arc(x1 - br[0], y1 - br[1], br[0], br[1], 0, 90)  # sağ alt
    arc(x0 + bl[0], y1 - bl[1], bl[0], bl[1], 90, 180)  # sol alt
    arc(x0 + tl[0], y0 + tl[1], tl[0], tl[1], 180, 270)  # sol üst
    return pts


def _polygon_mask(n, pts):
    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    return mask


def _vertical_gradient(n, box, stops):
    """Kutunun altından üstüne doğrusal gradyan (CSS `to top`)."""
    _, y0, _, y1 = box
    ramp = np.zeros((n, 3), dtype=np.float64)
    for y in range(n):
        t = 0.0 if y1 == y0 else (y1 - y) / (y1 - y0)
        ramp[y] = _lerp_stops(stops, min(max(t, 0.0), 1.0))
    return Image.fromarray(
        np.repeat(ramp[:, None, :], n, axis=1).round().astype(np.uint8), "RGB"
    )


def _polar(n):
    """Merkeze göre yarıçap oranı ve tepeden saat yönünde açı (tur)."""
    c = (n - 1) / 2.0
    ax = np.arange(n) - c
    dx = ax[None, :]
    dy = ax[:, None]
    r = np.hypot(dx, dy) / (n / 2.0)
    turn = (np.arctan2(dx, -dy) / (2 * math.pi)) % 1.0
    return r, turn


def _ring(n, inner, sweep, colorize):
    """Halka katmanı: `colorize(t)` verilen tur konumu için RGB döndürür."""
    r, turn = _polar(n)
    band = (r >= inner) & (r <= 1.0)
    t = (turn - (RING_START_TURN % 1.0)) % 1.0
    keep = band & (t <= sweep)

    rgb = np.zeros((n, n, 3), dtype=np.uint8)
    ys, xs = np.nonzero(keep)
    if len(ys):
        lut_n = 1024
        lut = np.array(
            [colorize(sweep * i / (lut_n - 1)) for i in range(lut_n)], dtype=np.float64
        )
        idx = np.clip((t[ys, xs] / sweep * (lut_n - 1)).astype(int), 0, lut_n - 1)
        rgb[ys, xs] = lut[idx].round().astype(np.uint8)

    alpha = (keep * 255).astype(np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def _solid_ring(n, inner, sweep, color):
    return _ring(n, inner, sweep, lambda _t: color)


def _track(n, inner):
    r, _ = _polar(n)
    band = ((r >= inner) & (r <= 1.0)) * 1.0
    layer = np.zeros((n, n, 4), dtype=np.uint8)
    layer[..., 0], layer[..., 1], layer[..., 2] = TRACK_COLOR[:3]
    layer[..., 3] = (band * TRACK_COLOR[3]).astype(np.uint8)
    return Image.fromarray(layer, "RGBA")


# --- İşaret -----------------------------------------------------------------


def render_mark(n, mono=False):
    """İşareti saydam zemin üzerine n x n piksel olarak çizer."""
    s = n / U
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))

    if mono:
        img.alpha_composite(_solid_ring(n, RING_INNER_MONO, RING_SWEEP_TURN, (255, 255, 255)))
    else:
        img.alpha_composite(_track(n, RING_INNER))
        img.alpha_composite(
            _ring(n, RING_INNER, RING_SWEEP_TURN, lambda t: _lerp_stops(RING_STOPS, t))
        )

        # Noktalı çember
        dots = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        d = ImageDraw.Draw(dots)
        count = max(1, int(round(2 * math.pi * DOT_RADIUS / DOT_PERIOD)))
        rad = (DOT_SIZE / 2.0) * s
        for i in range(count):
            a = 2 * math.pi * i / count - math.pi / 2
            cx = n / 2 + DOT_RADIUS * s * math.cos(a)
            cy = n / 2 + DOT_RADIUS * s * math.sin(a)
            d.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), fill=DOT_COLOR)
        img.alpha_composite(dots)

    # Alev gövdesi
    by1 = (U - FLAME_BOTTOM) * s
    by0 = by1 - FLAME_H * s
    bx0 = (U - FLAME_W) / 2 * s
    bx1 = bx0 + FLAME_W * s
    body_box = (bx0, by0, bx1, by1)
    body_pts = _rounded_polygon(body_box, tuple((rx * s, ry * s) for rx, ry in FLAME_RADII))
    body_mask = _polygon_mask(n, body_pts)

    if mono:
        body = Image.new("RGBA", (n, n), (255, 255, 255, 255))
    else:
        body = _vertical_gradient(n, body_box, FLAME_STOPS).convert("RGBA")
    body.putalpha(body_mask)
    img.alpha_composite(body)

    if not mono:
        cy1 = by1 - CORE_BOTTOM * s
        cy0 = cy1 - CORE_H * s
        cx0 = (U - CORE_W) / 2 * s
        core_box = (cx0, cy0, cx0 + CORE_W * s, cy1)
        core_pts = _rounded_polygon(core_box, tuple((rx * s, ry * s) for rx, ry in CORE_RADII))
        core = Image.new("RGBA", (n, n), CORE_COLOR)
        core.putalpha(_polygon_mask(n, core_pts))
        img.alpha_composite(core)

    return img


def render_background(n):
    """Zemin: #0B0C14 üzerine ember radyal gradyan (adaptive background)."""
    ax = np.arange(n)
    dx = (ax[None, :] - GLOW_CENTER[0] * n) / (GLOW_RADIUS * n)
    dy = (ax[:, None] - GLOW_CENTER[1] * n) / (GLOW_RADIUS * n)
    t = np.clip(np.hypot(dx, dy), 0.0, 1.0)
    a = (1.0 - t) ** 1.6 * GLOW_ALPHA

    base = np.zeros((n, n, 3), dtype=np.float64)
    base[...] = BG
    glow = np.array(EMBER, dtype=np.float64)
    rgb = base * (1 - a[..., None]) + glow * a[..., None]
    return Image.fromarray(rgb.round().astype(np.uint8), "RGB").convert("RGBA")


def compose(size, *, mark_ratio, mono=False, background=False, tint=None):
    """İşareti `mark_ratio` oranında tuvale yerleştirir; SSx çizip küçültür."""
    n = size * SS
    canvas = render_background(n) if background else Image.new("RGBA", (n, n), (0, 0, 0, 0))

    m = max(1, int(round(n * mark_ratio)))
    mark = render_mark(m, mono=mono)
    if tint is not None:
        solid = Image.new("RGBA", mark.size, tint + (255,))
        solid.putalpha(mark.getchannel("A"))
        mark = solid

    off = (n - m) // 2
    canvas.alpha_composite(mark, (off, off))
    return canvas.resize((size, size), Image.LANCZOS)


def _write(img, *parts, rgb=False):
    path = os.path.join(*parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img.convert("RGB") if rgb else img).save(path, "PNG", optimize=True)
    print("  " + os.path.relpath(path, ROOT).replace("\\", "/"))


def main():
    print("01 · launcher (mipmap-*/ic_launcher.png)")
    for dpi, k in zip(DENSITIES, SCALES):
        size = int(48 * k)
        _write(
            compose(size, mark_ratio=LEGACY_MARK, background=True),
            RES,
            "mipmap-" + dpi,
            "ic_launcher.png",
        )

    print("02 · adaptive foreground (mipmap-*/ic_launcher_foreground.png)")
    for dpi, k in zip(DENSITIES, SCALES):
        size = int(108 * k)
        _write(
            compose(size, mark_ratio=ADAPTIVE_MARK),
            RES,
            "mipmap-" + dpi,
            "ic_launcher_foreground.png",
        )

    print("03 · monochrome (mipmap-*/ic_launcher_monochrome.png)")
    for dpi, k in zip(DENSITIES, SCALES):
        size = int(108 * k)
        _write(
            compose(size, mark_ratio=ADAPTIVE_MARK, mono=True, tint=(255, 255, 255)),
            RES,
            "mipmap-" + dpi,
            "ic_launcher_monochrome.png",
        )

    print("04 · bildirim (drawable-*/ic_notification.png)")
    for dpi, k in zip(DENSITIES, SCALES):
        size = int(24 * k)
        _write(
            compose(size, mark_ratio=NOTIFICATION_MARK, mono=True, tint=(255, 255, 255)),
            RES,
            "drawable-" + dpi,
            "ic_notification.png",
        )

    print("05 · açılış (drawable-*/ic_splash_logo.png · 128 dp)")
    for dpi, k in zip(DENSITIES, SCALES):
        size = int(128 * k)
        _write(
            compose(size, mark_ratio=1.0),
            RES,
            "drawable-" + dpi,
            "ic_splash_logo.png",
        )

    print("06 · mağaza (assets/logo/export/play_store_512.png · alfa yok)")
    _write(
        compose(512, mark_ratio=PLAY_MARK, background=True),
        ROOT,
        "assets",
        "logo",
        "export",
        "play_store_512.png",
        rgb=True,
    )


if __name__ == "__main__":
    main()
