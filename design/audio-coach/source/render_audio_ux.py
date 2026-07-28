#!/usr/bin/env python3
"""Render design-only audio coach states; production Swift is not modified."""
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ux" / "screens"
S = 2
W, H = 393, 852
CHALK = "#F5F1E8"
CHALK_SUBTLE = "#ECE5D8"
CARBON = "#171714"
MUTED = "#55534D"
VERMILION = "#D13A25"
ULTRAMARINE = "#2946C6"
HAIR = "#D5D0C6"
WHITE = "#FFFFFF"
FONT_REGULAR = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
FONT_BOLD = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf")
FONT_MONO = Path("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf")


def u(value: float) -> int:
    return round(value * S)


def font(size: float, bold: bool = False, mono: bool = False):
    path = FONT_MONO if mono else FONT_BOLD if bold else FONT_REGULAR
    return ImageFont.truetype(str(path), u(size))


def text(draw, xy, value, size, fill=CARBON, *, bold=False, mono=False, anchor=None, spacing=3, align="left"):
    draw.multiline_text((u(xy[0]), u(xy[1])), value, font=font(size, bold, mono), fill=fill,
                        anchor=anchor, spacing=u(spacing), align=align)


def rr(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(tuple(u(v) for v in box), radius=u(radius), fill=fill,
                           outline=outline, width=max(1, u(width)))


def line(draw, points, fill, width=1):
    draw.line(tuple(u(v) for v in points), fill=fill, width=max(1, u(width)))


def ellipse(draw, box, fill=None, outline=None, width=1):
    draw.ellipse(tuple(u(v) for v in box), fill=fill, outline=outline, width=max(1, u(width)))


def base(light=True):
    im = Image.new("RGB", (u(W), u(H)), CHALK if light else CARBON)
    d = ImageDraw.Draw(im)
    color = CARBON if light else WHITE
    text(d, (20, 15), "9:41", 12, color, bold=True)
    text(d, (350, 15), "5G", 11, color, bold=True)
    rr(d, (367, 17, 384, 25), 2, None, color, 1)
    rr(d, (369, 19, 380, 23), 1, color)
    rr(d, (145, 841, 248, 845), 2, color)
    return im, d


def toggle(draw, x, y, enabled=True):
    fill = ULTRAMARINE if enabled else HAIR
    rr(draw, (x, y, x + 51, y + 31), 16, fill)
    cx = x + (35 if enabled else 16)
    ellipse(draw, (cx - 12, y + 3, cx + 12, y + 27), WHITE)


def speaker(draw, cx, cy, muted=False, color=CARBON):
    # Original geometric glyph, not an imported icon asset.
    draw.polygon([(u(cx-10),u(cy-4)),(u(cx-4),u(cy-4)),(u(cx+4),u(cy-11)),
                  (u(cx+4),u(cy+11)),(u(cx-4),u(cy+4)),(u(cx-10),u(cy+4))], fill=color)
    if muted:
        line(draw, (cx+9, cy-8, cx+20, cy+8), color, 2)
        line(draw, (cx+20, cy-8, cx+9, cy+8), color, 2)
    else:
        draw.arc(tuple(u(v) for v in (cx, cy-9, cx+18, cy+9)), -55, 55, fill=color, width=u(2))


def slider(draw, y, value=0.5, disabled=False, ax=False):
    x1, x2 = 20, 373
    color = MUTED if disabled else ULTRAMARINE
    track = "#C6C2B8" if disabled else HAIR
    line(draw, (x1, y, x2, y), track, 5 if ax else 4)
    line(draw, (x1, y, x1 + (x2-x1)*value, y), color, 5 if ax else 4)
    hx = x1 + (x2-x1)*value
    ellipse(draw, (hx-12, y-12, hx+12, y+12), CHALK if disabled else WHITE, color, 2)


def audio_rows(draw, top, *, music=True, volume=0.5, voice=True, ax=False):
    title_size = 22 if ax else 18
    body_size = 18 if ax else 15
    row_h = 82 if ax else 64
    text(draw, (20, top), "Звук тренировки", title_size, bold=True)
    text(draw, (373, top+4), "Локально", 12 if not ax else 15, MUTED, bold=True, anchor="ra")
    y = top + 38
    line(draw, (20, y, 373, y), HAIR)
    text(draw, (20, y+18), "Музыка", body_size, bold=True)
    text(draw, (20, y+43 if ax else y+39), "Оригинальный ритм", 13 if not ax else 16, MUTED)
    toggle(draw, 322, y+15 if not ax else y+24, music)
    y += row_h
    line(draw, (20, y, 373, y), HAIR)
    text(draw, (20, y+16), "Громкость музыки", body_size, bold=True)
    text(draw, (373, y+18), f"{round(volume*100)}%", 14 if not ax else 17, MUTED, bold=True, anchor="ra")
    slider(draw, y+54 if not ax else y+64, volume, disabled=not music, ax=ax)
    y += row_h + (14 if ax else 10)
    line(draw, (20, y, 373, y), HAIR)
    text(draw, (20, y+18), "Голосовой тренер", body_size, bold=True)
    text(draw, (20, y+43 if ax else y+39), "Переходы и темп", 13 if not ax else 16, MUTED)
    toggle(draw, 322, y+15 if not ax else y+24, voice)
    line(draw, (20, y+row_h, 373, y+row_h), HAIR)
    return y + row_h


def primary(draw, y, title_value):
    rr(draw, (20, y, 373, y+58), 20, CARBON)
    text(draw, (196.5, y+29), title_value, 16, WHITE, bold=True, anchor="mm")


def setup_state(music=True, ax=False):
    im, d = base(True)
    text(d, (20, 58), "ЛОКАЛЬНАЯ ТРЕНИРОВКА", 10 if not ax else 13, VERMILION, bold=True)
    text(d, (20, 82), "Соберите свой темп" if not ax else "Соберите\nсвой темп", 31 if not ax else 37, bold=True, spacing=-2)
    text(d, (20, 130 if not ax else 176), "Настройки звука можно изменить\nдо начала тренировки.", 14 if not ax else 19, MUTED, spacing=4)
    top = 205 if not ax else 258
    end = audio_rows(d, top, music=music, volume=.5, voice=True, ax=ax)
    if not music:
        text(d, (20, end+14), "Музыка выключена. Голосовые подсказки\nпродолжат работать.", 12, MUTED)
    else:
        text(d, (20, end+14), "Во время подсказки музыка автоматически\nстанет тише.", 12 if not ax else 15, MUTED)
    primary(d, 758, "Собрать тренировку")
    return im


def plan_state():
    im, d = base(True)
    text(d, (20, 58), "‹", 32, bold=True)
    text(d, (196, 70), "Ваш план", 14, bold=True, anchor="mm")
    text(d, (20, 112), "СЕГОДНЯ · ВЕСЬ ПРЕСС", 10, VERMILION, bold=True)
    text(d, (20, 140), "10 минут\nбез спешки", 34, bold=True, spacing=-1)
    rr(d, (20, 224, 119, 254), 15, CHALK_SUBTLE); text(d, (69.5,239), "8 упражнений", 10, bold=True, anchor="mm")
    rr(d, (127, 224, 204, 254), 15, CHALK_SUBTLE); text(d, (165.5,239), "7 пауз", 10, bold=True, anchor="mm")
    text(d, (20, 287), "ЗВУК ТРЕНИРОВКИ", 10, VERMILION, bold=True)
    line(d, (20, 315, 373, 315), HAIR)
    speaker(d, 35, 344, False, ULTRAMARINE)
    text(d, (60, 331), "Музыка · 50%", 15, bold=True)
    text(d, (60, 353), "Голосовой тренер включён", 12, MUTED)
    text(d, (373, 344), "Изменить", 13, ULTRAMARINE, bold=True, anchor="rm")
    line(d, (20, 377, 373, 377), HAIR)
    text(d, (20, 405), "01", 13, VERMILION, bold=True, mono=True); text(d, (62, 405), "Скручивания", 15, bold=True); text(d, (373,405), "0:40", 14, bold=True, mono=True, anchor="ra")
    line(d, (20, 441, 373, 441), HAIR)
    text(d, (20, 465), "02", 13, VERMILION, bold=True, mono=True); text(d, (62, 465), "Обратные скручивания", 15, bold=True); text(d, (373,465), "0:40", 14, bold=True, mono=True, anchor="ra")
    line(d, (20, 501, 373, 501), HAIR)
    text(d, (20, 525), "03", 13, VERMILION, bold=True, mono=True); text(d, (62, 525), "Велосипед с поворотом", 15, bold=True); text(d, (373,525), "0:40", 14, bold=True, mono=True, anchor="ra")
    line(d, (20, 561, 373, 561), HAIR)
    text(d, (20, 588), "…", 20, MUTED)
    primary(d, 758, "Начать тренировку")
    return im


def pause_glyph(d, cx, cy):
    rr(d, (cx-6,cy-9,cx-2,cy+9),1,WHITE); rr(d,(cx+2,cy-9,cx+6,cy+9),1,WHITE)


def player_state(muted=False, voiceover=False):
    im, d = base(False)
    text(d, (20, 58), "×", 27, WHITE)
    text(d, (196, 72), "03 / 08", 14, WHITE, bold=True, mono=True, anchor="mm")
    ellipse(d, (329, 48, 377, 96), None, "#80807A", 1)
    speaker(d, 350, 72, muted, WHITE)
    for i in range(8):
        color = VERMILION if i < 2 else WHITE if i == 2 else "#555550"
        rr(d, (20+i*45, 111, 59+i*45, 115), 2, color)
    text(d, (20, 139), "Велосипед\nс поворотом", 29, WHITE, bold=True, spacing=-2)
    text(d, (373, 185), "КОСЫЕ", 10, "#B8B8B3", bold=True, anchor="ra")
    rr(d, (20, 216, 373, 475), 28, CHALK)
    ellipse(d, (145, 260, 249, 364), None, HAIR)
    ellipse(d, (224, 278, 260, 314), VERMILION)
    line(d, (236, 314, 203, 354, 186, 414), CARBON, 14)
    line(d, (206, 337, 162, 326, 139, 310), ULTRAMARINE, 10)
    line(d, (205, 345, 250, 372, 276, 396), CARBON, 14)
    line(d, (188, 393, 157, 423, 137, 437), CARBON, 14)
    line(d, (190, 392, 207, 429, 225, 443), CARBON, 14)
    line(d, (80, 427, 300, 427), HAIR, 2)
    # Speech status is a quiet hairline row, not another card or live-region ticker.
    line(d, (20, 511, 373, 511), "#494945")
    if muted:
        status = "ЗВУК ТРЕНИРОВКИ ВЫКЛЮЧЕН"
    elif voiceover:
        status = "VOICEOVER · МУЗЫКА ПРИГЛУШЕНА"
    else:
        status = "ГОЛОСОВАЯ ПОДСКАЗКА · РАЗ"
    text(d, (20, 528), status, 10, "#C7C7C3", bold=True)
    line(d, (20, 552, 373, 552), "#494945")
    text(d, (20, 578), "0:28", 60, WHITE, bold=True, mono=True)
    text(d, (268, 616), "Осталось в этом\nупражнении", 11, "#C7C7C3", bold=True, anchor="lm")
    ellipse(d, (20, 758, 78, 816), None, "#9A9A95", 1); pause_glyph(d,49,787)
    rr(d, (90, 758, 373, 816), 20, VERMILION)
    text(d, (231.5, 787), "Далее · отдых 12 сек", 15, WHITE, bold=True, anchor="mm")
    return im


def contact_sheet(items):
    cols, rows = 3, 2
    tw, th = 236, 511
    board = Image.new("RGB", (u(830), u(1165)), CARBON)
    d = ImageDraw.Draw(board)
    text(d, (36, 34), "ABS TRAINER · AUDIO COACH", 25, WHITE, bold=True)
    text(d, (36, 72), "Темп / Срез · Setup / Plan / Player · design-only", 13, "#C7C7C3")
    for idx, (label, image) in enumerate(items):
        col, row = idx % cols, idx // cols
        x, y = 36 + col*260, 132 + row*520
        text(d, (x, y-24), label, 10, WHITE, bold=True)
        thumb = image.resize((u(196), u(426)), Image.Resampling.LANCZOS)
        board.paste(thumb, (u(x), u(y)))
    text(d, (36, 1082), "Audio remains optional · VoiceOver owns speech · Reduce Motion does not change audio", 12, "#C7C7C3")
    text(d, (36, 1111), "44 pt controls · slider 5% steps · no critical meaning is audio-only", 12, "#C7C7C3")
    return board


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    screens = [
        ("01 · SETUP / ON", setup_state(True), "01-setup-music-on.png"),
        ("02 · SETUP / OFF", setup_state(False), "02-setup-music-off.png"),
        ("03 · PLAN", plan_state(), "03-plan-audio-summary.png"),
        ("04 · PLAYER", player_state(False), "04-player-coach-speaking.png"),
        ("05 · PLAYER / MUTE", player_state(True), "05-player-muted.png"),
        ("06 · SETUP / AX3", setup_state(True, True), "06-setup-ax3.png"),
    ]
    for _, image, name in screens:
        path = OUT / name
        image.save(path, optimize=True)
        print(f"{path}: {image.width}x{image.height}")
    sheet = contact_sheet([(label, image) for label, image, _ in screens])
    path = ROOT / "ux" / "audio-controls-contact-sheet.png"
    sheet.save(path, optimize=True)
    print(f"{path}: {sheet.width}x{sheet.height}")


if __name__ == "__main__":
    main()
