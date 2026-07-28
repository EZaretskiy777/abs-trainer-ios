# ABS Trainer audio coach assets

Developer-ready design/audio package for `t_855239fc`.

## Selected runtime asset

`app/workout_music_pulse_grid_v1.m4a`

Only this M4A should enter the app bundle. Masters and the unselected candidate are design/release evidence.

## Contents

- `source/generate_workout_music.py` — deterministic synthesis; no samples or external audio inputs.
- `source/validate_audio.py` — decode/loudness/peak/DC/seam measurement and manifest writer.
- `source/render_waveforms.py` — waveform contact sheet.
- `source/render_audio_ux.py` — design-only Setup/Plan/Player PNG renderer.
- `masters/` — two 48 kHz stereo 24-bit WAV candidates.
- `previews/` — two listenable AAC-LC M4A previews and waveform sheet.
- `app/` — selected app-size AAC-LC M4A.
- `manifest/` — provenance, seeds, SHA-256, measured and byte-reproducibility reports.
- `ux/` — high-fidelity states and contact sheet.

Full iOS/UX contract: `../../docs/audio-coach-design-handoff.md`.

## Reproduce audio

```bash
python3 -m venv .venv-audio
.venv-audio/bin/pip install imageio-ffmpeg==0.6.0
.venv-audio/bin/python design/audio-coach/source/generate_workout_music.py
.venv-audio/bin/python design/audio-coach/source/validate_audio.py
```

Seeds:

- Pulse Grid: `85523901`
- Forward Arc: `85523902`

The generator uses Python standard-library synthesis plus pinned ffmpeg processing/export. It reads no sample, MIDI, reference-audio, network, vocal, model or trademark input.

## Render design evidence

```bash
python3 design/audio-coach/source/render_audio_ux.py
```

For waveform rendering, put the pinned imageio-ffmpeg executable on `PATH` and use a Python environment with Pillow.

## Human gates

Before release, listen on headphones for seam/content, compare music/`ru-RU` TTS on speaker and headphones, verify VoiceOver arbitration, and perform release-owner similarity/provenance review. Automated evidence does not replace these checks.
