#!/usr/bin/env python3
"""Validate measured exercise media against the design handoff contract."""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "design" / "exercise-library"
MANIFEST_PATH = BASE / "manifest" / "exercise-assets.json"
REPORT_PATH = BASE / "manifest" / "validation-report.txt"
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
EXPECTED = {
    "crunch", "reverse_crunch", "bicycle_twist", "plank", "mountain_climber",
    "toe_touch", "leg_raise", "russian_twist", "dead_bug", "hollow_hold",
}


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def probe_video(path: Path) -> dict:
    inspect = subprocess.run([FFMPEG, "-hide_banner", "-i", str(path)], capture_output=True, text=True)
    stderr = inspect.stderr
    stream = re.search(r"Video:\s*([^,]+),\s*([^,(]+).*?(\d{2,5})x(\d{2,5}).*?(\d+(?:\.\d+)?)\s*fps", stderr)
    duration = re.search(r"Duration:\s*00:00:(\d+(?:\.\d+)?)", stderr)
    if not stream or not duration:
        raise ValueError(f"cannot parse ffmpeg probe for {path.name}")
    progress = subprocess.run(
        [FFMPEG, "-v", "error", "-i", str(path), "-map", "0:v:0", "-f", "null", "-", "-progress", "pipe:1", "-nostats"],
        capture_output=True, text=True,
    )
    if progress.returncode != 0:
        raise ValueError(f"decode failed for {path.name}: {progress.stderr.strip()}")
    frames = [int(value) for value in re.findall(r"^frame=(\d+)$", progress.stdout, re.MULTILINE)]
    return {
        "codec": stream.group(1).strip(),
        "pixel_format": stream.group(2).strip(),
        "width": int(stream.group(3)),
        "height": int(stream.group(4)),
        "fps": float(stream.group(5)),
        "duration": float(duration.group(1)),
        "frames": max(frames) if frames else 0,
        "has_audio": "Audio:" in stderr,
    }


def decode_frame(path: Path, frame: int, output: Path) -> Image.Image:
    result = subprocess.run([
        FFMPEG, "-v", "error", "-i", str(path), "-vf", f"select=eq(n\\,{frame})",
        "-frames:v", "1", "-y", str(output),
    ], capture_output=True, text=True)
    if result.returncode != 0 or not output.exists():
        raise ValueError(f"frame {frame} decode failed for {path.name}: {result.stderr.strip()}")
    with Image.open(output) as image:
        return image.convert("RGB").copy()


def validate() -> tuple[list[str], list[str]]:
    data = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    errors: list[str] = []
    lines: list[str] = []
    assets = data.get("assets", [])
    ids = [item.get("exercise_id") for item in assets]
    if len(assets) != 10 or set(ids) != EXPECTED or len(ids) != len(set(ids)):
        errors.append(f"manifest id set/count invalid: count={len(assets)} ids={ids}")
    total = 0
    with tempfile.TemporaryDirectory(prefix="exercise-asset-qa-") as temporary:
        temp = Path(temporary)
        for item in assets:
            exercise_id = item["exercise_id"]
            video = ROOT / item["video"]["path"]
            poster = ROOT / item["poster"]["path"]
            item_errors: list[str] = []
            if not video.is_file() or not poster.is_file():
                errors.append(f"{exercise_id}: missing video or poster")
                continue
            try:
                measured = probe_video(video)
                with Image.open(poster) as image:
                    poster_size = image.size
                    image.verify()
                first = decode_frame(video, 0, temp / f"{exercise_id}-first.png")
                last = decode_frame(video, 119, temp / f"{exercise_id}-last.png")
                difference = ImageChops.difference(first, last)
                stats = ImageStat.Stat(difference)
                seam_rms = (sum(value * value for value in stats.rms) / len(stats.rms)) ** 0.5
            except Exception as exc:
                errors.append(f"{exercise_id}: decode/probe error: {exc}")
                continue
            expected_video = item["video"]
            expected_poster = item["poster"]
            checks = {
                "codec": measured["codec"].startswith("h264"),
                "pixel_format": measured["pixel_format"] == "yuv420p",
                "dimensions": (measured["width"], measured["height"]) == (720, 720),
                "fps": abs(measured["fps"] - 30) < 0.01,
                "duration": abs(measured["duration"] - 4.0) <= 0.1,
                "frames": measured["frames"] == 120,
                "no_audio": not measured["has_audio"],
                "poster": poster_size == (720, 720),
                "video_budget": video.stat().st_size <= 1_200_000,
                "poster_budget": poster.stat().st_size <= 140_000,
                "video_size_manifest": video.stat().st_size == expected_video["size_bytes"],
                "poster_size_manifest": poster.stat().st_size == expected_poster["size_bytes"],
                "video_hash": digest(video) == expected_video["sha256"],
                "poster_hash": digest(poster) == expected_poster["sha256"],
                "loop_seam": seam_rms <= 2.5,
                "provenance": item["source"]["provenance"] == "original_in_house" and item["source"]["license"] == "owned_original_work" and item["source"]["third_party_inputs"] == [],
                "qa_review": item["qa"]["visual_review"].startswith("pass") and item["qa"]["seam_review"].startswith("pass") and item["qa"]["storyboard_review"].startswith("pass") and item["qa"]["reduce_motion_poster_review"] == "pass",
            }
            item_errors.extend(name for name, passed in checks.items() if not passed)
            total += video.stat().st_size + poster.stat().st_size
            status = "PASS" if not item_errors else "FAIL[" + ",".join(item_errors) + "]"
            lines.append(
                f"{exercise_id:18} {status:20} video={video.stat().st_size:7} poster={poster.stat().st_size:6} "
                f"{measured['width']}x{measured['height']} {measured['fps']:.0f}fps {measured['frames']}f {measured['duration']:.2f}s "
                f"audio={measured['has_audio']} seam_rms={seam_rms:.3f}"
            )
            errors.extend(f"{exercise_id}: {name}" for name in item_errors)
    if total > 13_400_000:
        errors.append(f"total hard budget exceeded: {total}")
    if total > 10_000_000:
        errors.append(f"total target budget exceeded: {total}")
    lines.append(f"TOTAL {total} bytes ({total / 1_000_000:.3f} MB) target<=10.000MB hard<=13.400MB")
    return lines, errors


def main() -> None:
    lines, errors = validate()
    report = ["ABS Trainer exercise media validation", "", *lines, "", f"RESULT: {'FAIL' if errors else 'PASS'}"]
    if errors:
        report.extend(["", "Errors:", *[f"- {item}" for item in errors]])
    REPORT_PATH.write_text("\n".join(report) + "\n", encoding="utf-8")
    print("\n".join(report))
    raise SystemExit(1 if errors else 0)


if __name__ == "__main__":
    main()
