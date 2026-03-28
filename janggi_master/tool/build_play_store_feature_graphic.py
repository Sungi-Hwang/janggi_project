from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(r"D:\Project\janggi-master\janggi_master")
PROMO_DIR = ROOT / "test_tmp" / "promo_video_assets"
OUT_DIR = ROOT / "test_tmp" / "play_store_feature_graphics"
FONT_PATH = ROOT / "assets" / "fonts" / "NotoSerifCJKkr-Regular.otf"

SIZE = (1024, 500)


def load_font(size: int):
    return ImageFont.truetype(str(FONT_PATH), size=size)


def fit_crop(img: Image.Image, target_size):
    tw, th = target_size
    w, h = img.size
    scale = max(tw / w, th / h)
    resized = img.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
    rw, rh = resized.size
    left = max(0, (rw - tw) // 2)
    top = max(0, (rh - th) // 2)
    return resized.crop((left, top, left + tw, top + th))


def draw_badge(draw, xy, text, font, fill, outline):
    x, y, w, h = xy
    draw.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill=fill, outline=outline, width=2)
    bbox = draw.textbbox((0, 0), text, font=font)
    tx = x + (w - (bbox[2] - bbox[0])) / 2
    ty = y + (h - (bbox[3] - bbox[1])) / 2 - 2
    draw.text((tx, ty), text, font=font, fill=(68, 45, 24))


def add_shadowed_text(draw, pos, text, font, fill, shadow=(255, 248, 236), offset=(2, 2), spacing=6):
    x, y = pos
    sx, sy = offset
    draw.multiline_text((x + sx, y + sy), text, font=font, fill=shadow, spacing=spacing)
    draw.multiline_text((x, y), text, font=font, fill=fill, spacing=spacing)


def card_crop(path: Path, box, radius=28, source_crop=None):
    src = Image.open(path).convert("RGB")
    if source_crop:
        src = src.crop(source_crop)
    crop = fit_crop(src, (box[2] - box[0], box[3] - box[1]))
    mask = Image.new("L", crop.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, crop.size[0], crop.size[1]), radius=radius, fill=255)
    return crop, mask


def compose_variant(
    name: str,
    headline: str,
    subline: str,
    badge_text: str,
    board_path: Path,
    board_source_crop,
    progress_path: Path,
    progress_source_crop,
    accent=(188, 150, 93),
):
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    base_bg = Image.open(board_path).convert("RGB")
    if board_source_crop:
        base_bg = base_bg.crop(board_source_crop)
    base = fit_crop(base_bg, SIZE)
    base = base.filter(ImageFilter.GaussianBlur(8))

    overlay = Image.new("RGBA", SIZE, (248, 239, 223, 0))
    odraw = ImageDraw.Draw(overlay)
    odraw.rectangle((0, 0, 590, 500), fill=(245, 236, 219, 236))
    odraw.rectangle((590, 0, 1024, 500), fill=(58, 42, 30, 88))
    base = Image.alpha_composite(base.convert("RGBA"), overlay)

    draw = ImageDraw.Draw(base)
    serif_big = load_font(50)
    serif_mid = load_font(24)
    serif_small = load_font(18)
    serif_badge = load_font(20)

    draw_badge(draw, (72, 64, 186, 42), badge_text, serif_badge, fill=(242, 225, 193), outline=accent)

    add_shadowed_text(
        draw,
        (72, 130),
        headline,
        font=serif_big,
        fill=(76, 49, 26),
        shadow=(255, 248, 236),
        spacing=10,
    )
    draw.multiline_text((74, 272), subline, font=serif_mid, fill=(100, 70, 43), spacing=8)

    # right-side board card
    board_box = (604, 50, 974, 338)
    crop, mask = card_crop(board_path, board_box, radius=26, source_crop=board_source_crop)
    shadow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((board_box[0] + 8, board_box[1] + 10, board_box[2] + 8, board_box[3] + 10), radius=28, fill=(37, 23, 12, 70))
    base = Image.alpha_composite(base, shadow)
    base.paste(crop, (board_box[0], board_box[1]), mask)
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(board_box, radius=26, outline=(228, 211, 180), width=3)

    # progress list card
    list_box = (650, 346, 972, 458)
    list_crop, list_mask = card_crop(progress_path, list_box, radius=22, source_crop=progress_source_crop)
    shadow2 = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    sdraw2 = ImageDraw.Draw(shadow2)
    sdraw2.rounded_rectangle((list_box[0] + 6, list_box[1] + 8, list_box[2] + 6, list_box[3] + 8), radius=24, fill=(37, 23, 12, 56))
    base = Image.alpha_composite(base, shadow2)
    base.paste(list_crop, (list_box[0], list_box[1]), list_mask)
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(list_box, radius=22, outline=(228, 211, 180), width=2)

    cue_box = (592, 390, 954, 446)
    draw.rounded_rectangle(cue_box, radius=18, fill=(248, 239, 223, 226), outline=(208, 184, 142), width=2)
    cue_title_font = load_font(16)
    cue_body_font = load_font(21)
    draw.text((612, 401), "훈련 흐름", font=cue_title_font, fill=(124, 92, 59))
    draw.text((612, 419), "정답이 납득되는 퍼즐 · 클리어 표시", font=cue_body_font, fill=(82, 58, 34))

    # footer brand line
    draw.text((74, 386), "장기 한수", font=load_font(28), fill=(67, 42, 22))
    draw.text((74, 422), "AI 훈수 · 묘수풀이 · 복기용 이어하기", font=serif_small, fill=(124, 92, 59))

    out_path = OUT_DIR / f"{name}.png"
    base.convert("RGB").save(out_path, quality=95)
    return out_path


def build_board(paths):
    images = [Image.open(p).convert("RGB") for p in paths]
    w, h = 1024, 1100
    board = Image.new("RGB", (w, h), (245, 238, 226))
    draw = ImageDraw.Draw(board)
    draw.text((36, 28), "Play Store Feature Graphic Drafts", font=load_font(28), fill=(70, 45, 25))

    y = 88
    for path in paths:
        img = Image.open(path).convert("RGB")
        preview = fit_crop(img, (920, 449))
        board.paste(preview, (52, y))
        draw.rounded_rectangle((52, y, 972, y + 449), radius=18, outline=(210, 191, 158), width=2)
        draw.text((56, y + 460), path.name, font=load_font(18), fill=(110, 82, 54))
        y += 520

    out_path = OUT_DIR / "feature_graphic_preview_board.jpg"
    board.save(out_path, quality=92)
    return out_path


def main():
    menu = PROMO_DIR / "main_menu4.png"
    board = PROMO_DIR / "after_close.png"
    puzzle_list = PROMO_DIR / "puzzle_list_fresh.png"

    outputs = [
        compose_variant(
            name="feature_graphic_v1",
            headline="AI 훈수 +\n묘수풀이",
            subline="이어하기 분석까지\n한 앱에서",
            badge_text="장기 훈련 앱",
            board_path=board,
            board_source_crop=(94, 350, 986, 1420),
            progress_path=puzzle_list,
            progress_source_crop=(24, 86, 1058, 650),
            accent=(188, 150, 93),
        ),
        compose_variant(
            name="feature_graphic_v2",
            headline="정답이 납득되는\n장기 묘수풀이",
            subline="AI와 대국하고,\n원하는 배치에서 바로 복기",
            badge_text="퍼즐 + 분석",
            board_path=menu,
            board_source_crop=(0, 160, 1080, 1920),
            progress_path=puzzle_list,
            progress_source_crop=(24, 86, 1058, 650),
            accent=(162, 116, 74),
        ),
    ]
    build_board(outputs)
    for out in outputs:
        print(out)


if __name__ == "__main__":
    main()
