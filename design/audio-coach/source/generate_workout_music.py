#!/usr/bin/env python3
"""Generate original ABS Trainer workout loops from synthesis only.

No samples, MIDI files, model outputs, network inputs, or reference audio are read.
The only variable input is the integer seed recorded in the manifest.
"""
from __future__ import annotations

import argparse
import math
import random
import shutil
import struct
import subprocess
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

SAMPLE_RATE = 48_000
CHANNELS = 2
SAMPLE_WIDTH = 3
TARGET_LUFS = -18.0
TRUE_PEAK_LIMIT = -1.3


@dataclass(frozen=True)
class Variant:
    slug: str
    seed: int
    bpm: int
    bars: int
    root_hz: float
    progression: tuple[tuple[int, int, int], ...]
    bass_pattern: tuple[int, ...]
    lead_pattern: tuple[int | None, ...]
    character: str

    @property
    def duration(self) -> float:
        return self.bars * 4 * 60.0 / self.bpm


VARIANTS = (
    Variant(
        slug="pulse_grid",
        seed=85523901,
        bpm=120,
        bars=32,
        root_hz=65.406,  # C2; descriptive pitch constant, not external content.
        progression=((0, 3, 7), (-2, 3, 7), (-4, 0, 5), (-5, 0, 3)),
        bass_pattern=(0, 0, 7, 0, 3, 0, 7, -2),
        lead_pattern=(12, None, 15, None, 19, None, 15, None, 12, None, 17, None, 15, None, 10, None),
        character="focused half-time pulse with open midrange for speech",
    ),
    Variant(
        slug="forward_arc",
        seed=85523902,
        bpm=128,
        bars=32,
        root_hz=73.416,  # D2.
        progression=((0, 3, 7), (5, 8, 12), (-2, 3, 7), (3, 7, 10)),
        bass_pattern=(0, 7, 0, 3, 5, 0, 7, 3),
        lead_pattern=(12, 15, None, 17, 19, None, 17, None, 15, 12, None, 10, 12, None, 15, None),
        character="brighter forward-driving syncopation and wider stereo motion",
    ),
)


def hz(root: float, semitones: int) -> float:
    return root * (2.0 ** (semitones / 12.0))


def env_decay(position: float, length: float, curve: float = 5.0) -> float:
    if position < 0.0 or position >= length:
        return 0.0
    return math.exp(-curve * position / length)


def softclip(value: float) -> float:
    return math.tanh(value * 0.92) / math.tanh(0.92)


def render_sample(variant: Variant, index: int, rng: random.Random) -> tuple[float, float]:
    t = index / SAMPLE_RATE
    beat = 60.0 / variant.bpm
    sixteenth = beat / 4.0
    bar = beat * 4.0
    duration = variant.duration
    local_bar = t % bar
    bar_index = int(t / bar)
    step_index = int(t / sixteenth)
    step_pos = t % sixteenth
    beat_pos = t % beat
    beat_index = int(t / beat)

    # Pads use periodic oscillators and short chord crossfades. Their phases are
    # fixed, so generation is deterministic and does not depend on render chunks.
    chord = variant.progression[bar_index % len(variant.progression)]
    pad = 0.0
    for tone_i, semi in enumerate(chord):
        freq = hz(variant.root_hz * 2.0, semi)
        phase = 0.17 * tone_i
        pad += math.sin(math.tau * freq * t + phase) * 0.055
        pad += math.sin(math.tau * freq * 0.5 * t + phase * 0.7) * 0.025
    # Gentle four-bar breathing, exactly periodic over the loop.
    pad *= 0.78 + 0.22 * math.sin(math.tau * t / (bar * 4.0) - math.pi / 2.0)

    # Bass: one-beat synthesized notes, low-pass character from fundamental + octave.
    bass_semi = variant.bass_pattern[beat_index % len(variant.bass_pattern)]
    bass_freq = hz(variant.root_hz, bass_semi)
    bass_env = env_decay(beat_pos, beat, 3.2) * min(1.0, beat_pos / 0.012)
    bass = (math.sin(math.tau * bass_freq * t) + 0.24 * math.sin(math.tau * bass_freq * 2.0 * t)) * 0.18 * bass_env

    # Kick on quarters with an extra restrained pickup every fourth bar.
    kick_phase = beat_pos
    kick_env = env_decay(kick_phase, 0.24, 7.0)
    kick_freq = 48.0 + 62.0 * math.exp(-kick_phase * 24.0)
    kick = math.sin(math.tau * kick_freq * kick_phase) * kick_env * 0.55
    if bar_index % 4 == 3 and local_bar >= bar - sixteenth:
        p = local_bar - (bar - sixteenth)
        kick += math.sin(math.tau * (54.0 + 35.0 * math.exp(-p * 20.0)) * p) * env_decay(p, 0.18, 7.0) * 0.22

    # Deterministic in-house noise percussion. RNG is advanced exactly twice/sample.
    noise_l = rng.random() * 2.0 - 1.0
    noise_r = rng.random() * 2.0 - 1.0
    hat_env = env_decay(step_pos, min(0.055, sixteenth), 8.5)
    hat_accent = 0.050 if step_index % 2 == 0 else 0.027
    hats_l = noise_l * hat_env * hat_accent
    hats_r = noise_r * hat_env * hat_accent
    snare = 0.0
    snare_pos = local_bar - beat if beat <= local_bar < beat + 0.22 else local_bar - 3 * beat if 3 * beat <= local_bar < 3 * beat + 0.22 else -1.0
    if snare_pos >= 0.0:
        snare_env = env_decay(snare_pos, 0.22, 5.8) * min(1.0, snare_pos / 0.006)
        snare = (0.75 * (noise_l + noise_r) * 0.5 + 0.25 * math.sin(math.tau * 184.0 * snare_pos)) * snare_env * 0.23

    # Short tonal motif; deliberately sparse to preserve TTS intelligibility.
    motif_note = variant.lead_pattern[step_index % len(variant.lead_pattern)]
    lead = 0.0
    if motif_note is not None:
        lead_freq = hz(variant.root_hz * 2.0, motif_note)
        lead_env = env_decay(step_pos, sixteenth * 0.88, 4.2) * min(1.0, step_pos / 0.008)
        lead = (math.sin(math.tau * lead_freq * t) + 0.18 * math.sin(math.tau * lead_freq * 2.0 * t)) * lead_env * 0.075

    # Stereo width comes from original synthesis/panning only, never samples.
    pan = 0.22 * math.sin(math.tau * t / (bar * 2.0))
    center = pad + bass + kick + snare
    left = center + lead * (0.78 - pan) + hats_l
    right = center + lead * (0.78 + pan) + hats_r

    # Ten-millisecond equal endpoint fade guarantees zero-valued loop endpoints.
    seam = min(1.0, t / 0.010, (duration - t) / 0.010)
    return softclip(left * seam), softclip(right * seam)


def write_s24le(raw_path: Path, variant: Variant) -> None:
    frames = round(variant.duration * SAMPLE_RATE)
    rng = random.Random(variant.seed)
    with wave.open(str(raw_path), "wb") as output:
        output.setnchannels(CHANNELS)
        output.setsampwidth(SAMPLE_WIDTH)
        output.setframerate(SAMPLE_RATE)
        block = bytearray()
        scale = (1 << 22) - 1  # conservative source headroom before loudness normalization
        for index in range(frames):
            left, right = render_sample(variant, index, rng)
            for value in (left, right):
                integer = max(-(1 << 23), min((1 << 23) - 1, round(value * scale)))
                block.extend(struct.pack("<i", integer)[:3])
            if len(block) >= 192_000:
                output.writeframesraw(block)
                block.clear()
        if block:
            output.writeframesraw(block)


def run(command: list[str]) -> None:
    completed = subprocess.run(command, text=True, capture_output=True)
    if completed.returncode != 0:
        raise RuntimeError(f"command failed ({completed.returncode}): {' '.join(command)}\n{completed.stderr}")


def resolve_ffmpeg(explicit: str | None) -> str:
    if explicit:
        return explicit
    found = shutil.which("ffmpeg")
    if found:
        return found
    try:
        import imageio_ffmpeg  # type: ignore
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception as exc:
        raise SystemExit("ffmpeg not found; install pinned imageio-ffmpeg==0.6.0") from exc


def generate_variant(ffmpeg: str, variant: Variant, output_root: Path) -> None:
    masters = output_root / "masters"
    previews = output_root / "previews"
    app = output_root / "app"
    masters.mkdir(parents=True, exist_ok=True)
    previews.mkdir(parents=True, exist_ok=True)
    app.mkdir(parents=True, exist_ok=True)
    master = masters / f"workout_music_{variant.slug}_v1.wav"
    preview = previews / f"workout_music_{variant.slug}_v1_preview.m4a"
    with tempfile.TemporaryDirectory(prefix="abs-audio-") as directory:
        raw = Path(directory) / f"{variant.slug}_raw.wav"
        write_s24le(raw, variant)
        run([
            ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(raw),
            "-af", (
                f"highpass=f=20,loudnorm=I={TARGET_LUFS}:TP={TRUE_PEAK_LIMIT}:LRA=7,"
                f"afade=t=in:st=0:d=0.01,afade=t=out:st={variant.duration - 0.01}:d=0.01"
            ),
            "-ar", str(SAMPLE_RATE), "-ac", str(CHANNELS), "-c:a", "pcm_s24le", str(master),
        ])
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i", str(master),
        "-c:a", "aac", "-profile:a", "aac_low", "-b:a", "144k", "-ar", str(SAMPLE_RATE),
        "-ac", str(CHANNELS), "-movflags", "+faststart", str(preview),
    ])
    if variant.slug == "pulse_grid":
        selected = app / "workout_music_pulse_grid_v1.m4a"
        shutil.copyfile(preview, selected)
    print(f"generated {variant.slug}: {variant.duration:.3f}s @ {variant.bpm} BPM")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--ffmpeg")
    parser.add_argument("--variant", choices=[v.slug for v in VARIANTS] + ["all"], default="all")
    args = parser.parse_args()
    ffmpeg = resolve_ffmpeg(args.ffmpeg)
    variants = VARIANTS if args.variant == "all" else tuple(v for v in VARIANTS if v.slug == args.variant)
    for variant in variants:
        generate_variant(ffmpeg, variant, args.output.resolve())


if __name__ == "__main__":
    main()
