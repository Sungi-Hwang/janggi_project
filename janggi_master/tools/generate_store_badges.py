from pathlib import Path
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "marketing" / "store_badges"
OUT_DIR.mkdir(parents=True, exist_ok=True)

FONT_REG = Path(r"C:\Windows\Fonts\malgun.ttf")
FONT_BOLD = Path(r"C:\Windows\Fonts\malgunbd.ttf")


def load_font(path: Path, size: int):
    try:
        return ImageFont.truetype(str(path), size)
    except Exception:
        return ImageFont.load_default()


def add_vertical_gradients(base: Image.Image) -> None:
    w, h = base.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = overlay.load()
    for y in range(h):
        top = max(0, 190 - y) / 190.0
        bottom = max(0, y - (h - 300)) / 300.0
        alpha = int(max(top * 170, bottom * 180))
        for x in range(w):
            px[x, y] = (0, 0, 0, alpha)
    base.alpha_composite(overlay)


def rounded_box(draw: ImageDraw.ImageDraw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def make_badge_image(src_name: str, out_name: str, badge: str, title: str, subtitle: str, chips, color):
    src = ROOT / src_name
    img = Image.open(src).convert("RGBA")
    w, h = img.size

    add_vertical_gradients(img)
    draw = ImageDraw.Draw(img)

    font_badge = load_font(FONT_BOLD, 46)
    font_title = load_font(FONT_BOLD, 56)
    font_sub = load_font(FONT_REG, 35)
    font_chip = load_font(FONT_BOLD, 30)

    # Top badge
    badge_x1, badge_y1 = 44, 44
    badge_x2, badge_y2 = w - 44, 170
    rounded_box(
        draw,
        (badge_x1, badge_y1, badge_x2, badge_y2),
        radius=36,
        fill=(22, 22, 26, 200),
        outline=(255, 255, 255, 150),
        width=3,
    )
    rounded_box(
        draw,
        (badge_x1 + 18, badge_y1 + 20, badge_x1 + 290, badge_y2 - 20),
        radius=24,
        fill=color + (255,),
    )
    draw.text((badge_x1 + 48, badge_y1 + 49), badge, font=font_badge, fill=(255, 255, 255, 255))

    draw.text((badge_x1 + 320, badge_y1 + 28), title, font=font_title, fill=(255, 255, 255, 255))
    draw.text((badge_x1 + 320, badge_y1 + 96), subtitle, font=font_sub, fill=(220, 230, 240, 255))

    # Bottom chips
    y = h - 300
    x = 44
    for text in chips:
        tw, th = draw.textbbox((0, 0), text, font=font_chip)[2:]
        chip_w = tw + 56
        chip_h = 66
        rounded_box(
            draw,
            (x, y, x + chip_w, y + chip_h),
            radius=28,
            fill=(20, 20, 24, 195),
            outline=(255, 255, 255, 120),
            width=2,
        )
        draw.text((x + 28, y + 15), text, font=font_chip, fill=(250, 250, 250, 255))
        x += chip_w + 18
        if x + chip_w > w - 44:
            x = 44
            y += chip_h + 14

    img.save(OUT_DIR / out_name)


def main():
    items = [
        {
            "src": "jm_verify_ai_hint_fixed.png",
            "out": "01_ai_duel.png",
            "badge": "AI",
            "title": "AI 대전",
            "subtitle": "Stockfish 기반 오프라인 대국",
            "chips": ["실시간 힌트", "무르기", "수순 분석"],
            "color": (0, 200, 255),
        },
        {
            "src": "jm_friend_open.png",
            "out": "02_offline_local.png",
            "badge": "LOCAL",
            "title": "오프라인 친구 대전",
            "subtitle": "네트워크 없이 바로 2인 대국",
            "chips": ["완전 오프라인", "기물 손실 표시", "즉시 재시작"],
            "color": (0, 220, 140),
        },
        {
            "src": "device_screen3.png",
            "out": "03_puzzle_solve.png",
            "badge": "PUZZLE",
            "title": "기보 퍼즐 풀이",
            "subtitle": "1수·2수·3수 외통 단계별 도전",
            "chips": ["난이도 분류", "즉시 플레이", "힌트 제공"],
            "color": (220, 90, 255),
        },
        {
            "src": "device_screen6.png",
            "out": "04_puzzle_share.png",
            "badge": "SHARE",
            "title": "퍼즐 공유",
            "subtitle": "텍스트 코드로 내보내기/불러오기",
            "chips": ["복사/붙여넣기", "간편 공유", "재현 가능한 수순"],
            "color": (255, 135, 45),
        },
        {
            "src": "jm_cold_start.png",
            "out": "05_continue_mode.png",
            "badge": "CONTINUE",
            "title": "이어하기",
            "subtitle": "특정 배치에서 바로 분석 대국",
            "chips": ["중간 배치 시작", "분석용 활용", "AI 대응"],
            "color": (255, 75, 75),
        },
        {
            "src": "jm_ai_open2.png",
            "out": "06_stockfish_tuning.png",
            "badge": "TUNING",
            "title": "Stockfish 난이도 조절",
            "subtitle": "Depth·생각시간 기반 세밀 조정",
            "chips": ["AI 깊이 설정", "사고시간 제어", "실력별 맞춤"],
            "color": (255, 190, 0),
        },
    ]

    for item in items:
        make_badge_image(
            src_name=item["src"],
            out_name=item["out"],
            badge=item["badge"],
            title=item["title"],
            subtitle=item["subtitle"],
            chips=item["chips"],
            color=item["color"],
        )
        print(f"generated: {OUT_DIR / item['out']}")


if __name__ == "__main__":
    main()
