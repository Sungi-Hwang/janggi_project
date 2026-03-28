from __future__ import annotations

import math
import subprocess
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "test_tmp" / "promo_video_assets"

FFMPEG_CANDIDATES = [
    Path(
        r"C:\Users\PC\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-essentials_build\bin\ffmpeg.exe"
    ),
    Path("ffmpeg"),
]

SCREEN_SOURCES = [
    {
        "name": "home",
        "file": ASSET_DIR / "emu_home_valid.png",
        "headline": "AI 훈수 + 묘수풀이 + 이어하기 분석",
        "subline": "실제 앱 화면만으로 다시 구성한 베타 초안",
    },
    {
        "name": "puzzle",
        "file": ASSET_DIR / "emu_puzzle_board_valid.png",
        "headline": "정답이 납득되는 퍼즐 위주로 재정리",
        "subline": "에뮬레이터에서 다시 수집한 퍼즐 플레이 장면",
    },
    {
        "name": "solved",
        "file": ASSET_DIR / "emu_puzzle_solved_valid.png",
        "headline": "실제 종국이면 바로 완료 처리",
        "subline": "퍼즐 완료 팝업과 정답 흐름을 실제 화면으로 확인",
    },
    {
        "name": "progress",
        "file": ASSET_DIR / "emu_puzzle_list_solved_valid.png",
        "headline": "푼 문제는 바로 체크",
        "subline": "카테고리 진행률과 목록 반영까지 한 번에 표시",
    },
    {
        "name": "ai",
        "file": ASSET_DIR / "emu_ai_setup_valid.png",
        "headline": "혼자 장기 실력을 늘리는 훈련 앱",
        "subline": "AI 대국과 이어하기 분석 흐름까지 같은 앱 안에서",
    },
]

VIDEO_SEGMENTS = [
    {"slide": "home", "duration": 3.2},
    {"slide": "puzzle", "duration": 2.8},
    {"slide": "solved", "duration": 2.8},
    {"slide": "progress", "duration": 4.2},
    {"slide": "ai", "duration": 3.0},
]

CANVAS_SIZE = (1920, 1080)
FADE_SECONDS = 0.25

TITLE_FONT = Path(r"C:\Windows\Fonts\malgunbd.ttf")
BODY_FONT = Path(r"C:\Windows\Fonts\malgun.ttf")

TITLE_COLOR = (247, 239, 224)
ACCENT_COLOR = (236, 190, 109)
BODY_COLOR = (231, 218, 194)


def find_ffmpeg() -> str:
    for candidate in FFMPEG_CANDIDATES:
        if candidate.name == "ffmpeg":
            return str(candidate)
        if candidate.exists():
            return str(candidate)
    raise FileNotFoundError("ffmpeg executable not found")


def fit_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if draw.textlength(trial, font=font) <= max_width:
            current = trial
            continue
        if current:
            lines.append(current)
        current = word
    if current:
        lines.append(current)
    return lines


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def build_slide(source: dict[str, Path | str]) -> Path:
    image_path = Path(source["file"])
    screenshot = Image.open(image_path).convert("RGB")

    canvas = Image.new("RGB", CANVAS_SIZE, (34, 24, 19))

    bg = screenshot.copy()
    bg = bg.resize(CANVAS_SIZE, Image.Resampling.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(28))
    canvas.paste(bg, (0, 0))

    dark_overlay = Image.new("RGBA", CANVAS_SIZE, (24, 16, 13, 168))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), dark_overlay)

    gradient = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    gradient_draw = ImageDraw.Draw(gradient)
    for x in range(CANVAS_SIZE[0]):
        alpha = int(210 - (x / CANVAS_SIZE[0]) * 150)
        gradient_draw.line([(x, 0), (x, CANVAS_SIZE[1])], fill=(43, 28, 21, max(alpha, 30)))
    canvas = Image.alpha_composite(canvas, gradient)

    shot = screenshot.copy()
    shot.thumbnail((500, 930), Image.Resampling.LANCZOS)

    panel_padding = 22
    shot_size = (shot.width + panel_padding * 2, shot.height + panel_padding * 2)
    panel = Image.new("RGBA", shot_size, (26, 18, 15, 0))

    panel_draw = ImageDraw.Draw(panel)
    panel_draw.rounded_rectangle((0, 0, shot_size[0], shot_size[1]), radius=38, fill=(249, 241, 228, 248))

    shot_mask = rounded_mask(shot.size, 28)
    panel.paste(shot, (panel_padding, panel_padding), shot_mask)

    shadow = Image.new("RGBA", (shot_size[0] + 50, shot_size[1] + 50), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (25, 25, shot_size[0] + 25, shot_size[1] + 25),
        radius=42,
        fill=(0, 0, 0, 120),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))

    panel_x = 1220
    panel_y = (CANVAS_SIZE[1] - shot_size[1]) // 2
    canvas.alpha_composite(shadow, (panel_x - 18, panel_y - 6))
    canvas.alpha_composite(panel, (panel_x, panel_y))

    draw = ImageDraw.Draw(canvas)
    logo_font = ImageFont.truetype(str(TITLE_FONT), 34)
    headline_font = ImageFont.truetype(str(TITLE_FONT), 70)
    sub_font = ImageFont.truetype(str(BODY_FONT), 34)
    chip_font = ImageFont.truetype(str(TITLE_FONT), 28)

    left_x = 140
    draw.text((left_x, 124), "장기 한수", font=logo_font, fill=ACCENT_COLOR)

    headline_lines = fit_text(draw, str(source["headline"]), headline_font, 820)
    y = 270
    for line in headline_lines:
        draw.text((left_x, y), line, font=headline_font, fill=TITLE_COLOR)
        y += 94

    subline = str(source["subline"])
    sub_lines = fit_text(draw, subline, sub_font, 760)
    y += 26
    for line in sub_lines:
        draw.text((left_x, y), line, font=sub_font, fill=BODY_COLOR)
        y += 52

    chip_text = "PLAY STORE BETA"
    chip_w = int(draw.textlength(chip_text, font=chip_font) + 54)
    chip_h = 58
    chip_y = 880
    chip = Image.new("RGBA", (chip_w, chip_h), (0, 0, 0, 0))
    chip_draw = ImageDraw.Draw(chip)
    chip_draw.rounded_rectangle((0, 0, chip_w, chip_h), radius=28, fill=(92, 54, 35, 220))
    chip_draw.text((28, 12), chip_text, font=chip_font, fill=(245, 228, 198))
    canvas.alpha_composite(chip, (left_x, chip_y))

    footer_font = ImageFont.truetype(str(BODY_FONT), 26)
    draw.text((left_x, 962), "에뮬레이터 화면만으로 다시 제작한 15초 초안", font=footer_font, fill=(214, 196, 166))

    output_path = ASSET_DIR / f"store_slide_clean_{source['name']}.png"
    canvas.convert("RGB").save(output_path, quality=95)
    return output_path


def build_preview_board(slides: Iterable[Path]) -> Path:
    slides = list(slides)
    thumb_w = 780
    thumb_h = 439
    board = Image.new("RGB", (thumb_w * 2 + 60, thumb_h * 3 + 80), (28, 20, 16))
    draw = ImageDraw.Draw(board)
    draw.text((26, 18), "Store Video Draft · Emulator Only", font=ImageFont.truetype(str(TITLE_FONT), 34), fill=ACCENT_COLOR)

    positions = [(20, 80), (820, 80), (20, 539), (820, 539), (20, 998)]
    for slide_path, (x, y) in zip(slides, positions):
        slide = Image.open(slide_path).convert("RGB").resize((thumb_w, thumb_h), Image.Resampling.LANCZOS)
        board.paste(slide, (x, y))
        draw.rounded_rectangle((x, y, x + thumb_w, y + thumb_h), radius=18, outline=(111, 76, 53), width=4)

    output_path = ASSET_DIR / "store_video_preview_board.jpg"
    board.save(output_path, quality=95)
    return output_path


def write_ffmpeg_concat_manifest(slides: list[Path]) -> Path:
    manifest_path = ASSET_DIR / "store_video_inputs.txt"
    lines: list[str] = []
    for segment, slide_path in zip(VIDEO_SEGMENTS, slides):
        lines.append(f"file '{slide_path.as_posix()}'")
        lines.append(f"duration {segment['duration']}")
    lines.append(f"file '{slides[-1].as_posix()}'")
    manifest_path.write_text("\n".join(lines), encoding="utf-8")
    return manifest_path


def build_video(slides: list[Path]) -> Path:
    ffmpeg = find_ffmpeg()
    slide_inputs = []
    for slide, segment in zip(slides, VIDEO_SEGMENTS):
        slide_inputs.extend(["-loop", "1", "-t", str(segment["duration"]), "-i", str(slide)])

    offsets = []
    cumulative = 0.0
    for segment in VIDEO_SEGMENTS[:-1]:
        cumulative += segment["duration"]
        offsets.append(cumulative - FADE_SECONDS * (len(offsets) + 1))

    filter_parts = []
    for idx in range(len(VIDEO_SEGMENTS)):
        filter_parts.append(
            f"[{idx}:v]format=yuv420p,scale=1920:1080,setsar=1[v{idx}]"
        )

    current_label = "v0"
    for idx, offset in enumerate(offsets, start=1):
        next_label = f"x{idx}"
        filter_parts.append(
            f"[{current_label}][v{idx}]xfade=transition=fade:duration={FADE_SECONDS}:offset={offset:.2f}[{next_label}]"
        )
        current_label = next_label

    filter_complex = ";".join(filter_parts)
    output_path = ASSET_DIR / "store_video_draft_15s.mp4"

    command = [
        ffmpeg,
        "-y",
        *slide_inputs,
        "-filter_complex",
        filter_complex,
        "-map",
        f"[{current_label}]",
        "-r",
        "30",
        "-c:v",
        "libx264",
        "-pix_fmt",
        "yuv420p",
        str(output_path),
    ]
    subprocess.run(command, check=True)
    return output_path


def main() -> None:
    missing = [str(item["file"]) for item in SCREEN_SOURCES if not Path(item["file"]).exists()]
    if missing:
        raise FileNotFoundError(f"Missing emulator source screenshots: {missing}")

    slides = [build_slide(item) for item in SCREEN_SOURCES]
    build_preview_board(slides)
    build_video(slides)


if __name__ == "__main__":
    main()
