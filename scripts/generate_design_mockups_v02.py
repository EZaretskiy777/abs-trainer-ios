#!/usr/bin/env python3
"""Generate deterministic high-fidelity v0.2 PNG mockups for ABS Trainer iOS.

The artifacts are intentionally local/offline so the project can keep moving
without external design SaaS credentials. They are not a replacement for final
Figma handoff, but they provide aligned, reviewable Apple/Fitness-like screens.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path("design/assets/mockups")
W, H = 1290, 2796  # iPhone 15 Pro logical 3x-ish canvas
BG = "#05070A"
CARD = "#111827"
CARD2 = "#172033"
GREEN = "#34D399"
CYAN = "#38BDF8"
AMBER = "#F59E0B"
TEXT = "#F8FAFC"
MUTED = "#94A3B8"
BORDER = "#263244"


def font(size, bold=False):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for c in candidates:
        try:
            return ImageFont.truetype(c, size)
        except OSError:
            pass
    return ImageFont.load_default()


def rr(draw, xy, r, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)


def text(draw, xy, value, size=44, color=TEXT, bold=False, anchor=None):
    draw.text(xy, value, font=font(size, bold), fill=color, anchor=anchor)


def base(title, subtitle):
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # subtle top glow
    for i in range(220):
        alpha = int(65 * (1 - i / 220))
        col = (10, 40 + alpha // 3, 32 + alpha // 4)
        d.ellipse((180 - i*3, -520 - i, 1110 + i*3, 620 + i), outline=col)
    text(d, (72, 112), "ABS Trainer", 62, TEXT, True)
    text(d, (72, 190), subtitle, 34, MUTED)
    return im, d


def bottom_nav(d, active="Workout"):
    rr(d, (72, 2588, 1218, 2708), 60, "#0B111C", BORDER, 2)
    items = ["Plan", "Workout", "Progress"]
    x = [260, 645, 1030]
    for label, cx in zip(items, x):
        color = GREEN if label == active else MUTED
        if label == active:
            rr(d, (cx-135, 2614, cx+135, 2682), 34, "#123328")
        text(d, (cx, 2648), label, 30, color, True, "mm")


def chip(d, x, y, label, active=True, w=250):
    rr(d, (x, y, x+w, y+84), 42, "#123328" if active else CARD2, GREEN if active else BORDER, 2)
    text(d, (x+w/2, y+42), label, 30, GREEN if active else MUTED, True, "mm")


def home():
    im, d = base("Home", "Local core workouts, no account")
    rr(d, (72, 300, 1218, 760), 42, CARD, BORDER, 2)
    text(d, (120, 366), "Build your abs session", 54, TEXT, True)
    text(d, (120, 440), "Choose duration and target zones.", 34, MUTED)
    text(d, (120, 540), "10", 104, GREEN, True)
    text(d, (300, 590), "starter exercises", 34, MUTED)
    text(d, (120, 680), "3D placeholders ready for asset swap", 30, CYAN)

    text(d, (72, 870), "Duration", 38, TEXT, True)
    for idx, (lab, active) in enumerate([("5 min", False), ("10 min", True), ("15 min", False)]):
        chip(d, 72 + idx*390, 930, lab, active, 330)

    text(d, (72, 1118), "Target zones", 38, TEXT, True)
    chip(d, 72, 1180, "Upper", True, 330)
    chip(d, 432, 1180, "Lower", True, 330)
    chip(d, 792, 1180, "Obliques", True, 360)

    rr(d, (72, 1390, 1218, 2085), 48, CARD, BORDER, 2)
    text(d, (120, 1460), "Today’s focus", 44, TEXT, True)
    for n, row in enumerate([("Dead Bug", "Lower • 40 sec", GREEN), ("Bicycle Crunch", "Obliques • 45 sec", CYAN), ("Plank", "Full core • 60 sec", AMBER)]):
        y = 1565 + n*150
        rr(d, (120, y, 1170, y+112), 30, CARD2, BORDER, 1)
        text(d, (160, y+34), row[0], 34, TEXT, True)
        text(d, (160, y+78), row[1], 26, MUTED)
        d.ellipse((1080, y+34, 1124, y+78), fill=row[2])
    rr(d, (72, 2240, 1218, 2372), 66, GREEN)
    text(d, (645, 2306), "Generate workout", 42, "#03110C", True, "mm")
    bottom_nav(d, "Plan")
    im.save(OUT / "abs-trainer-hifi-v02-home.png")


def workout():
    im, d = base("Workout", "10 min • Upper + Lower + Obliques")
    rr(d, (72, 300, 1218, 500), 44, CARD, BORDER, 2)
    text(d, (120, 365), "Generated plan", 52, TEXT, True)
    text(d, (120, 430), "8 intervals • balanced rotation", 30, MUTED)
    rows = [("Dead Bug", "40s", "Lower", GREEN), ("Reverse Crunch", "35s", "Lower", GREEN), ("Bicycle Crunch", "45s", "Obliques", CYAN), ("Toe Reach", "35s", "Upper", AMBER), ("Plank Hold", "60s", "Full core", GREEN)]
    y = 610
    for name, sec, zone, col in rows:
        rr(d, (72, y, 1218, y+170), 38, CARD, BORDER, 2)
        d.ellipse((120, y+52, 186, y+118), fill=col)
        text(d, (224, y+48), name, 40, TEXT, True)
        text(d, (224, y+102), zone, 28, MUTED)
        text(d, (1120, y+85), sec, 42, col, True, "mm")
        y += 202
    rr(d, (72, 2180, 1218, 2312), 66, GREEN)
    text(d, (645, 2246), "Start session", 42, "#03110C", True, "mm")
    bottom_nav(d, "Workout")
    im.save(OUT / "abs-trainer-hifi-v02-workout.png")


def player():
    im, d = base("Player", "Exercise 3 of 8")
    rr(d, (72, 320, 1218, 1360), 54, "#0A1320", BORDER, 2)
    rr(d, (152, 410, 1138, 1190), 44, CARD2, "#2B3A50", 2)
    # abstract aligned 3D placeholder
    d.ellipse((430, 560, 860, 990), outline=CYAN, width=12)
    d.line((500, 930, 790, 650), fill=GREEN, width=18)
    d.line((790, 650, 930, 760), fill=GREEN, width=18)
    d.line((650, 780, 830, 1010), fill=AMBER, width=18)
    text(d, (645, 1255), "3D motion placeholder", 32, MUTED, False, "mm")
    text(d, (72, 1480), "Bicycle Crunch", 58, TEXT, True)
    text(d, (72, 1552), "Obliques • keep shoulders relaxed", 34, MUTED)
    text(d, (645, 1788), "00:32", 148, TEXT, True, "mm")
    rr(d, (170, 1960, 1120, 1990), 15, CARD2)
    rr(d, (170, 1960, 735, 1990), 15, GREEN)
    rr(d, (72, 2140, 575, 2272), 66, CARD2, BORDER, 2)
    text(d, (323, 2206), "Pause", 40, TEXT, True, "mm")
    rr(d, (615, 2140, 1218, 2272), 66, GREEN)
    text(d, (916, 2206), "Next", 40, "#03110C", True, "mm")
    bottom_nav(d, "Workout")
    im.save(OUT / "abs-trainer-hifi-v02-player.png")


def finish():
    im, d = base("Finish", "Session complete")
    d.ellipse((395, 410, 895, 910), fill="#123328", outline=GREEN, width=8)
    text(d, (645, 660), "✓", 220, GREEN, True, "mm")
    text(d, (645, 1040), "Great work", 74, TEXT, True, "mm")
    text(d, (645, 1110), "You completed 8 core intervals", 34, MUTED, False, "mm")
    for idx, (a, b, col) in enumerate([("10:00", "total time", GREEN), ("8", "exercises", CYAN), ("3", "zones", AMBER)]):
        x0 = 72 + idx*390
        rr(d, (x0, 1290, x0+330, 1510), 42, CARD, BORDER, 2)
        text(d, (x0+165, 1370), a, 54, col, True, "mm")
        text(d, (x0+165, 1440), b, 28, MUTED, False, "mm")
    rr(d, (72, 1760, 1218, 1892), 66, GREEN)
    text(d, (645, 1826), "Repeat workout", 42, "#03110C", True, "mm")
    rr(d, (72, 1930, 1218, 2062), 66, CARD2, BORDER, 2)
    text(d, (645, 1996), "New workout", 40, TEXT, True, "mm")
    rr(d, (72, 2240, 1218, 2408), 40, CARD, BORDER, 2)
    text(d, (120, 2300), "Future: premium progress insights", 34, MUTED)
    bottom_nav(d, "Progress")
    im.save(OUT / "abs-trainer-hifi-v02-finish.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for fn in [home, workout, player, finish]:
        fn()
    print("Generated v0.2 mockups:")
    for p in sorted(OUT.glob("abs-trainer-hifi-v02-*.png")):
        print(f"- {p} ({p.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
