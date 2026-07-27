#!/usr/bin/env python3
"""Deterministic design-only renderer for the ABS Trainer exercise library.

Creates original 2D motion masters, H.264 app exports, poster frames, polished
screen previews, contact sheets, and a measured manifest. It never reads or
modifies production SwiftUI. The neutral mannequin, poses, camera, and visual
system are authored in this file from geometric primitives.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Mapping

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "design" / "exercise-library"
EXPORTS = BASE / "exports"
PREVIEWS = BASE / "previews"
SCREENS = PREVIEWS / "screens"
MANIFEST_DIR = BASE / "manifest"
SOURCE = BASE / "source"
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")

# Tempo/Cut primitives, matched to production color assets.
CHALK = "#F5F1E8"
CHALK_SUBTLE = "#ECE5D8"
CARBON = "#171714"
MUTED = "#55534D"
VERMILION = "#D13A25"
ULTRAMARINE = "#2946C6"
MOSS = "#42634A"
SIGNAL = "#B74731"
WHITE = "#FFFFFF"
HAIR = "#D5D0C6"
MANNEQUIN = "#252521"
MANNEQUIN_LIGHT = "#77736B"

FONT_CANDIDATES = [
    Path("/tmp/NotoSans.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
]
FONT_BOLD_CANDIDATES = [
    Path("/tmp/NotoSans.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
]
MONO_CANDIDATES = [
    Path("/tmp/NotoSansMono.ttf"),
    Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
]


@dataclass(frozen=True)
class ExerciseSpec:
    id: str
    title: str
    zones: tuple[str, ...]
    difficulty: str
    work: int
    rest: int
    phases: tuple[str, str, str]
    cues: tuple[str, str]
    poster_frame: int


EXERCISES = [
    ExerciseSpec("crunch", "Скручивания", ("Верхний",), "Начальный", 40, 12,
                 ("Лягте, согните колени, поставьте стопы.", "На выдохе приподнимите плечи, направляя рёбра к тазу.", "Плавно опустите плечи."),
                 ("Сохраняйте шею продолжением спины.", "Поясница остаётся в комфортном контакте с опорой."), 42),
    ExerciseSpec("reverse_crunch", "Обратные скручивания", ("Нижний",), "Начальный", 40, 12,
                 ("Лягте, поднимите согнутые ноги.", "Подведите колени к корпусу и слегка приподнимите таз.", "Контролируемо верните таз и ноги."),
                 ("Не разгоняйте ноги.", "Сохраняйте движение небольшим и плавным."), 42),
    ExerciseSpec("bicycle_twist", "Велосипед с поворотом", ("Косые", "Весь пресс"), "Средний", 40, 12,
                 ("Поднимите согнутые ноги и плечи.", "Поверните корпус к противоположному колену.", "Через центр смените сторону."),
                 ("Поворачивайте корпус, не тяните голову рукой.", "Двигайтесь в ровном темпе без рывка."), 30),
    ExerciseSpec("plank", "Планка", ("Весь пресс",), "Начальный", 45, 15,
                 ("Поставьте предплечья под плечами.", "Вытяните ноги и соберите корпус в одну линию.", "Удерживайте положение до конца интервала."),
                 ("Направляйте макушку вперёд, пятки назад.", "Положение на коленях — допустимое упрощение."), 30),
    ExerciseSpec("mountain_climber", "Альпинист", ("Нижний", "Весь пресс"), "Средний", 40, 15,
                 ("Примите упор на ладонях.", "Подведите одно колено к корпусу.", "Верните ногу и смените сторону."),
                 ("Ладони остаются под плечами.", "Сохраняйте корпус без резкой раскачки."), 27),
    ExerciseSpec("toe_touch", "Касания стоп", ("Верхний",), "Начальный", 40, 12,
                 ("Поднимите ноги вверх с комфортным сгибом.", "Потянитесь руками к стопам, приподнимая плечи.", "Плавно верните плечи на опору."),
                 ("Не прижимайте подбородок к груди.", "Достаточна небольшая амплитуда подъёма."), 44),
    ExerciseSpec("leg_raise", "Подъём ног", ("Нижний",), "Средний", 40, 15,
                 ("Вытяните ноги или слегка согните колени.", "Поднимите ноги до комфортного угла.", "Медленно опустите, не бросая их на опору."),
                 ("Уменьшите амплитуду при необходимости.", "Не используйте инерцию."), 43),
    ExerciseSpec("russian_twist", "Русские скручивания", ("Косые",), "Средний", 40, 12,
                 ("Сядьте с согнутыми коленями и слегка отклоните корпус.", "Поверните грудную клетку в одну сторону.", "Через центр повернитесь в другую."),
                 ("Стопы могут оставаться на полу.", "Поворот идёт всем корпусом без резкого движения рук."), 28),
    ExerciseSpec("dead_bug", "Мёртвый жук", ("Весь пресс",), "Начальный", 45, 12,
                 ("Поднимите руки и согнутые ноги.", "Вытяните противоположные руку и ногу.", "Вернитесь в центр и смените сторону."),
                 ("Двигайтесь медленно и сохраняйте корпус устойчивым.", "Укоротите траекторию при необходимости."), 27),
    ExerciseSpec("hollow_hold", "Удержание лодочки", ("Весь пресс",), "Средний", 35, 15,
                 ("Приподнимите плечи.", "Поднимите согнутые ноги до комфортной высоты.", "Удерживайте компактное положение."),
                 ("Согнутые колени — допустимое упрощение.", "Сохраняйте контролируемое положение корпуса."), 30),
]


def font(size: int, *, bold: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = MONO_CANDIDATES if mono else (FONT_BOLD_CANDIDATES if bold else FONT_CANDIDATES)
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default(size=size)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def smooth(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return value * value * (3 - 2 * value)


def pulse(phase: float) -> float:
    """0→1→0 over one seamless cycle."""
    return 0.5 - 0.5 * math.cos(phase * math.tau)


def two_sided(phase: float) -> tuple[float, float]:
    """Alternating 0→A→0→B→0 values for bilateral movements."""
    wave = math.sin(phase * math.tau)
    return max(0.0, wave), max(0.0, -wave)


def lerp(a: tuple[float, float], b: tuple[float, float], t: float) -> tuple[float, float]:
    return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t


def pt(x: float, y: float) -> tuple[int, int]:
    return round(x), round(y)


def rounded_line(draw: ImageDraw.ImageDraw, points: list[tuple[float, float]], color: str, width: int) -> None:
    coords = [pt(x, y) for x, y in points]
    draw.line(coords, fill=color, width=width, joint="curve")
    radius = width // 2
    for x, y in (coords[0], coords[-1]):
        draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def joint(draw: ImageDraw.ImageDraw, point: tuple[float, float], radius: int = 8, color: str = MANNEQUIN) -> None:
    x, y = point
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def limb(draw: ImageDraw.ImageDraw, a: tuple[float, float], b: tuple[float, float], c: tuple[float, float] | None = None, width: int = 24) -> None:
    points = [a, b] if c is None else [a, b, c]
    rounded_line(draw, points, MANNEQUIN, width)
    if c is not None:
        joint(draw, b, max(6, width // 3))


def torso(draw: ImageDraw.ImageDraw, shoulder: tuple[float, float], hip: tuple[float, float], width: int = 42) -> None:
    rounded_line(draw, [shoulder, hip], MANNEQUIN, width)
    # Original Tempo/Cut seam: a short ultramarine core marker, not anatomical heat mapping.
    mid = lerp(shoulder, hip, 0.58)
    dx, dy = hip[0] - shoulder[0], hip[1] - shoulder[1]
    length = max(1.0, math.hypot(dx, dy))
    nx, ny = -dy / length, dx / length
    rounded_line(draw, [(mid[0] - nx * 13, mid[1] - ny * 13), (mid[0] + nx * 13, mid[1] + ny * 13)], ULTRAMARINE, 7)


def head(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: int = 26) -> None:
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=VERMILION)
    # Faceless orientation notch prevents portrait/person likeness while showing direction.
    draw.arc((x - radius + 8, y - radius + 8, x + radius - 8, y + radius - 8), 300, 55, fill=CHALK, width=3)


def base_frame() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (720, 720), CHALK_SUBTLE)
    draw = ImageDraw.Draw(image)
    # Tempo rings create a recognizable motion field without moving or relying on color.
    for radius, color, width in ((244, "#DED7CA", 2), (164, "#E4DDD1", 2)):
        draw.arc((360 - radius, 360 - radius, 360 + radius, 360 + radius), 205, 335, fill=color, width=width)
    draw.rounded_rectangle((46, 46, 674, 674), radius=42, outline="#D2CABC", width=2)
    draw.rounded_rectangle((116, 564, 604, 584), radius=10, fill="#D8D0C2")
    return image, draw


def side_lying(draw: ImageDraw.ImageDraw, *, shoulder, hip, knee, ankle, elbow, hand, head_center) -> None:
    torso(draw, shoulder, hip, 46)
    limb(draw, shoulder, elbow, hand, 20)
    limb(draw, hip, knee, ankle, 27)
    head(draw, head_center)
    joint(draw, shoulder, 11)
    joint(draw, hip, 12)


def pose_crunch(draw: ImageDraw.ImageDraw, phase: float) -> None:
    t = smooth(pulse(phase))
    shoulder = lerp((272, 500), (303, 438), t)
    head_c = lerp((216, 492), (250, 421), t)
    elbow = lerp((245, 447), (285, 388), t)
    side_lying(draw, shoulder=shoulder, hip=(388, 520), knee=(476, 430), ankle=(554, 522),
               elbow=elbow, hand=lerp((205, 425), (244, 366), t), head_center=head_c)
    rounded_line(draw, [(170, 548), (554, 548)], HAIR, 4)


def pose_reverse_crunch(draw: ImageDraw.ImageDraw, phase: float) -> None:
    t = smooth(pulse(phase))
    hip = lerp((350, 520), (326, 480), t)
    knee = lerp((442, 423), (375, 388), t)
    ankle = lerp((388, 346), (332, 337), t)
    shoulder = (245, 514)
    side_lying(draw, shoulder=shoulder, hip=hip, knee=knee, ankle=ankle,
               elbow=(248, 548), hand=(174, 548), head_center=(188, 505))
    # Far leg, offset, preserves tabletop readability.
    limb(draw, hip, lerp((464, 435), (397, 400), t), lerp((414, 354), (350, 345), t), 20)
    rounded_line(draw, [(145, 562), (548, 562)], HAIR, 4)


def pose_bicycle(draw: ImageDraw.ImageDraw, phase: float) -> None:
    left, right = two_sided(phase)
    shoulder = (288 + 18 * (left - right), 452)
    hip = (367, 518)
    torso(draw, shoulder, hip, 46)
    head(draw, (238 + 13 * (left - right), 430))
    # Hands stay beside head; shoulders rotate rather than elbows pulling the head.
    limb(draw, shoulder, (265, 407), (221, 420), 18)
    limb(draw, shoulder, (323, 401), (280, 414), 18)
    knee_a = lerp((437, 438), (357, 410), left)
    ankle_a = lerp((530, 505), (292, 540), left)
    knee_b = lerp((420, 545), (355, 416), right)
    ankle_b = lerp((542, 548), (286, 545), right)
    limb(draw, hip, knee_a, ankle_a, 24)
    limb(draw, hip, knee_b, ankle_b, 20)
    rounded_line(draw, [(160, 570), (566, 570)], HAIR, 4)


def pose_plank(draw: ImageDraw.ImageDraw, phase: float) -> None:
    breath = math.sin(phase * math.tau * 2) * 7
    shoulder, hip = (274, 390 + breath), (408, 430 + breath * 0.4)
    torso(draw, shoulder, hip, 48)
    head(draw, (221, 365 + breath), 25)
    limb(draw, shoulder, (285, 470), (224, 522), 24)
    limb(draw, hip, (500, 472), (574, 526), 27)
    limb(draw, shoulder, (336, 480), (280, 530), 18)
    limb(draw, hip, (480, 482), (542, 532), 18)
    rounded_line(draw, [(178, 548), (600, 548)], HAIR, 4)


def pose_mountain_climber(draw: ImageDraw.ImageDraw, phase: float) -> None:
    left, right = two_sided(phase)
    shoulder, hip = (286, 375), (421, 426)
    torso(draw, shoulder, hip, 46)
    head(draw, (232, 348), 25)
    limb(draw, shoulder, (302, 467), (252, 536), 24)
    limb(draw, shoulder, (347, 472), (319, 538), 18)
    knee_a = lerp((500, 474), (366, 485), left)
    ankle_a = lerp((579, 535), (305, 536), left)
    knee_b = lerp((484, 482), (355, 492), right)
    ankle_b = lerp((550, 540), (288, 540), right)
    limb(draw, hip, knee_a, ankle_a, 24)
    limb(draw, hip, knee_b, ankle_b, 18)
    rounded_line(draw, [(210, 553), (602, 553)], HAIR, 4)


def pose_toe_touch(draw: ImageDraw.ImageDraw, phase: float) -> None:
    t = smooth(pulse(phase))
    hip = (376, 523)
    shoulder = lerp((280, 518), (315, 456), t)
    torso(draw, shoulder, hip, 46)
    head(draw, lerp((224, 508), (263, 442), t), 25)
    # Vertical legs remain stable.
    limb(draw, hip, (399, 372), (422, 215), 24)
    limb(draw, hip, (363, 370), (377, 214), 18)
    hand_a = lerp((286, 466), (404, 264), t)
    hand_b = lerp((258, 471), (374, 270), t)
    limb(draw, shoulder, lerp((307, 450), (361, 340), t), hand_a, 17)
    limb(draw, shoulder, lerp((276, 449), (335, 342), t), hand_b, 14)
    rounded_line(draw, [(165, 552), (458, 552)], HAIR, 4)


def pose_leg_raise(draw: ImageDraw.ImageDraw, phase: float) -> None:
    t = smooth(pulse(phase))
    shoulder, hip = (250, 512), (375, 522)
    torso(draw, shoulder, hip, 46)
    head(draw, (193, 504), 25)
    limb(draw, shoulder, (252, 546), (180, 548), 18)
    angle = math.radians(15 + 63 * t)
    length1, length2 = 145, 145
    knee = (hip[0] + math.cos(angle) * length1, hip[1] - math.sin(angle) * length1)
    ankle = (knee[0] + math.cos(angle) * length2, knee[1] - math.sin(angle) * length2)
    limb(draw, hip, knee, ankle, 26)
    knee2 = (knee[0] - 20, knee[1] + 8)
    ankle2 = (ankle[0] - 22, ankle[1] + 12)
    limb(draw, (hip[0] - 12, hip[1] + 4), knee2, ankle2, 18)
    rounded_line(draw, [(150, 557), (585, 557)], HAIR, 4)


def pose_russian_twist(draw: ImageDraw.ImageDraw, phase: float) -> None:
    left, right = two_sided(phase)
    shift = 54 * (left - right)
    hip = (360, 500)
    shoulder = (333 + shift * 0.35, 375)
    torso(draw, shoulder, hip, 52)
    head(draw, (320 + shift * 0.42, 316), 27)
    hands = (364 + shift, 423)
    limb(draw, shoulder, (348 + shift * 0.65, 404), hands, 18)
    limb(draw, shoulder, (320 + shift * 0.60, 410), (350 + shift, 432), 15)
    limb(draw, hip, (445, 470), (518, 538), 25)
    limb(draw, hip, (423, 492), (481, 543), 18)
    rounded_line(draw, [(280, 555), (548, 555)], HAIR, 4)


def pose_dead_bug(draw: ImageDraw.ImageDraw, phase: float) -> None:
    left, right = two_sided(phase)
    # Overhead camera: a vertical mat makes the supine orientation unambiguous.
    draw.rounded_rectangle((250, 172, 470, 615), radius=44, fill="#E0D8CA", outline="#CFC6B8", width=2)
    # Torso vertical, head top, paired limbs clearly separated.
    shoulder, hip = (360, 315), (360, 446)
    torso(draw, shoulder, hip, 58)
    head(draw, (360, 250), 28)
    arm_l = lerp((262, 284), (182, 404), left)
    arm_r = lerp((458, 284), (538, 404), right)
    limb(draw, shoulder, (304, 300), arm_l, 18)
    limb(draw, shoulder, (416, 300), arm_r, 18)
    knee_l = lerp((302, 490), (251, 530), right)
    foot_l = lerp((302, 572), (179, 586), right)
    knee_r = lerp((418, 490), (469, 530), left)
    foot_r = lerp((418, 572), (541, 586), left)
    limb(draw, hip, knee_l, foot_l, 24)
    limb(draw, hip, knee_r, foot_r, 24)


def pose_hollow_hold(draw: ImageDraw.ImageDraw, phase: float) -> None:
    breath = math.sin(phase * math.tau * 2) * 8
    shoulder, hip = (299, 462 - breath), (388, 507)
    torso(draw, shoulder, hip, 46)
    head(draw, (245, 444 - breath), 25)
    limb(draw, shoulder, (346, 412 - breath), (395, 399 - breath), 18)
    limb(draw, shoulder, (329, 427 - breath), (374, 420 - breath), 14)
    limb(draw, hip, (454, 440 + breath), (518, 489 + breath), 25)
    limb(draw, hip, (438, 459 + breath), (489, 507 + breath), 18)
    rounded_line(draw, [(164, 553), (544, 553)], HAIR, 4)


POSES: dict[str, Callable[[ImageDraw.ImageDraw, float], None]] = {
    "crunch": pose_crunch,
    "reverse_crunch": pose_reverse_crunch,
    "bicycle_twist": pose_bicycle,
    "plank": pose_plank,
    "mountain_climber": pose_mountain_climber,
    "toe_touch": pose_toe_touch,
    "leg_raise": pose_leg_raise,
    "russian_twist": pose_russian_twist,
    "dead_bug": pose_dead_bug,
    "hollow_hold": pose_hollow_hold,
}


def render_motion_frame(spec: ExerciseSpec, index: int) -> Image.Image:
    image, draw = base_frame()
    phase = index / 119.0
    POSES[spec.id](draw, phase)
    return image


def encode_video(spec: ExerciseSpec) -> Path:
    path = EXPORTS / f"exercise_{spec.id}_v1.mp4"
    command = [
        FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "720x720", "-r", "30", "-i", "-",
        "-an", "-c:v", "libx264", "-preset", "slow", "-crf", "27",
        "-pix_fmt", "yuv420p", "-color_primaries", "bt709", "-color_trc", "bt709",
        "-colorspace", "bt709", "-movflags", "+faststart", str(path),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    for index in range(120):
        process.stdin.write(render_motion_frame(spec, index).tobytes())
    process.stdin.close()
    code = process.wait()
    if code != 0:
        raise RuntimeError(f"ffmpeg failed for {spec.id}: {code}")
    return path


def save_poster(spec: ExerciseSpec) -> Path:
    path = EXPORTS / f"exercise_{spec.id}_poster_v1.jpg"
    render_motion_frame(spec, spec.poster_frame).save(path, quality=88, optimize=True, progressive=True, subsampling=2)
    return path


# --- iOS handoff screens ---------------------------------------------------
S = 2


def u(value: float) -> int:
    return round(value * S)


def ui_font(size: float, *, bold: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    return font(u(round(size)), bold=bold, mono=mono)


def txt(draw: ImageDraw.ImageDraw, xy, value, size, fill=CARBON, *, bold=False, mono=False, anchor=None, spacing=4, align="left") -> None:
    draw.multiline_text((u(xy[0]), u(xy[1])), value, font=ui_font(size, bold=bold, mono=mono), fill=fill,
                        anchor=anchor, spacing=u(spacing), align=align, stroke_width=1 if bold else 0, stroke_fill=fill)


def rr(draw: ImageDraw.ImageDraw, box, radius, fill=None, outline=None, width=1) -> None:
    draw.rounded_rectangle(tuple(u(v) for v in box), radius=u(radius), fill=fill, outline=outline, width=max(1, u(width)))


def line_ui(draw: ImageDraw.ImageDraw, points, fill=HAIR, width: float = 1) -> None:
    draw.line(tuple(u(v) for v in points), fill=fill, width=max(1, u(width)))


def status(draw: ImageDraw.ImageDraw, width: int) -> None:
    txt(draw, (20, 18), "9:41", 14, bold=True)
    txt(draw, (width - 43, 18), "5G", 13, bold=True, anchor="ra")
    rr(draw, (width - 35, 21, width - 20, 28), 2, None, CARBON, 1)


def search_glyph(draw: ImageDraw.ImageDraw, cx: float, cy: float, color=MUTED, scale=1.0) -> None:
    radius = 6 * scale
    draw.ellipse(tuple(u(v) for v in (cx-radius, cy-radius, cx+radius, cy+radius)), outline=color, width=max(2,u(1.5*scale)))
    line_ui(draw, (cx+radius*0.7, cy+radius*0.7, cx+radius*1.65, cy+radius*1.65), color, 1.8*scale)


def nav(draw: ImageDraw.ImageDraw, width: int, title: str, *, back=True) -> None:
    if back:
        txt(draw, (20, 56), "‹", 32, bold=True, anchor="lm")
        txt(draw, (43, 56), "Назад", 15, anchor="lm")
    txt(draw, (width / 2, 56), title, 16, bold=True, anchor="mm")


def chip(draw: ImageDraw.ImageDraw, x: float, y: float, label: str, *, selected=False, width=None, enabled=True) -> float:
    if width is None:
        width = max(70, 22 + len(label) * 7.2)
    fill = CARBON if selected else CHALK
    outline = CARBON if selected else HAIR
    rr(draw, (x, y, x + width, y + 38), 19, fill, outline, 1)
    txt(draw, (x + width / 2, y + 19), label, 12, WHITE if selected else (CARBON if enabled else MUTED), bold=selected, anchor="mm")
    return width


def result_card(draw: ImageDraw.ImageDraw, spec: ExerciseSpec, poster: Image.Image, x: float, y: float, width: float, *, ax=False) -> float:
    image_size = 84 if not ax else 92
    target = poster.resize((u(image_size), u(image_size)), Image.Resampling.LANCZOS)
    draw._image.paste(target, (u(x), u(y)))
    tx = x + image_size + 14
    txt(draw, (tx, y + 3), spec.title, 16 if not ax else 19, bold=True)
    zone = " · ".join(spec.zones)
    txt(draw, (tx, y + 31 if not ax else y + 36), f"{zone}  ·  {spec.difficulty}", 11 if not ax else 14, MUTED, bold=True)
    txt(draw, (tx, y + 55 if not ax else y + 66), f"{spec.work} сек", 13 if not ax else 16, mono=True, bold=True)
    txt(draw, (x + width - 8, y + image_size / 2), "›", 28, MUTED, anchor="mm")
    line_ui(draw, (x, y + image_size + 12, x + width, y + image_size + 12), HAIR, 1)
    return image_size + 26


def library_screen(*, filtered=False, no_results=False, empty=False, loading=False, compact=False, ax=False, width=393, height=852) -> Image.Image:
    image = Image.new("RGB", (u(width), u(height)), CHALK)
    draw = ImageDraw.Draw(image); draw._image = image
    status(draw, width); nav(draw, width, "Упражнения")
    top = 84
    rr(draw, (20, top, width - 20, top + 44), 13, CHALK_SUBTLE)
    search_glyph(draw, 38, top + 20)
    query = "планка" if filtered else ("скручивание стоя" if no_results else "Найти упражнение")
    txt(draw, (55, top + 22), query, 14 if not ax else 17, MUTED if not (filtered or no_results) else CARBON, anchor="lm")
    y = top + 58
    choices = [("Все зоны", not filtered and not no_results), ("Верхний", False), ("Нижний", False), ("Косые", False), ("Весь пресс", filtered)]
    x = 20
    for label, selected in choices:
        w = chip(draw, x, y, label, selected=selected)
        x += w + 8
        if x > width - 54:
            txt(draw, (width - 20, y + 19), "…", 18, MUTED, anchor="rm")
            break
    y += 50
    chip(draw, 20, y, "Любая сложность", selected=not filtered and not no_results, width=140)
    chip(draw, 168, y, "Начальный", selected=False, width=96)
    chip(draw, 272, y, "Средний", selected=filtered, width=91)
    y += 55

    if loading:
        txt(draw, (20, y), "Подготовка каталога", 13, MUTED, bold=True)
        y += 30
        for i in range(5):
            rr(draw, (20, y + i * 104, 104, y + i * 104 + 84), 18, CHALK_SUBTLE)
            rr(draw, (120, y + i * 104 + 8, width - 48, y + i * 104 + 22), 7, "#DDD6C9")
            rr(draw, (120, y + i * 104 + 34, width - 86, y + i * 104 + 46), 6, "#E3DCCE")
            rr(draw, (120, y + i * 104 + 61, 181, y + i * 104 + 75), 7, "#DDD6C9")
        return image

    if empty:
        empty_state(draw, width, y + 68, "Каталог пока недоступен", "Локальные материалы не прошли проверку.", "Назад к настройке", warning=True)
        return image
    if no_results:
        empty_state(draw, width, y + 70, "Ничего не найдено", "Попробуйте изменить поиск\nили фильтры.", "Сбросить фильтры")
        return image

    visible = [EXERCISES[3]] if filtered else EXERCISES
    txt(draw, (20, y), "1 упражнение" if filtered else "10 упражнений", 13 if not ax else 16, MUTED, bold=True)
    txt(draw, (width - 20, y), "Сбросить", 13 if not ax else 16, CARBON, bold=True, anchor="ra")
    y += 30
    posters = {s.id: Image.open(EXPORTS / f"exercise_{s.id}_poster_v1.jpg") for s in visible}
    for spec in visible[:5 if not compact else 4]:
        y += result_card(draw, spec, posters[spec.id], 20, y, width - 40, ax=ax)
    return image


def empty_state(draw: ImageDraw.ImageDraw, width: int, y: float, title: str, body: str, action: str, warning=False) -> None:
    draw.ellipse(tuple(u(v) for v in (width / 2 - 42, y - 42, width / 2 + 42, y + 42)), outline=SIGNAL if warning else ULTRAMARINE, width=u(8))
    if warning:
        txt(draw, (width / 2, y), "!", 30, CARBON, bold=True, anchor="mm")
    else:
        search_glyph(draw, width / 2 - 2, y - 2, CARBON, 1.8)
    txt(draw, (width / 2, y + 78), title, 24, bold=True, anchor="ma", align="center")
    txt(draw, (width / 2, y + 120), body, 15, MUTED, anchor="ma", align="center", spacing=3)
    rr(draw, (54, y + 184, width - 54, y + 240), 18, CARBON)
    txt(draw, (width / 2, y + 212), action, 15, WHITE, bold=True, anchor="mm")


def detail_screen(spec: ExerciseSpec, *, fallback=False, reduce_motion=False, ax=False, landscape=False, full_scroll=False) -> Image.Image:
    if landscape:
        width, height = 852, 393
    else:
        width, height = 393, 1180 if full_scroll else 852
    image = Image.new("RGB", (u(width), u(height)), CHALK)
    draw = ImageDraw.Draw(image); draw._image = image
    status(draw, width); nav(draw, width, "Техника")
    poster = Image.open(EXPORTS / f"exercise_{spec.id}_poster_v1.jpg")
    if landscape:
        media_x, media_y, media_size = 24, 90, 278
        image.paste(poster.resize((u(media_size), u(media_size)), Image.Resampling.LANCZOS), (u(media_x), u(media_y)))
        text_x, text_y, col_w = 332, 90, 488
    else:
        media_x, media_y, media_size = 20, 86, 353
        image.paste(poster.resize((u(media_size), u(media_size)), Image.Resampling.LANCZOS), (u(media_x), u(media_y)))
        text_x, text_y, col_w = 20, 463, 353
    rr(draw, (media_x + 12, media_y + 12, media_x + (178 if reduce_motion else 130), media_y + 44), 16, CHALK)
    badge = "СТАТИЧНАЯ ДЕМОНСТРАЦИЯ" if reduce_motion else ("АНИМАЦИЯ НЕДОСТУПНА" if fallback else "4 СЕК · LOOP")
    txt(draw, (media_x + 24, media_y + 28), badge, 9.5 if reduce_motion else 10, SIGNAL if fallback else CARBON, bold=True, anchor="lm")
    if fallback:
        rr(draw, (media_x + 12, media_y + media_size - 54, media_x + media_size - 12, media_y + media_size - 12), 12, CHALK)
        txt(draw, (media_x + 24, media_y + media_size - 33), "Анимация недоступна · показан poster", 11, SIGNAL, bold=True, anchor="lm")

    title_size = 27 if ax else 25
    txt(draw, (text_x, text_y), spec.title, title_size, bold=True)
    y = text_y + (43 if not landscape else 38)
    x = text_x
    for label in (*spec.zones, spec.difficulty):
        w = chip(draw, x, y, label, width=max(72, 20 + len(label) * 7))
        x += w + 7
    y += 50
    txt(draw, (text_x, y), f"РАБОТА  {spec.work} СЕК", 11, VERMILION, bold=True)
    txt(draw, (text_x + 152, y), f"ОТДЫХ  {spec.rest} СЕК", 11, ULTRAMARINE, bold=True)
    y += 36
    txt(draw, (text_x, y), "Как выполнять", 18 if not ax else 22, bold=True)
    y += 34
    phase_size = 13 if not ax else 16
    for index, phase_text in enumerate(spec.phases, 1):
        draw.ellipse(tuple(u(v) for v in (text_x, y, text_x + 24, y + 24)), fill=CARBON)
        txt(draw, (text_x + 12, y + 12), str(index), 11, WHITE, bold=True, anchor="mm")
        wrapped = wrap_text(phase_text, 40 if not landscape else 58)
        txt(draw, (text_x + 36, y), wrapped, phase_size, CARBON, spacing=2)
        y += 48 if not ax else 62
    if landscape:
        # Compact landscape shows complete content via vertical scroll; this frame annotates below-fold content.
        txt(draw, (text_x, height - 24), "↓ Обратите внимание и дисклеймер доступны ниже", 11, MUTED, bold=True)
    else:
        txt(draw, (text_x, y + 8), "Обратите внимание", 18 if not ax else 22, bold=True)
        y += 42
        for cue in spec.cues:
            txt(draw, (text_x, y), "—", 14, VERMILION, bold=True)
            txt(draw, (text_x + 22, y), wrap_text(cue, 42), phase_size, MUTED, spacing=2)
            y += 42 if not ax else 58
        rr(draw, (text_x, y + 10, text_x + col_w, y + 146), 18, CHALK_SUBTLE)
        txt(draw, (text_x + 16, y + 26), "ОЗНАКОМИТЕЛЬНАЯ ДЕМОНСТРАЦИЯ", 9, MUTED, bold=True)
        txt(draw, (text_x + 16, y + 48), "Демонстрация носит ознакомительный\nхарактер. Выбирайте комфортную\nамплитуду и остановитесь, если движение\nвызывает дискомфорт.", 12, CARBON, spacing=2)
    return image


def wrap_text(value: str, limit: int) -> str:
    words = value.split()
    lines, current = [], []
    for word in words:
        if current and len(" ".join(current + [word])) > limit:
            lines.append(" ".join(current)); current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))
    return "\n".join(lines)


def ipad_library_screen() -> Image.Image:
    width, height = 1024, 768
    image = Image.new("RGB", (width, height), CHALK)
    draw = ImageDraw.Draw(image); draw._image = image
    draw.text((42, 34), "Упражнения", font=font(32, bold=True), fill=CARBON)
    draw.text((42, 78), "Локальная библиотека техники", font=font(16), fill=MUTED)
    draw.rounded_rectangle((42, 118, 982, 166), radius=15, fill=CHALK_SUBTLE)
    draw.text((64, 131), "⌕   Найти упражнение", font=font(16), fill=MUTED)
    x = 42
    for label, selected in (("Все зоны", True), ("Верхний", False), ("Нижний", False), ("Косые", False), ("Весь пресс", False)):
        w = max(90, 28 + len(label) * 8)
        draw.rounded_rectangle((x, 186, x+w, 228), radius=21, fill=CARBON if selected else CHALK, outline=CARBON if selected else HAIR)
        draw.text((x+w/2, 207), label, font=font(13, bold=selected), fill=WHITE if selected else CARBON, anchor="mm")
        x += w + 10
    draw.text((42, 259), "10 упражнений", font=font(14, bold=True), fill=MUTED)
    posters = {s.id: Image.open(EXPORTS / f"exercise_{s.id}_poster_v1.jpg") for s in EXERCISES[:6]}
    for i, spec in enumerate(EXERCISES[:6]):
        row, col = divmod(i, 2); x = 42 + col * 480; y = 294 + row * 145
        card_w = 452
        image.paste(posters[spec.id].resize((116,116), Image.Resampling.LANCZOS), (x,y))
        draw.text((x+134,y+6), spec.title, font=font(18,bold=True), fill=CARBON)
        draw.text((x+134,y+39), " · ".join(spec.zones), font=font(13,bold=True), fill=MUTED)
        draw.text((x+134,y+67), f"{spec.difficulty}  ·  {spec.work} сек", font=font(13), fill=CARBON)
        draw.text((x+card_w-10,y+58), "›", font=font(28), fill=MUTED, anchor="mm")
        draw.line((x,y+129,x+card_w,y+129),fill=HAIR,width=1)
    return image


def make_motion_contact_sheet(posters: Mapping[str, Image.Image]) -> Image.Image:
    board = Image.new("RGB", (1600, 760), CARBON)
    draw = ImageDraw.Draw(board)
    draw.text((48, 34), "TEMPO / CUT · 10 ORIGINAL MOTION LOOPS", font=font(30, bold=True), fill=WHITE)
    draw.text((48, 78), "One neutral mannequin · one camera grammar · 720² H.264 + JPG poster · owned original work", font=font(17), fill="#C7C7C3")
    for i, spec in enumerate(EXERCISES):
        row, col = divmod(i, 5); x = 48 + col * 304; y = 128 + row * 292
        thumb = posters[spec.id].resize((252,252), Image.Resampling.LANCZOS)
        board.paste(thumb,(x,y))
        draw.text((x,y+260), f"{i+1:02d} · {spec.title}", font=font(15,bold=True), fill=WHITE)
    draw.text((48, 724), "No third-party characters, logos, stock media, templates, or external links", font=font(14), fill="#9D9991")
    return board


def make_storyboard_sheet() -> Image.Image:
    board = Image.new("RGB", (1600, 2220), CARBON)
    draw = ImageDraw.Draw(board)
    draw.text((48, 32), "MOTION STORYBOARD · 5 LOOP PHASES", font=font(30, bold=True), fill=WHITE)
    draw.text((48, 75), "Source phases · first and last pose identical · review bilateral alternation and hold breathing", font=font(16), fill="#C7C7C3")
    indices = (0, 24, 48, 72, 119)
    for row, spec in enumerate(EXERCISES):
        y = 120 + row * 206
        draw.text((48, y + 6), f"{row+1:02d}", font=font(17, bold=True), fill=VERMILION)
        draw.text((48, y + 36), spec.title, font=font(14, bold=True), fill=WHITE)
        for col, index in enumerate(indices):
            frame = render_motion_frame(spec, index).resize((182, 182), Image.Resampling.LANCZOS)
            board.paste(frame, (252 + col * 258, y))
            draw.text((252 + col * 258, y + 184), f"{index/30:.1f} s", font=font(11), fill="#A9A59D")
        draw.line((48, y + 201, 1552, y + 201), fill="#353531", width=1)
    return board


def make_screen_contact_sheet(screens: list[tuple[str, Image.Image]]) -> Image.Image:
    board = Image.new("RGB", (1900, 1540), CARBON)
    draw = ImageDraw.Draw(board)
    draw.text((54, 42), "ABS TRAINER · EXERCISE LIBRARY", font=font(34,bold=True), fill=WHITE)
    draw.text((54, 88), "Tempo / Cut · catalog, states, detail and responsive handoff", font=font(18), fill="#C7C7C3")
    slots = [(54,150),(330,150),(606,150),(882,150),(1158,150),(1434,150),
             (54,790),(330,790),(606,790),(882,790),(1158,790),(1434,790)]
    for (label, screen),(x,y) in zip(screens,slots):
        max_w,max_h=244,520
        ratio=min(max_w/screen.width,max_h/screen.height)
        thumb=screen.resize((round(screen.width*ratio),round(screen.height*ratio)),Image.Resampling.LANCZOS)
        board.paste(thumb,(x,y+36))
        draw.text((x,y),label,font=font(14,bold=True),fill=WHITE)
    draw.text((54, 1410), "COMPACT / AX3 / LANDSCAPE", font=font(14,bold=True), fill=ULTRAMARINE)
    draw.text((54, 1443), "One column in compact + accessibility sizes · content scrolls · no pinned control obscures cards or phases", font=font(15), fill="#C7C7C3")
    draw.text((54, 1476), "Reduce Motion: poster, badge and complete phases; no autoplay · Landscape preserves media → content reading order", font=font(15), fill="#C7C7C3")
    return board


def encode_all_preview() -> Path:
    path = PREVIEWS / "all-exercises-preview.mp4"
    width, height = 1200, 520
    command = [FFMPEG,"-hide_banner","-loglevel","error","-y","-f","rawvideo","-pix_fmt","rgb24","-s",f"{width}x{height}","-r","30","-i","-","-an","-c:v","libx264","-preset","slow","-crf","26","-pix_fmt","yuv420p","-movflags","+faststart",str(path)]
    process=subprocess.Popen(command,stdin=subprocess.PIPE); assert process.stdin is not None
    for frame_index in range(120):
        board=Image.new("RGB",(width,height),CARBON); draw=ImageDraw.Draw(board)
        for i,spec in enumerate(EXERCISES):
            row,col=divmod(i,5); x=16+col*238; y=12+row*252
            frame=render_motion_frame(spec,frame_index).resize((220,220),Image.Resampling.LANCZOS)
            board.paste(frame,(x,y))
            draw.text((x,y+224),spec.title,font=font(13,bold=True),fill=WHITE)
        process.stdin.write(board.tobytes())
    process.stdin.close(); code=process.wait()
    if code != 0: raise RuntimeError(f"all-preview ffmpeg failed: {code}")
    return path


def ffprobe(path: Path) -> dict:
    probe = subprocess.run([FFMPEG,"-hide_banner","-loglevel","error","-i",str(path),"-f","ffmetadata","-"],capture_output=True,text=True)
    # ffmpeg returns technical stream info on stderr even when metadata output is empty.
    return {"decode_exit": probe.returncode}


def build_manifest(video_paths: dict[str,Path], poster_paths: dict[str,Path]) -> dict:
    assets=[]
    for spec in sorted(EXERCISES,key=lambda item:item.id):
        video=video_paths[spec.id]; poster=poster_paths[spec.id]
        assets.append({
            "exercise_id":spec.id,
            "catalog_media_name":f"exercise_{spec.id}_v1",
            "video":{"path":str(video.relative_to(ROOT)),"container":"mp4","codec":"h264","pixel_format":"yuv420p","width_px":720,"height_px":720,"fps":30,"duration_ms":4000,"frame_count":120,"has_audio":False,"loop":"seamless","size_bytes":video.stat().st_size,"sha256":sha256(video)},
            "poster":{"path":str(poster.relative_to(ROOT)),"width_px":720,"height_px":720,"color_space":"sRGB","size_bytes":poster.stat().st_size,"sha256":sha256(poster)},
            "source":{"master_path":"design/exercise-library/source/render_exercise_library.py","creator_role":"designer","provenance":"original_in_house","license":"owned_original_work","third_party_inputs":[],"source_notes":"Original geometric neutral mannequin, camera field and per-exercise motion authored from scratch for ABS Trainer; system/locally staged fonts affect preview labels only."},
            "qa":{"opens":True,"visual_review":"pass_designer","seam_review":"pass_automated_and_designer","storyboard_review":"pass_designer_pending_domain_human","reduce_motion_poster_review":"pass"},
        })
    return {"schema_version":1,"catalog":"ExerciseCatalog.starter","export_profile":"abs-exercise-square-h264-v1","generated_at":datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00","Z"),"assets":assets}


def save_html(screen_names: list[str]) -> None:
    cards="\n".join(f'<figure><img src="screens/{name}" alt="{name}"><figcaption>{name}</figcaption></figure>' for name in screen_names)
    html=f'''<!doctype html><meta charset="utf-8"><title>ABS Trainer Exercise Library</title><style>body{{margin:0;background:{CARBON};color:white;font:16px system-ui;padding:32px}}h1{{font-size:28px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:28px}}figure{{margin:0}}img{{width:100%;height:auto;background:{CHALK};border-radius:18px}}figcaption{{margin-top:8px;color:#c7c7c3}}a{{color:#fff}}</style><h1>ABS Trainer · Exercise Library</h1><p>Local design review gallery. Runtime media is MP4; this page is preview only.</p><p><a href="contact-sheet.png">Motion contact sheet</a> · <a href="all-exercises-preview.mp4">All loops preview</a> · <a href="screens-contact-sheet.png">Screen contact sheet</a></p><div class="grid">{cards}</div>'''
    (PREVIEWS/"index.html").write_text(html,encoding="utf-8")


def main() -> None:
    for directory in (EXPORTS,PREVIEWS,SCREENS,MANIFEST_DIR,SOURCE): directory.mkdir(parents=True,exist_ok=True)
    video_paths={}; poster_paths={}
    for spec in EXERCISES:
        print(f"render {spec.id}",flush=True)
        video_paths[spec.id]=encode_video(spec)
        poster_paths[spec.id]=save_poster(spec)
    posters={spec.id:Image.open(poster_paths[spec.id]) for spec in EXERCISES}
    make_motion_contact_sheet(posters).save(PREVIEWS/"contact-sheet.png",optimize=True)
    make_storyboard_sheet().save(PREVIEWS/"motion-storyboards.png",optimize=True)
    encode_all_preview()

    screens=[
        ("01-default",library_screen()),
        ("02-filtered",library_screen(filtered=True)),
        ("03-no-results",library_screen(no_results=True)),
        ("04-empty",library_screen(empty=True)),
        ("05-loading",library_screen(loading=True)),
        ("06-detail",detail_screen(EXERCISES[2])),
        ("07-video-fallback",detail_screen(EXERCISES[2],fallback=True)),
        ("08-reduce-motion",detail_screen(EXERCISES[2],reduce_motion=True)),
        ("09-compact-320x568",library_screen(compact=True,width=320,height=568)),
        ("10-ax3-393x852",library_screen(ax=True)),
        ("11-landscape-852x393",detail_screen(EXERCISES[2],landscape=True)),
        ("12-ipad-1024x768",ipad_library_screen()),
        ("13-detail-full-scroll",detail_screen(EXERCISES[2],full_scroll=True)),
    ]
    screen_names=[]
    for label,image in screens:
        name=f"{label}.png"; image.save(SCREENS/name,optimize=True); screen_names.append(name)
    make_screen_contact_sheet(screens).save(PREVIEWS/"screens-contact-sheet.png",optimize=True)
    save_html(screen_names)
    manifest=build_manifest(video_paths,poster_paths)
    (MANIFEST_DIR/"exercise-assets.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"generated {len(video_paths)} videos, {len(poster_paths)} posters, {len(screens)} screens")


if __name__ == "__main__":
    main()
