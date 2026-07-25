#!/usr/bin/env python3
"""Generate deterministic visual handoff previews for the Tempo/Cut duration dial.

Design-only artifact generator. It does not modify or exercise production SwiftUI.
"""
from __future__ import annotations

from math import cos, radians, sin
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent / "previews"
SCALE = 2

CHALK = "#F5F1E8"
CHALK_SUBTLE = "#ECE5D8"
CARBON = "#171714"
MUTED = "#55534D"
VERMILION = "#D13A25"
ULTRAMARINE = "#2946C6"
WHITE = "#FFFFFF"
HAIRLINE = "#D2CEC4"

# The checked preview was rendered with Google Fonts Noto Sans variable files
# staged in /tmp. SHA-256 values are recorded in docs/design-duration-dial.md.
# The script falls back to Pillow's bundled font for geometry-only regeneration.
FONT_REGULAR = "/tmp/NotoSans.ttf"
FONT_BOLD = "/tmp/NotoSans.ttf"
FONT_MONO_BOLD = "/tmp/NotoSansMono.ttf"


def u(value: float) -> int:
    return round(value * SCALE)


def font(size: float, bold: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = FONT_MONO_BOLD if mono else (FONT_BOLD if bold else FONT_REGULAR)
    if Path(path).exists():
        return ImageFont.truetype(path, u(size))
    return ImageFont.load_default(size=u(size))


def board_font(size: float) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    if Path(FONT_REGULAR).exists():
        return ImageFont.truetype(FONT_REGULAR, round(size))
    return ImageFont.load_default(size=round(size))


def draw_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    value: str,
    size: float,
    fill: str = CARBON,
    *,
    bold: bool = False,
    mono: bool = False,
    anchor: str | None = None,
    spacing: float = 4,
) -> None:
    draw.multiline_text(
        (u(xy[0]), u(xy[1])),
        value,
        font=font(size, bold=bold, mono=mono),
        fill=fill,
        anchor=anchor,
        spacing=u(spacing),
        stroke_width=1 if bold else 0,
        stroke_fill=fill,
    )


def rounded_rect(
    draw: ImageDraw.ImageDraw,
    box: tuple[float, float, float, float],
    radius: float,
    fill: str | None,
    outline: str | None = None,
    width: float = 1,
) -> None:
    draw.rounded_rectangle(
        tuple(u(v) for v in box),
        radius=u(radius),
        fill=fill,
        outline=outline,
        width=u(width),
    )


def line(draw: ImageDraw.ImageDraw, points: tuple[float, float, float, float], fill: str, width: float = 1) -> None:
    draw.line(tuple(u(v) for v in points), fill=fill, width=u(width))


def circle(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    diameter: float,
    fill: str | None,
    outline: str | None = None,
    width: float = 1,
) -> None:
    cx, cy = center
    r = diameter / 2
    draw.ellipse(
        (u(cx - r), u(cy - r), u(cx + r), u(cy + r)),
        fill=fill,
        outline=outline,
        width=u(width),
    )


def polar(center: tuple[float, float], radius: float, degrees: float) -> tuple[float, float]:
    angle = radians(degrees)
    return center[0] + cos(angle) * radius, center[1] + sin(angle) * radius


def draw_arc_rounded(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    start: float,
    end: float,
    color: str,
    width: float,
) -> None:
    bounds = (
        u(center[0] - radius),
        u(center[1] - radius),
        u(center[0] + radius),
        u(center[1] + radius),
    )
    draw.arc(bounds, start=start, end=end, fill=color, width=u(width))
    for angle in (start, end):
        px, py = polar(center, radius, angle)
        circle(draw, (px, py), width, color)


def draw_step_button(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    symbol: str,
    enabled: bool = True,
    size: float = 52,
) -> None:
    circle(draw, center, size, CHALK, CARBON if enabled else HAIRLINE, 1.5)
    draw_text(
        draw,
        center,
        symbol,
        23,
        CARBON if enabled else MUTED,
        bold=True,
        anchor="mm",
    )


def draw_dial(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    diameter: float,
    value: int,
    *,
    center_size: float = 56,
    button_mode: str = "below",
    increase_contrast: bool = False,
) -> None:
    radius = diameter / 2 - 16
    stroke = 10 if diameter >= 200 else 9
    start, end = 135.0, 405.0
    fraction = {5: 0.0, 10: 0.5, 15: 1.0}[value]
    current = start + (end - start) * fraction

    base_color = "#A7A39A" if increase_contrast else "#D5D0C6"
    progress_color = CARBON if increase_contrast else VERMILION
    draw_arc_rounded(draw, center, radius, start, end, base_color, stroke)
    if fraction > 0:
        draw_arc_rounded(draw, center, radius, start, current, progress_color, stroke)

    for index, angle in enumerate((start, 270.0, end)):
        p1 = polar(center, radius - stroke / 2 - 7, angle)
        p2 = polar(center, radius + stroke / 2 + 7, angle)
        tick_color = progress_color if index <= {5: 0, 10: 1, 15: 2}[value] else CARBON
        line(draw, (p1[0], p1[1], p2[0], p2[1]), tick_color, 2.5 if increase_contrast else 2)

    handle = polar(center, radius, current)
    circle(draw, handle, 31 if increase_contrast else 30, CHALK)
    circle(draw, handle, 24, CARBON, CARBON, 1)

    draw_text(draw, (center[0], center[1] - 9), str(value), center_size, CARBON, bold=True, anchor="mm")
    draw_text(draw, (center[0], center[1] + center_size * 0.46), "МИНУТ", 12 if center_size < 65 else 13, MUTED, bold=True, anchor="mm")

    if button_mode == "below":
        button_y = center[1] + diameter / 2 + 11
        draw_step_button(draw, (center[0] - 62, button_y), "−", value > 5, 52 if diameter >= 200 else 48)
        draw_step_button(draw, (center[0] + 62, button_y), "+", value < 15, 52 if diameter >= 200 else 48)
    else:
        rail_x = center[0] + diameter / 2 + 46
        draw_step_button(draw, (rail_x, center[1] - 33), "+", value < 15, 48)
        draw_step_button(draw, (rail_x, center[1] + 33), "−", value > 5, 48)


def draw_status(draw: ImageDraw.ImageDraw, width: float) -> None:
    draw_text(draw, (20, 17), "9:41", 14, CARBON, bold=True)
    draw_text(draw, (width - 40, 17), "5G", 13, CARBON, bold=True, anchor="ra")
    rounded_rect(draw, (width - 34, 20, width - 20, 27), 2, None, CARBON, 1.5)
    rounded_rect(draw, (width - 32, 22, width - 23, 25), 1, CARBON)


def draw_header(draw: ImageDraw.ImageDraw, x: float, y: float, title_size: float, body_size: float) -> float:
    draw_text(draw, (x, y), "ЛОКАЛЬНАЯ ТРЕНИРОВКА", 10, VERMILION, bold=True)
    draw_text(draw, (x, y + 24), "Соберите\nсвой темп", title_size, CARBON, bold=True, spacing=-2)
    title_height = title_size * 1.8
    draw_text(
        draw,
        (x, y + 36 + title_height),
        "Выберите длительность и нагрузку.\nПлан будет готов без регистрации.",
        body_size,
        MUTED,
        spacing=4,
    )
    return y + 36 + title_height + body_size * 2.5


def section_header(draw: ImageDraw.ImageDraw, x: float, y: float, width: float, value: str, ax: bool = False) -> float:
    draw_text(draw, (x, y), "Сколько времени?", 18 if not ax else 21, CARBON, bold=True)
    if ax:
        draw_text(draw, (x, y + 28), value, 16, MUTED, bold=True)
        return y + 54
    draw_text(draw, (x + width, y + 4), value, 13, MUTED, bold=True, anchor="ra")
    return y + 30


def draw_zone_grid(draw: ImageDraw.ImageDraw, x: float, y: float, width: float, compact: bool = False) -> None:
    draw_text(draw, (x, y), "Куда нагрузка?", 18 if compact else 19, CARBON, bold=True)
    draw_text(draw, (x + width, y + 4), "Можно несколько", 11 if compact else 12, MUTED, bold=True, anchor="ra")
    gap = 8
    cell_w = (width - gap) / 2
    cell_h = 52 if compact else 58
    labels = ["Верхний пресс", "Нижний пресс", "Косые мышцы", "Весь пресс"]
    for i, label in enumerate(labels):
        row, col = divmod(i, 2)
        left = x + col * (cell_w + gap)
        top = y + 36 + row * (cell_h + gap)
        selected = i == 3
        rounded_rect(draw, (left, top, left + cell_w, top + cell_h), 12, ULTRAMARINE if selected else CHALK, ULTRAMARINE if selected else HAIRLINE, 1)
        draw_text(draw, (left + 12, top + (15 if not selected else 9)), label, 12 if compact else 13, WHITE if selected else CARBON, bold=True)
        if selected:
            draw_text(draw, (left + 12, top + 31), "ВЫБРАНО", 8.5, "#D9DFFF", bold=True)


def draw_cta(draw: ImageDraw.ImageDraw, x: float, y: float, width: float, compact: bool = False) -> None:
    height = 54 if compact else 58
    rounded_rect(draw, (x, y, x + width, y + height), 20, CARBON)
    draw_text(draw, (x + 16, y + height / 2), "Собрать тренировку", 14 if compact else 15, WHITE, bold=True, anchor="lm")
    arrow_x = x + width - 21
    arrow_y = y + height / 2
    line(draw, (arrow_x - 10, arrow_y, arrow_x + 3, arrow_y), WHITE, 2)
    line(draw, (arrow_x - 2, arrow_y - 5, arrow_x + 3, arrow_y), WHITE, 2)
    line(draw, (arrow_x - 2, arrow_y + 5, arrow_x + 3, arrow_y), WHITE, 2)


def portrait(width: int, height: int, value: int, *, ax: bool = False, compact: bool = False) -> Image.Image:
    image = Image.new("RGB", (u(width), u(height)), CHALK)
    draw = ImageDraw.Draw(image)
    draw_status(draw, width)
    inset = 20

    if compact:
        draw_header(draw, inset, 48, 32, 12.5)
        section_y = 194
        dial_diameter = 184
        dial_center_y = 318
        zone_y = 466
        cta_y = height - 68
    elif ax:
        draw_header(draw, inset, 58, 38, 16)
        section_y = 278
        dial_diameter = 184
        dial_center_y = 422
        zone_y = 585
        cta_y = height - 78
    else:
        draw_header(draw, inset, 64, 40, 15)
        section_y = 257
        dial_diameter = 216
        dial_center_y = 395
        zone_y = 568
        cta_y = height - 78

    dial_top = section_header(draw, inset, section_y, width - 2 * inset, f"{value} минут", ax=ax)
    if ax:
        dial_center_y = max(dial_center_y, dial_top + dial_diameter / 2)
    draw_dial(
        draw,
        (width / 2, dial_center_y),
        dial_diameter,
        value,
        center_size=70 if ax else (50 if compact else 56),
        increase_contrast=ax,
    )
    draw_zone_grid(draw, inset, zone_y, width - 2 * inset, compact=compact or ax)
    draw_cta(draw, inset, cta_y, width - 2 * inset, compact=compact)
    line(draw, (width / 2 - 62, height - 10, width / 2 + 62, height - 10), CARBON, 4)
    return image


def landscape() -> Image.Image:
    width, height = 852, 393
    image = Image.new("RGB", (u(width), u(height)), CHALK)
    draw = ImageDraw.Draw(image)
    draw_status(draw, width)
    draw_text(draw, (32, 55), "ЛОКАЛЬНАЯ ТРЕНИРОВКА", 9, VERMILION, bold=True)
    draw_text(draw, (32, 78), "Соберите\nсвой темп", 34, CARBON, bold=True, spacing=-2)
    draw_text(draw, (32, 157), "Выберите длительность и нагрузку.\nПлан будет готов без регистрации.", 12, MUTED)
    draw_zone_grid(draw, 32, 222, 315, compact=True)

    section_header(draw, 390, 54, 398, "15 минут")
    draw_dial(draw, (500, 207), 168, 15, center_size=46, button_mode="side")
    draw_cta(draw, 620, 314, 200, compact=True)
    line(draw, (366, 46, 366, 356), HAIRLINE, 1)
    line(draw, (width - 82, height - 9, width - 20, height - 9), CARBON, 4)
    return image


def make_board(images: list[tuple[str, Image.Image]]) -> Image.Image:
    board = Image.new("RGB", (1900, 1450), "#171714")
    draw = ImageDraw.Draw(board)
    draw.text((70, 48), "TEMPO / CUT · DURATION DIAL", font=board_font(36), fill=WHITE, stroke_width=1, stroke_fill=WHITE)
    draw.text((70, 96), "5—15 min · step 5 · open 270° arc · drag/tap + explicit −/+", font=board_font(23), fill="#C9C5BC")
    slots = [(70, 170, 600, 1220), (700, 170, 1120, 1220), (1220, 170, 1780, 790), (1220, 850, 1780, 1320)]
    for (label, image), (x0, y0, x1, y1) in zip(images, slots):
        max_w, max_h = x1 - x0, y1 - y0 - 55
        ratio = min(max_w / image.width, max_h / image.height)
        resized = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)
        px = x0 + (max_w - resized.width) // 2
        py = y0 + 45
        board.paste(resized, (px, py))
        draw.text((x0, y0), label, font=board_font(22), fill="#F5F1E8", stroke_width=1, stroke_fill="#F5F1E8")
    draw.text((70, 1388), "Repository handoff · Figma destination unavailable · verify real SwiftUI pixels and VoiceOver after implementation", font=board_font(20), fill="#A9A59D")
    return board


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    standard = portrait(393, 852, 10)
    compact = portrait(320, 700, 5, compact=True)
    ax3 = portrait(393, 852, 10, ax=True)
    wide = landscape()
    outputs = {
        "duration-dial-393x852.png": standard,
        "duration-dial-320x700.png": compact,
        "duration-dial-393x852-ax3.png": ax3,
        "duration-dial-852x393-landscape.png": wide,
        "duration-dial-spec.png": make_board([
            ("STANDARD · 393×852 · 10 MIN", standard),
            ("COMPACT · 320×700 · MIN 5", compact),
            ("AX3 / HIGH CONTRAST · 393×852", ax3),
            ("LANDSCAPE · 852×393 · MAX 15", wide),
        ]),
    }
    for name, image in outputs.items():
        path = OUT / name
        image.save(path, optimize=True)
        print(f"{path}: {image.width}×{image.height}, {path.stat().st_size} bytes")


if __name__ == "__main__":
    main()
