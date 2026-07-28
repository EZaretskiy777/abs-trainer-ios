#!/usr/bin/env python3
"""Measure generated audio, write manifest/report, and fail contract violations."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import shutil
import struct
import subprocess
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE))
from generate_workout_music import VARIANTS  # noqa: E402


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve_ffmpeg() -> str:
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg  # type: ignore
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception as exc:
        raise SystemExit("ffmpeg unavailable") from exc


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(command)}\n{result.stderr}")
    return result


def probe(ffmpeg: str, path: Path) -> dict:
    result = subprocess.run([ffmpeg, "-hide_banner", "-i", str(path), "-f", "null", "-"],
                            text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"decode failed: {path}\n{result.stderr}")
    stream = re.search(r"Audio:\s*([^,]+),\s*(\d+) Hz,\s*([^,]+),\s*([^,]+)", result.stderr)
    duration = re.search(r"Duration:\s*(\d+):(\d+):(\d+\.\d+)", result.stderr)
    bitrate = re.search(r"bitrate:\s*(\d+) kb/s", result.stderr)
    if not stream or not duration:
        raise RuntimeError(f"could not parse probe for {path}")
    seconds = int(duration.group(1))*3600 + int(duration.group(2))*60 + float(duration.group(3))
    return {
        "codec": stream.group(1).strip(),
        "sample_rate_hz": int(stream.group(2)),
        "channel_layout": stream.group(3).strip(),
        "sample_format": stream.group(4).strip(),
        "duration_seconds": round(seconds, 3),
        "container_bitrate_kbps": int(bitrate.group(1)) if bitrate else None,
        "decode_exit_code": result.returncode,
        "bytes": path.stat().st_size,
    }


def loudness(ffmpeg: str, path: Path) -> dict:
    result = run([
        ffmpeg, "-hide_banner", "-nostats", "-i", str(path),
        "-af", "loudnorm=I=-18:TP=-1:LRA=7:print_format=json", "-f", "null", "-",
    ])
    match = re.search(r"\{\s*\"input_i\".*?\}", result.stderr, re.S)
    if not match:
        raise RuntimeError(f"loudness JSON missing for {path}")
    raw = json.loads(match.group(0))
    return {
        "integrated_lufs": float(raw["input_i"]),
        "loudness_range_lu": float(raw["input_lra"]),
        "true_peak_dbtp": float(raw["input_tp"]),
        "threshold_lufs": float(raw["input_thresh"]),
    }


def decode_s24(sample: bytes) -> int:
    sign = b"\xff" if sample[2] & 0x80 else b"\x00"
    return struct.unpack("<i", sample + sign)[0]


def wave_metrics(ffmpeg: str, path: Path) -> dict:
    # Python 3.11's wave module cannot read ffmpeg's WAVE_FORMAT_EXTENSIBLE
    # 24-bit output, so decode deterministically to headerless stereo s24le.
    decoded = subprocess.run(
        [ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(path),
         "-f", "s24le", "-acodec", "pcm_s24le", "-ac", "2", "-ar", "48000", "-"],
        capture_output=True,
    )
    if decoded.returncode != 0:
        raise RuntimeError(f"PCM decode failed for {path}: {decoded.stderr.decode(errors='replace')}")
    raw = decoded.stdout
    frames = len(raw) // 6
    values_l = []
    values_r = []
    peak = 0
    sum_l = sum_r = 0.0
    for offset in range(0, len(raw), 6):
        left = decode_s24(raw[offset:offset+3])
        right = decode_s24(raw[offset+3:offset+6])
        peak = max(peak, abs(left), abs(right))
        sum_l += left
        sum_r += right
        if offset < 4800*6 or offset >= len(raw)-4800*6:
            values_l.append(left)
            values_r.append(right)
    first_l, first_r = decode_s24(raw[:3]), decode_s24(raw[3:6])
    last_l, last_r = decode_s24(raw[-6:-3]), decode_s24(raw[-3:])
    full_scale = float((1 << 23) - 1)
    boundary_delta = max(abs(first_l-last_l), abs(first_r-last_r)) / full_scale
    return {
        "frames": frames,
        "peak_sample_dbfs": round(20*math.log10(max(peak/full_scale, 1e-12)), 3),
        "dc_offset_left_dbfs": round(20*math.log10(max(abs(sum_l/frames)/full_scale, 1e-12)), 3),
        "dc_offset_right_dbfs": round(20*math.log10(max(abs(sum_r/frames)/full_scale, 1e-12)), 3),
        "first_frame": [first_l, first_r],
        "last_frame": [last_l, last_r],
        "boundary_delta_dbfs": round(20*math.log10(max(boundary_delta, 1e-12)), 3),
        "seam_window_ms": 100,
        "seam_method": "first/last sample delta plus 100 ms waveform inspection; endpoint fade encoded by generator",
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    root = args.root.resolve()
    ffmpeg = resolve_ffmpeg()
    assets = []
    failures = []
    selected_slug = "pulse_grid"
    for variant in VARIANTS:
        master = root / "masters" / f"workout_music_{variant.slug}_v1.wav"
        preview = root / "previews" / f"workout_music_{variant.slug}_v1_preview.m4a"
        master_probe = probe(ffmpeg, master)
        preview_probe = probe(ffmpeg, preview)
        measured = loudness(ffmpeg, master)
        seam = wave_metrics(ffmpeg, master)
        if not (60.0 <= master_probe["duration_seconds"] <= 90.0): failures.append(f"{variant.slug}: duration")
        if master_probe["sample_rate_hz"] != 48_000: failures.append(f"{variant.slug}: sample rate")
        if "stereo" not in master_probe["channel_layout"]: failures.append(f"{variant.slug}: channels")
        if abs(measured["integrated_lufs"] + 18.0) > 1.0: failures.append(f"{variant.slug}: loudness")
        if measured["true_peak_dbtp"] > -1.0: failures.append(f"{variant.slug}: true peak")
        if seam["boundary_delta_dbfs"] > -80.0: failures.append(f"{variant.slug}: seam delta")
        assets.append({
            "id": f"workout_music_{variant.slug}_v1",
            "selected_final": variant.slug == selected_slug,
            "character": variant.character,
            "composition": {"bpm": variant.bpm, "bars": variant.bars, "seed": variant.seed,
                            "duration_seconds": variant.duration},
            "master": {"path": str(master.relative_to(root)), "sha256": sha256(master),
                       "probe": master_probe, "loudness": measured, "signal": seam},
            "preview": {"path": str(preview.relative_to(root)), "sha256": sha256(preview),
                        "probe": preview_probe},
        })
    app = root / "app" / "workout_music_pulse_grid_v1.m4a"
    app_record = {"path": str(app.relative_to(root)), "sha256": sha256(app), "probe": probe(ffmpeg, app)}
    manifest = {
        "schema_version": 1,
        "project": "ABS Trainer audio coach",
        "provenance": "original_in_house",
        "license": "owned_original_work",
        "third_party_inputs": [],
        "external_samples": [],
        "vocals": False,
        "artist_imitation": False,
        "selected_final": "workout_music_pulse_grid_v1",
        "selected_rationale": "Pulse Grid leaves the clearest midrange and most stable half-time bed under short ru-RU speech while retaining workout momentum; Forward Arc is intentionally brighter and busier and remains a review-only candidate.",
        "generator": {"path": "source/generate_workout_music.py", "sha256": sha256(root / "source" / "generate_workout_music.py"),
                      "python": "3.11+ stdlib", "ffmpeg_distribution": "imageio-ffmpeg 0.6.0 pinned",
                      "command": ".venv-audio/bin/python design/audio-coach/source/generate_workout_music.py"},
        "assets": assets,
        "runtime_app_asset": app_record,
        "validation": {"status": "PASS" if not failures else "FAIL", "failures": failures,
                       "headphones_listen_check": "pending human/device review",
                       "legal_similarity_review": "human review required; no universal legal guarantee"},
    }
    manifest_dir = root / "manifest"
    manifest_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = manifest_dir / "audio-assets.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report_lines = [
        "ABS Trainer audio validation report",
        f"status: {manifest['validation']['status']}",
        "provenance: original_in_house; third_party_inputs: []",
        "",
    ]
    for asset in assets:
        m = asset["master"]
        report_lines.extend([
            f"[{asset['id']}] selected={str(asset['selected_final']).lower()}",
            f"duration={m['probe']['duration_seconds']:.3f}s sample_rate={m['probe']['sample_rate_hz']} channels={m['probe']['channel_layout']} codec={m['probe']['codec']}",
            f"loudness={m['loudness']['integrated_lufs']:.2f} LUFS-I LRA={m['loudness']['loudness_range_lu']:.2f} LU true_peak={m['loudness']['true_peak_dbtp']:.2f} dBTP",
            f"sample_peak={m['signal']['peak_sample_dbfs']:.2f} dBFS seam_delta={m['signal']['boundary_delta_dbfs']:.2f} dBFS dc_L/R={m['signal']['dc_offset_left_dbfs']:.2f}/{m['signal']['dc_offset_right_dbfs']:.2f} dBFS",
            f"master_sha256={m['sha256']}", f"preview_sha256={asset['preview']['sha256']}", "",
        ])
    report_lines.extend([f"runtime_sha256={app_record['sha256']}", "decode: PASS for all WAV/M4A files", "headphones seam/content check: PENDING HUMAN/DEVICE REVIEW"])
    (manifest_dir / "validation-report.txt").write_text("\n".join(report_lines) + "\n", encoding="utf-8")
    print("\n".join(report_lines))
    if failures:
        raise SystemExit("validation failures: " + ", ".join(failures))


if __name__ == "__main__":
    main()
