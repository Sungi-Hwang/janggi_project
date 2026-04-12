from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(r"D:\Project\janggi-master\janggi_master")
TEST_TMP = ROOT / "test_tmp"
OUT_DIR = TEST_TMP / "play_store_feature_graphics"
FONT_PATH = ROOT / "assets" / "fonts" / "NotoSerifCJKkr-Regular.otf"

SIZE = (1024, 500)


def font(size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), size=size)


def fit_contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.copy()
    image.thumbnail(size, Image.Resampling.LANCZOS)
    return image


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def make_screen_card(path: Path, box: tuple[int, int, int, int], radius: int = 22) -> tuple[Image.Image, Image.Image]:
    width = box[2] - box[0]
    height = box[3] - box[1]
    screenshot = Image.open(path).convert("RGB")
    screenshot = fit_contain(screenshot, (width - 24, height - 24))

    card = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(card)
    draw.rounded_rectangle((0, 0, width, height), radius=radius, fill=(252, 248, 240, 255))

    inner = Image.new("RGBA", (width - 18, height - 18), (244, 240, 232, 255))
    inner_mask = rounded_mask(inner.size, radius=max(16, radius - 8))
    card.paste(inner, (9, 9), inner_mask)

    sx = (width - screenshot.width) // 2
    sy = (height - screenshot.height) // 2
    shot_mask = rounded_mask(screenshot.size, 16)
    card.paste(screenshot, (sx, sy), shot_mask)

    border = ImageDraw.Draw(card)
    border.rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, outline=(221, 204, 175, 255), width=2)
    shadow = Image.new("RGBA", (width + 14, height + 14), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((7, 7, width + 6, height + 6), radius=radius, fill=(54, 37, 22, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    return shadow, card


def draw_badge(draw: ImageDraw.ImageDraw, xywh: tuple[int, int, int, int], text: str) -> None:
    x, y, w, h = xywh
    draw.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill=(243, 229, 204), outline=(196, 160, 112), width=2)
    badge_font = font(18)
    bbox = draw.textbbox((0, 0), text, font=badge_font)
    tx = x + (w - (bbox[2] - bbox[0])) / 2
    ty = y + (h - (bbox[3] - bbox[1])) / 2 - 1
    draw.text((tx, ty), text, font=badge_font, fill=(91, 63, 35))


def draw_multiline_block(draw: ImageDraw.ImageDraw, x: int, y: int, lines: list[str], sizes: list[int], fills: list[tuple[int, int, int]]) -> int:
    cy = y
    for line, size, fill in zip(lines, sizes, fills):
        line_font = font(size)
        draw.text((x, cy), line, font=line_font, fill=fill)
        bbox = draw.textbbox((x, cy), line, font=line_font)
        cy = bbox[3] + 10
    return cy


def build_feature_graphic() -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bg_source = Image.open(TEST_TMP / "portfolio_continue.png").convert("RGB")
    bg_source = bg_source.resize((1080, int(1080 * bg_source.height / bg_source.width)), Image.Resampling.LANCZOS)
    base = bg_source.crop((120, 210, 1144, 710)).resize(SIZE, Image.Resampling.LANCZOS)
    base = base.filter(ImageFilter.GaussianBlur(14)).convert("RGBA")

    overlay = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    odraw.rectangle((0, 0, 560, 500), fill=(245, 236, 221, 238))
    odraw.rectangle((560, 0, 1024, 500), fill=(69, 49, 31, 84))
    odraw.ellipse((746, -80, 1100, 250), fill=(250, 230, 187, 48))
    odraw.ellipse((570, 280, 930, 640), fill=(255, 246, 229, 32))
    canvas = Image.alpha_composite(base, overlay)
    draw = ImageDraw.Draw(canvas)

    draw_badge(draw, (70, 58, 188, 40), "AI 훈수 · 묘수풀이")

    y = draw_multiline_block(
        draw,
        70,
        124,
        ["혼자 두고,", "풀고, 복기하는"],
        [54, 54],
        [(77, 49, 25), (77, 49, 25)],
    )
    draw.text((72, y + 8), "장기 훈련 앱", font=font(32), fill=(104, 73, 45))
    sub_font = font(22)
    draw.multiline_text(
        (72, y + 70),
        "AI 대국, 정답이 납득되는 퍼즐,\n원하는 배치에서 바로 이어하기 분석",
        font=sub_font,
        fill=(111, 83, 55),
        spacing=8,
    )

    foot_font = font(18)
    draw.text((72, 450), "장기 한수 · AI 훈수 · 묘수풀이 · 이어하기", font=foot_font, fill=(127, 95, 61))

    cards = [
        (TEST_TMP / "portfolio_puzzle_categories.png", (604, 48, 984, 250)),
        (TEST_TMP / "portfolio_continue.png", (574, 226, 836, 468)),
        (TEST_TMP / "portfolio_ai_setup.png", (822, 268, 998, 470)),
    ]

    for path, box in cards:
        shadow, card = make_screen_card(path, box)
        canvas.alpha_composite(shadow, (box[0] - 7, box[1] - 7))
        canvas.alpha_composite(card, (box[0], box[1]))

    callout = (588, 420, 1000, 470)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(callout, radius=18, fill=(248, 239, 223, 236), outline=(210, 185, 146), width=2)
    draw.text((610, 434), "퍼즐 · AI 대국 · 이어하기 분석", font=font(20), fill=(88, 60, 32))

    out_path = OUT_DIR / "feature_graphic_v4.png"
    canvas.convert("RGB").save(out_path, quality=95)
    return out_path


def build_preview_board(image_path: Path) -> Path:
    preview = Image.new("RGB", (1080, 620), (244, 239, 232))
    draw = ImageDraw.Draw(preview)
    draw.text((32, 26), "Play Store Feature Graphic", font=font(28), fill=(72, 44, 22))
    image = Image.open(image_path).convert("RGB")
    image = fit_contain(image, (1016, 496))
    x = (1080 - image.width) // 2
    y = 86
    preview.paste(image, (x, y))
    draw.rounded_rectangle((x, y, x + image.width, y + image.height), radius=18, outline=(214, 199, 175), width=2)
    draw.text((x, y + image.height + 16), image_path.name, font=font(18), fill=(109, 81, 54))
    out_path = OUT_DIR / "feature_graphic_preview_board_v4.jpg"
    preview.save(out_path, quality=92)
    return out_path


def main() -> None:
    feature = build_feature_graphic()
    preview = build_preview_board(feature)
    print(feature)
    print(preview)


if __name__ == "__main__":
    main()
