#!/usr/bin/env python3
"""Render inspectable waveform evidence from generated masters."""
from __future__ import annotations

import json
import shutil
import struct
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "manifest" / "audio-assets.json"
OUT = ROOT / "previews"
W, H = 1600, 980
CARBON = "#171714"
CHALK = "#F5F1E8"
MUTED = "#A8A79F"
VERMILION = "#D13A25"
ULTRAMARINE = "#4865E5"
HAIR = "#494945"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(size, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT, size)


def text(d, xy, value, size, fill=CHALK, bold=False, anchor=None):
    d.text(xy, value, font=font(size, bold), fill=fill, anchor=anchor)


def ffmpeg_exe():
    found = shutil.which("ffmpeg")
    if found:
        return found
    import imageio_ffmpeg  # type: ignore
    return imageio_ffmpeg.get_ffmpeg_exe()


def peaks(path: Path, bins=1420):
    result = subprocess.run([ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-i", str(path),
                             "-f", "s16le", "-acodec", "pcm_s16le", "-ac", "2", "-ar", "48000", "-"],
                            capture_output=True, check=True)
    raw = result.stdout
    frames = len(raw) // 4
    stride = max(1, frames // bins)
    channels = [[0.0, 0.0] for _ in range(bins)]
    for b in range(bins):
        lo_l = lo_r = 32767
        hi_l = hi_r = -32768
        start = b * stride * 4
        end = min(len(raw), (b + 1) * stride * 4)
        for offset in range(start, end, 4):
            left, right = struct.unpack_from("<hh", raw, offset)
            lo_l, hi_l = min(lo_l, left), max(hi_l, left)
            lo_r, hi_r = min(lo_r, right), max(hi_r, right)
        channels[b] = [lo_l / 32768, hi_l / 32768, lo_r / 32768, hi_r / 32768]
    return channels


def draw_wave(d, data, box, color):
    x1, y1, x2, y2 = box
    mid_l = y1 + (y2-y1)*.28
    mid_r = y1 + (y2-y1)*.72
    amp = (y2-y1)*.21
    d.line((x1, mid_l, x2, mid_l), fill=HAIR, width=1)
    d.line((x1, mid_r, x2, mid_r), fill=HAIR, width=1)
    for idx, (lo_l, hi_l, lo_r, hi_r) in enumerate(data):
        x = round(x1 + idx * (x2-x1) / max(1, len(data)-1))
        d.line((x, mid_l-hi_l*amp, x, mid_l-lo_l*amp), fill=color, width=1)
        d.line((x, mid_r-hi_r*amp, x, mid_r-lo_r*amp), fill=color, width=1)
    text(d, (x1+8, mid_l-amp+4), "L", 16, MUTED)
    text(d, (x1+8, mid_r-amp+4), "R", 16, MUTED)


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    image = Image.new("RGB", (W, H), CARBON)
    d = ImageDraw.Draw(image)
    text(d, (70, 54), "ABS TRAINER · ORIGINAL AUDIO LOOPS", 34, bold=True)
    text(d, (70, 104), "48 kHz stereo · procedural synthesis only · no external samples", 20, MUTED)
    colors = [VERMILION, ULTRAMARINE]
    for index, asset in enumerate(manifest["assets"]):
        top = 170 + index * 350
        selected = "  ·  SELECTED FINAL" if asset["selected_final"] else "  ·  CANDIDATE"
        text(d, (70, top), asset["id"].replace("workout_music_", "").replace("_v1", "").upper() + selected,
             24, colors[index], bold=True)
        composition = asset["composition"]
        measured = asset["master"]["loudness"]
        text(d, (70, top+42), f"{composition['duration_seconds']:.0f}s  ·  {composition['bpm']} BPM  ·  seed {composition['seed']}", 18, MUTED)
        text(d, (1530, top+42), f"{measured['integrated_lufs']:.2f} LUFS-I  ·  {measured['true_peak_dbtp']:.2f} dBTP",
             18, CHALK, anchor="ra")
        data = peaks(ROOT / asset["master"]["path"])
        draw_wave(d, data, (70, top+82, 1530, top+285), colors[index])
        signal = asset["master"]["signal"]
        text(d, (70, top+305), f"Seam Δ {signal['boundary_delta_dbfs']:.2f} dBFS  ·  DC {signal['dc_offset_left_dbfs']:.2f}/{signal['dc_offset_right_dbfs']:.2f} dBFS", 16, MUTED)
    d.line((70, 886, 1530, 886), fill=HAIR, width=1)
    text(d, (70, 910), "Selected: Pulse Grid — stable half-time bed and clearer midrange for ru-RU coaching speech.", 19, CHALK)
    text(d, (70, 944), "Listen: previews/*.m4a · Measurements: manifest/validation-report.txt", 16, MUTED)
    OUT.mkdir(parents=True, exist_ok=True)
    output = OUT / "waveform-contact-sheet.png"
    image.save(output, optimize=True)
    print(f"{output}: {image.width}x{image.height} {output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
