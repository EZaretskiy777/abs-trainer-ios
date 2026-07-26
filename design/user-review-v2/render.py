#!/usr/bin/env python3
"""Render the ABS Trainer user-review v2 design-only PNG set.

No production source is read or modified at runtime. Coordinates are logical iOS
points and exports are 2x PNGs for an iPhone 17 Pro Max portrait canvas.
"""
from __future__ import annotations

from math import cos, radians, sin
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
S = 2
W, H = 440, 956
CHALK = "#F5F1E8"
CHALK_SUBTLE = "#ECE5D8"
CARBON = "#171714"
MUTED = "#55534D"
VERMILION = "#D13A25"
ULTRAMARINE = "#2946C6"
SIGNAL = "#B74731"
WHITE = "#FFFFFF"
HAIR = "#D5D0C6"
INV_SECONDARY = "#C7D0F4"
INV_HAIR = "#697DDA"
FONT = Path("/tmp/NotoSans.ttf")
MONO = Path("/tmp/NotoSansMono.ttf")


def u(value: float) -> int:
    return round(value * S)


def f(size: float, bold: bool = False, mono: bool = False):
    path = MONO if mono else FONT
    if path.exists():
        return ImageFont.truetype(str(path), u(size))
    return ImageFont.load_default(size=u(size))


def text(d, xy, value, size, fill=CARBON, *, bold=False, mono=False, anchor=None, spacing=4, align="left", stroke=0):
    d.multiline_text(
        (u(xy[0]), u(xy[1])), value, font=f(size, bold, mono), fill=fill,
        anchor=anchor, spacing=u(spacing), align=align,
        stroke_width=stroke if bold else 0, stroke_fill=fill,
    )


def rr(d, box, radius, fill=None, outline=None, width: float = 1):
    d.rounded_rectangle(tuple(u(v) for v in box), radius=u(radius), fill=fill, outline=outline, width=max(1, u(width)))


def line(d, points, fill, width: float = 1, joint=None):
    d.line(tuple(u(v) for v in points), fill=fill, width=max(1, u(width)), joint=joint)


def ellipse(d, box, fill=None, outline=None, width: float = 1):
    d.ellipse(tuple(u(v) for v in box), fill=fill, outline=outline, width=max(1, u(width)))


def status(d, light=False):
    color = WHITE if light else CARBON
    text(d, (22, 20), "9:41", 15, color, bold=True)
    text(d, (378, 20), "5G", 14, color, bold=True, anchor="ra")
    rr(d, (389, 22, 416, 34), 3, None, color, 1.5)
    rr(d, (392, 25, 411, 31), 1, color)


def pause_glyph(d, cx, cy, color=WHITE):
    rr(d, (cx - 7, cy - 10, cx - 3, cy + 10), 1.5, color)
    rr(d, (cx + 3, cy - 10, cx + 7, cy + 10), 1.5, color)


def repeat_glyph(d, cx, cy, color=WHITE):
    # Compact counter-clockwise repeat mark, drawn to avoid font-glyph fallback.
    bbox = tuple(u(v) for v in (cx - 10, cy - 10, cx + 10, cy + 10))
    d.arc(bbox, start=35, end=325, fill=color, width=u(2.5))
    line(d, (cx - 10, cy - 4, cx - 10, cy + 5, cx - 2, cy + 4), color, 2.5, "curve")


def home_indicator(d, light=False):
    fill = WHITE if light else CARBON
    rr(d, (161, 940, 279, 945), 3, fill)


def arrow(d, x, y, color=WHITE):
    line(d, (x - 12, y, x + 5, y), color, 2.5)
    line(d, (x, y - 5, x + 5, y, x, y + 5), color, 2.5, "curve")


def check(d, cx, cy, size, color=CARBON, width=8):
    line(d, (cx - size * .34, cy + size * .02, cx - size * .08, cy + size * .26, cx + size * .38, cy - size * .30), color, width, "curve")


def section_header(d, y, title_value, helper):
    text(d, (22, y), title_value, 20, CARBON, bold=True)
    text(d, (418, y + 4), helper, 13, MUTED, bold=True, anchor="ra")


def dial(d, center=(220, 426), diameter=204, value=10):
    cx, cy = center
    r = diameter / 2 - 16
    start, end = 135, 405
    frac = {5: 0, 10: .5, 15: 1}[value]
    bbox = tuple(u(v) for v in (cx-r, cy-r, cx+r, cy+r))
    d.arc(bbox, start=start, end=end, fill=HAIR, width=u(10))
    d.arc(bbox, start=start, end=start + 270*frac, fill=VERMILION, width=u(10))
    for a in (start, 270, end):
        p1 = (cx + cos(radians(a))*(r-12), cy + sin(radians(a))*(r-12))
        p2 = (cx + cos(radians(a))*(r+12), cy + sin(radians(a))*(r+12))
        line(d, (*p1, *p2), CARBON, 2)
    a = start + 270*frac
    hx, hy = cx + cos(radians(a))*r, cy + sin(radians(a))*r
    ellipse(d, (hx-15, hy-15, hx+15, hy+15), CHALK)
    ellipse(d, (hx-12, hy-12, hx+12, hy+12), CARBON)
    text(d, (cx, cy-11), str(value), 54, CARBON, bold=True, mono=True, anchor="mm")
    text(d, (cx, cy+32), "МИНУТ", 11, MUTED, bold=True, anchor="mm")
    for x, symbol in ((152, "−"), (288, "+")):
        ellipse(d, (x-26, cy+110, x+26, cy+162), CHALK, HAIR, 1.2)
        text(d, (x, cy+136), symbol, 22, CARBON, bold=True, anchor="mm")


def setup_screen():
    im = Image.new("RGB", (u(W), u(H)), CHALK); d = ImageDraw.Draw(im)
    status(d)
    text(d, (22, 76), "ЛОКАЛЬНАЯ ТРЕНИРОВКА", 11, VERMILION, bold=True)
    text(d, (22, 99), "Соберите\nсвой темп", 42, CARBON, bold=True, spacing=-3)
    text(d, (22, 198), "Выберите длительность и нагрузку.\nПлан будет готов без регистрации.", 16, MUTED, spacing=3)
    section_header(d, 262, "Сколько времени?", "10 минут")
    dial(d, (220, 392), 196, 10)
    section_header(d, 596, "Куда нагрузка?", "Можно несколько")
    labels = ["Верхний пресс", "Нижний пресс", "Косые мышцы", "Весь пресс"]
    for i, label in enumerate(labels):
        row, col = divmod(i, 2); x=22+col*202; y=634+row*68; selected=i==3
        rr(d, (x,y,x+194,y+60), 12, ULTRAMARINE if selected else CHALK, ULTRAMARINE if selected else HAIR, 1)
        text(d, (x+14,y+(12 if selected else 20)), label, 13.5, WHITE if selected else CARBON, bold=True)
        if selected: text(d, (x+14,y+36), "ВЫБРАНО", 9, "#DDE3FF", bold=True)
    rr(d, (22, 858, 418, 922), 20, CARBON)
    text(d, (42, 890), "Собрать тренировку", 17, WHITE, bold=True, anchor="lm")
    arrow(d, 390, 890)
    home_indicator(d)
    return im


def tempo_rail(d, y, total=8, current=2):
    gap=5; width=(396-gap*(total-1))/total
    for i in range(total):
        x=22+i*(width+gap)
        color=VERMILION if i<current else WHITE if i==current else "#555550"
        rr(d,(x,y,x+width,y+5),3,color)


def media_aperture(d, y=242):
    rr(d,(22,y,418,y+290),28,CHALK)
    rr(d,(38,y+18,169,y+48),15,None,HAIR,1)
    text(d,(52,y+28),"ДЕМО ДВИЖЕНИЯ",10,CARBON,bold=True)
    ellipse(d,(151,y+62,289,y+200),None,HAIR,1)
    # Original flat exercise cue, not copied reference anatomy artwork.
    ellipse(d,(258,y+92,300,y+134),VERMILION)
    line(d,(273,y+134,236,y+180,218,y+240),CARBON,16,"curve")
    line(d,(240,y+160,188,y+146,160,y+129),ULTRAMARINE,12,"curve")
    line(d,(239,y+164,284,y+196,312,y+222),CARBON,16,"curve")
    line(d,(224,y+203,185,y+247,155,y+268),CARBON,17,"curve")
    line(d,(224,y+203,242,y+247,267,y+271),CARBON,17,"curve")
    line(d,(120,y+245,320,y+245),HAIR,2)
    text(d,(220,y+264),"Поясница прижата · локоть тянется к колену",12,CARBON,bold=True,anchor="ma",align="center")


def active_base():
    im=Image.new("RGB",(u(W),u(H)),CARBON); d=ImageDraw.Draw(im)
    status(d,True)
    text(d,(28,83),"×",33,WHITE,anchor="mm")
    text(d,(220,83),"03 / 08",15,WHITE,bold=True,mono=True,anchor="mm")
    tempo_rail(d,119)
    text(d,(22,151),"Велосипед\nс поворотом",31,WHITE,bold=True,spacing=-2)
    text(d,(418,198),"КОСЫЕ",11,"#B8B8B3",bold=True,anchor="ra")
    media_aperture(d,235)
    text(d,(22,574),"0:28",68,WHITE,bold=True,mono=True)
    text(d,(304,615),"Осталось в этом\nупражнении",12,"#C7C7C3",bold=True,spacing=2,anchor="lm")
    ellipse(d,(22,860,82,920),None,"#9A9A95",1.2)
    pause_glyph(d,52,890)
    rr(d,(96,860,418,920),20,VERMILION)
    text(d,(257,890),"Далее · отдых 12 сек",17,WHITE,bold=True,anchor="mm")
    home_indicator(d,True)
    return im


def rest_screen():
    im=Image.new("RGB",(u(W),u(H)),ULTRAMARINE); d=ImageDraw.Draw(im)
    status(d,True)
    text(d,(22,91),"ПАУЗА МЕЖДУ УПРАЖНЕНИЯМИ",11,INV_SECONDARY,bold=True)
    text(d,(22,122),"Вдох.\nМедленный\nвыдох.",48,WHITE,bold=True,spacing=-4)
    text(d,(22,330),"12",112,WHITE,bold=True,mono=True)
    line(d,(22,510,103,510),WHITE,2); line(d,(103,510,418,510),INV_HAIR,2)
    line(d,(22,744,418,744),INV_HAIR,1)
    text(d,(22,766),"ДАЛЬШЕ · 04 ИЗ 08",11,INV_SECONDARY,bold=True)
    text(d,(22,797),"Планка",21,WHITE,bold=True)
    text(d,(418,797),"0:45",20,WHITE,bold=True,mono=True,anchor="ra")
    line(d,(22,836,418,836),INV_HAIR,1)
    rr(d,(22,854,418,918),20,None,"#A3B0EA",1.5)
    text(d,(220,886),"Пропустить отдых",17,WHITE,bold=True,anchor="mm")
    home_indicator(d,True)
    return im


def finish_screen():
    im=Image.new("RGB",(u(W),u(H)),CHALK); d=ImageDraw.Draw(im)
    status(d)
    text(d,(22,90),"ТРЕНИРОВКА ЗАВЕРШЕНА",11,VERMILION,bold=True)
    ellipse(d,(22,132,174,284),None,VERMILION,18); check(d,98,208,62,CARBON,8)
    text(d,(22,321),"Темп\nвыдержан.",43,CARBON,bold=True,spacing=-3)
    text(d,(22,426),"Все упражнения выполнены. Результат\nсохранён только на этом устройстве.",16,MUTED,spacing=3)
    line(d,(22,499,418,499),HAIR,1)
    line(d,(220,499,220,590),HAIR,1)
    text(d,(22,520),"10:04",30,CARBON,bold=True,mono=True)
    text(d,(22,560),"фактическое время",12,MUTED)
    text(d,(244,520),"8 / 8",30,CARBON,bold=True,mono=True)
    text(d,(244,560),"упражнений",12,MUTED)
    line(d,(22,590,418,590),HAIR,1)
    rr(d,(22,830,418,894),20,CARBON)
    # Balanced 44/flexible/44 contract: label center equals button center.
    text(d,(220,862),"Повторить тренировку",16.5,WHITE,bold=True,anchor="mm")
    repeat_glyph(d,386,862)
    text(d,(220,919),"Настроить новую",16,CARBON,bold=True,anchor="mm")
    home_indicator(d)
    return im


def confirmation_screen():
    base=active_base().convert("RGBA")
    overlay=Image.new("RGBA",base.size,(0,0,0,163)); base.alpha_composite(overlay)
    d=ImageDraw.Draw(base)
    # Flat opaque product modal; no system material/blur.
    rr(d,(34,250,406,694),28,CHALK)
    ellipse(d,(192,280,248,336),CHALK_SUBTLE)
    rr(d,(210,298,230,318),4,SIGNAL)
    text(d,(220,369),"Завершить тренировку?",24,CARBON,bold=True,anchor="mm")
    text(d,(220,415),"Прогресс этой сессии\nне сохранится.",17,MUTED,anchor="mm",align="center",spacing=4)
    rr(d,(58,480,382,542),20,CARBON)
    text(d,(220,511),"Продолжить тренировку",16,WHITE,bold=True,anchor="mm")
    rr(d,(58,554,382,612),20,CHALK,SIGNAL,1.2)
    text(d,(220,583),"Завершить тренировку",16,SIGNAL,bold=True,anchor="mm")
    text(d,(220,646),"Касание вне окна ничего не делает",11,MUTED,anchor="mm")
    return base.convert("RGB")


def contact_sheet(items):
    thumb_w, thumb_h = 220, 478
    board=Image.new("RGB",(u(1216),u(1110)),CARBON); d=ImageDraw.Draw(board)
    text(d,(48,42),"ABS TRAINER · USER REVIEW V2",28,WHITE,bold=True)
    text(d,(48,84),"Темп / Срез · единый high-fidelity набор · iPhone 17 Pro Max",15,"#C7C7C3")
    slots=[(48,150),(300,150),(552,150),(804,150),(930,150)]
    # Five equal thumbnails fit by using 196-point rendered width.
    for (label,im),(x,y) in zip(items,slots):
        ratio=(196*S)/im.width
        thumb=im.resize((round(im.width*ratio),round(im.height*ratio)),Image.Resampling.LANCZOS)
        board.paste(thumb,(u(x),u(y)))
        text(d,(x,y-28),label,12,WHITE,bold=True)
    text(d,(48,682),"ИСПРАВЛЕНО",12,VERMILION,bold=True)
    notes=[
        "SETUP  · Домен честный: 5/10/15 минут и зоны; intensity не выдумана.",
        "ACTIVE · Таймер и контекст имеют общую midY; pause — явный inverse-control.",
        "REST   · Весь критичный контент White; secondary 72%; outline ≥3:1.",
        "FINISH · Primary/secondary на одной оси; label primary независимо центрирован.",
        "MODAL  · Safe default перед destructive; opaque Chalk, modal focus contract.",
    ]
    for i,n in enumerate(notes): text(d,(48,714+i*36),n,15,WHITE if i else "#F5F1E8",bold=i==0)
    text(d,(48,920),"COMPACT / AX3",12,ULTRAMARINE,bold=True)
    text(d,(48,952),"Intrinsic height + scroll; horizontal text pairs switch to vertical; CTA stays in safeAreaInset.",14,"#C7C7C3")
    text(d,(48,980),"At AX3 essential copy wraps; ring/media may shrink; modal body scrolls before actions clip.",14,"#C7C7C3")
    text(d,(48,1030),"Design-only approval checkpoint · Production SwiftUI unchanged",13,"#8F8F89")
    return board


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    screens=[
        ("01 · НАСТРОЙКА",setup_screen(),"01-setup.png"),
        ("02 · УПРАЖНЕНИЕ",active_base(),"02-active.png"),
        ("03 · ОТДЫХ",rest_screen(),"03-rest.png"),
        ("04 · ЗАВЕРШЕНИЕ",finish_screen(),"04-finish.png"),
        ("05 · ПОДТВЕРЖДЕНИЕ",confirmation_screen(),"05-confirmation.png"),
    ]
    for _,im,name in screens:
        path=OUT/name; im.save(path,optimize=True); print(f"{path}: {im.width}x{im.height} {path.stat().st_size} bytes")
    board=contact_sheet([(label,im) for label,im,_ in screens])
    path=OUT/"contact-sheet.png"; board.save(path,optimize=True); print(f"{path}: {board.width}x{board.height} {path.stat().st_size} bytes")

if __name__=="__main__":
    main()
