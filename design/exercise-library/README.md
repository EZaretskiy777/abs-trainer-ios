# ABS Trainer Exercise Library design package

Design-only source and exports for Kanban task `t_f1d72cf8`. Production SwiftUI is intentionally unchanged.

## Review first

- `previews/index.html` — local full-size gallery
- `previews/screens-contact-sheet.png` — catalog/detail/state overview
- `previews/contact-sheet.png` — all 10 poster frames
- `previews/motion-storyboards.png` — five loop phases per exercise
- `previews/all-exercises-preview.mp4` — all 10 loops playing together
- `../../docs/exercise-library-design-handoff.md` — implementation contract and QA

## Source and exports

- `source/render_exercise_library.py` — editable original geometry, poses, motion and screen renderer
- `source/validate_assets.py` — decode/profile/hash/budget/seam validator
- `exports/` — 10 H.264 MP4 files and 10 JPG posters
- `manifest/exercise-assets.json` — measured per-id manifest
- `manifest/validation-report.txt` — latest validator result

The mannequin, motion, camera field and UI previews are original in-house work composed from geometric primitives. No stock image/video, third-party character, logo, motion template, remote URL, or external asset is included. System or locally staged fonts affect preview labels only and are not bundled as app assets.

## Reproduce

Python 3 with Pillow is required. Set `FFMPEG` to an ffmpeg binary with libx264:

```sh
FFMPEG=/path/to/ffmpeg python3 design/exercise-library/source/render_exercise_library.py
FFMPEG=/path/to/ffmpeg python3 design/exercise-library/source/validate_assets.py
```

The checked package used ffmpeg 7.0.2 supplied by `imageio-ffmpeg 0.6.0` as generation tooling only.

## Release gates

- Domain-aware human review of all 10 storyboards and Russian cues is still required.
- iOS must verify target-resource inclusion, Airplane Mode, lifecycle pause/release, Reduce Motion, VoiceOver, AX3 and representative device layouts.
- Figma transfer is pending an approved team destination.
