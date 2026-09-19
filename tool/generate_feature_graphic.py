"""Play Console feature graphic'ini (1024x500) uretir.

Kompozisyon `design/FocusSayac ASO Paketi.dc.html` §6'da tarif edilmis:
koyu lacivert zemin, sag ustten sol alta soluklasan mor isima, sol ucte bir
dev gun sayisi, ortada telefon cercevesi, sag altta uygulama adi.

Telefonun icindeki goruntu **uydurma degil**: `docs/play/store/02_odak.png`,
yani magazaya yuklenecek ikinci ekran goruntusunun ta kendisi. Elle cizilmis
bir taklit zamanla uygulamadan ayrisirdi; ayni dosyayi kullanmak banner ile
ekran goruntusunu tek kaynaga bagliyor.

Yazi tipleri uygulamanin kendi dosyalarindan geliyor (`assets/fonts`). Bunlar
subset edilmis olabilir ve eksik glifte PIL sessizce bos kutu cizer; bu yuzden
her dizge cizilmeden once `cmap`e karsi dogrulaniyor (bkz. madde 10'un font
tuzagi).

Calistirma:
    python tool/generate_feature_graphic.py
"""

from __future__ import annotations

import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from fontTools.ttLib import TTFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

W, H = 1024, 500
SS = 3  # superorneklem: her sey SSx cizilip tek seferde kucultuluyor

BG = (0x16, 0x18, 0x26)  # ASO §6 zemin
GLOW = (0x42, 0x3A, 0x6A)  # ASO §6 mor isima
DAY_COLOR = (0xF2, 0xF0, 0xFF)
LABEL_COLOR = (0x8F, 0x8C, 0xAB)
NAME_COLOR = (0xF2, 0xF0, 0xFF)
RULE_COLOR = (0x6C, 0x63, 0xA8)
PHONE_BODY = (0x0B, 0x0C, 0x14)  # AppColors.dark().bg
PHONE_EDGE = (0x3A, 0x37, 0x57)

SAFE = 64  # ASO §6: kenarlarda 64 px guvenli bosluk
TEXT_FLOOR = int(H * 0.80)  # ASO §6: alt %20'ye metin konmaz

# ASO §6 ornek rakami. Uygulamanin o anki geri sayimi degil — banner statik,
# sayac her gun degisiyor; iki numara bilerek birbirine baglanmadi.
DAYS = "132"
DAYS_LABEL = "GÜN KALDI"
APP_NAME = "FocusSayaç"

SCREENSHOT = os.path.join(ROOT, "docs", "play", "store", "02_odak.png")
OUT = os.path.join(ROOT, "docs", "play", "store", "feature_graphic_1024x500.png")

FONT_DISPLAY_BOLD = os.path.join(ROOT, "assets", "fonts", "SpaceGrotesk-700.ttf")
FONT_DISPLAY = os.path.join(ROOT, "assets", "fonts", "SpaceGrotesk-600.ttf")
FONT_BODY = os.path.join(ROOT, "assets", "fonts", "Inter-500.ttf")


def assert_glyphs(font_path: str, text: str) -> None:
    """Eksik glif PIL'de sessizce .notdef ciziyor; once cmap'e soruyoruz."""
    cmap = TTFont(font_path, fontNumber=0).getBestCmap()
    missing = sorted({ch for ch in text if ord(ch) not in cmap})
    if missing:
        raise SystemExit(f"{os.path.basename(font_path)}: eksik glif {missing!r} ({text!r})")


def load(font_path: str, size_px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(font_path, size_px * SS)


def draw_tracked(draw: ImageDraw.ImageDraw, xy, text, font, fill, tracking_px: int) -> None:
    """PIL'de harf araligi yok; ASO'nun seyreltilmis etiketi icin elle."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + tracking_px * SS


def radial_glow(size: tuple[int, int], center: tuple[float, float], radius: float) -> Image.Image:
    """Merkezden disa dogru sonen tek renkli isima (alfa maskesi)."""
    w, h = size
    ys, xs = np.mgrid[0:h, 0:w]
    dist = np.hypot(xs - center[0], ys - center[1]) / radius
    alpha = np.clip(1.0 - dist, 0.0, 1.0) ** 2
    layer = np.zeros((h, w, 4), dtype=np.uint8)
    layer[..., 0], layer[..., 1], layer[..., 2] = GLOW
    layer[..., 3] = (alpha * 255).astype(np.uint8)
    return Image.fromarray(layer, "RGBA")


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def main() -> None:
    canvas = Image.new("RGBA", (W * SS, H * SS), BG + (255,))

    # ASO §6: "sag ustten sol alta dogru soluklasan mor bir isima".
    canvas.alpha_composite(radial_glow((W * SS, H * SS), (0.80 * W * SS, 0.02 * H * SS), 0.62 * W * SS))

    draw = ImageDraw.Draw(canvas)

    # --- Sol uc: dev gun sayisi -------------------------------------------
    assert_glyphs(FONT_DISPLAY_BOLD, DAYS)
    assert_glyphs(FONT_BODY, DAYS_LABEL)
    days_font = load(FONT_DISPLAY_BOLD, 172)
    label_font = load(FONT_BODY, 22)
    # Rakamin *murekkep* ustu guvenli bosluga oturmali: yazi tipinin ascender'i
    # cizilen rakamdan cok daha yukarida, "ust = taban - punto" hesabi tasardi.
    ink_top, ink_bottom = draw.textbbox((0, 0), DAYS, font=days_font, anchor="ls")[1::2]
    days_baseline = 96 * SS - ink_top
    draw.text((SAFE * SS, days_baseline), DAYS, font=days_font, fill=DAY_COLOR, anchor="ls")
    draw_tracked(
        draw,
        (SAFE * SS, days_baseline + ink_bottom + 28 * SS),
        DAYS_LABEL,
        label_font,
        LABEL_COLOR,
        tracking_px=6,
    )

    # --- Orta: telefon cercevesi, icinde gercek ekran goruntusu ------------
    # Cerceve de guvenli bosluga sigiyor (64..436): magaza banner'i kirparsa
    # once kenarlardan kirpiyor, telefonun kosesi kesilmis gorunmesin.
    phone_w, phone_h = 210, 372
    phone_x, phone_y = 455, SAFE
    bezel = 8
    shot = Image.open(SCREENSHOT).convert("RGB")
    inner = ((phone_w - 2 * bezel) * SS, (phone_h - 2 * bezel) * SS)
    shot = shot.resize(inner, Image.LANCZOS)
    shot.putalpha(rounded_mask(inner, 22 * SS))

    draw.rounded_rectangle(
        (phone_x * SS, phone_y * SS, (phone_x + phone_w) * SS, (phone_y + phone_h) * SS),
        radius=30 * SS,
        fill=PHONE_BODY + (255,),
        outline=PHONE_EDGE + (255,),
        width=2 * SS,
    )
    canvas.alpha_composite(shot, ((phone_x + bezel) * SS, (phone_y + bezel) * SS))

    # --- Sag alt: ince cizgi + uygulama adi --------------------------------
    assert_glyphs(FONT_DISPLAY, APP_NAME)
    name_font = load(FONT_DISPLAY, 44)
    right = (W - SAFE) * SS
    draw.rectangle((right - 132 * SS, 302 * SS, right, 303 * SS + SS), fill=RULE_COLOR + (255,))
    draw.text((right, 336 * SS), APP_NAME, font=name_font, fill=NAME_COLOR, anchor="ra")

    name_bottom = 336 + name_font.getbbox(APP_NAME)[3] / SS
    if name_bottom > TEXT_FLOOR:
        raise SystemExit(f"uygulama adi alt %20'ye tasiyor: {name_bottom:.0f} > {TEXT_FLOOR}")

    canvas.resize((W, H), Image.LANCZOS).convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"{os.path.relpath(OUT, ROOT)} · {W}x{H} · metin tabani {name_bottom:.0f}px (sinir {TEXT_FLOOR})")


if __name__ == "__main__":
    main()
