# Design redesign brief — ABS Trainer iOS MVP v0.2

Updated: 2026-07-18T12:47:59Z
Owner: role:designer
Issue: #2
Status: corrective deliverable after rejected mockup v0.1

## Decision
The previous mockup artifact `design/assets/mockups/abs-trainer-polished-v01.png` is rejected and must not be used as A5-approved high-fidelity design.

## Redesign goal
Create a clean, aligned, professional Apple Fitness-like iOS dark UI for four core MVP screens:
1. Home / Parameters
2. Generated Workout
3. Exercise Player
4. Finish summary

## Quality bar
- Use an iPhone-native layout grid, not a rough collage.
- Consistent margins: 20 pt outer margin, 12–16 pt internal spacing.
- Consistent corner radius: 18–28 pt for cards, 999 pt for capsule controls.
- Clear typography hierarchy: large workout/timer focus, readable secondary labels.
- No crooked panels, inconsistent spacing, or decorative noise.
- Placeholder 3D/video area must look intentional and replaceable.

## Visual system v0.2
```text
Canvas: iPhone 15/16 vertical frame, dark background #05070A
Surface: elevated cards #111827 / #172033
Primary accent: fitness green #34D399
Secondary accent: cyan/blue #38BDF8
Warning/rest accent: amber #F59E0B
Typography: SF Pro style, bold numeric timer, concise labels
Motion/media: 3D exercise placeholder as clean glass panel until final assets
```

## Screen requirements

### 1. Home / Parameters
- Hero title: ABS Trainer
- Duration segmented control: 5 / 10 / 15 min
- Zone chips: Upper / Lower / Obliques
- Primary CTA: Generate workout
- Secondary info: 10 exercises, placeholder media, local install

### 2. Generated Workout
- Header with duration and selected zones
- Workout list cards with exercise name, seconds, zone badge
- Clear start CTA
- Premium/future content must not block MVP flow

### 3. Exercise Player
- Large media placeholder card with exercise silhouette/3D cue
- Exercise title and zone
- Dominant timer
- Pause/Resume and Next/Finish controls
- Progress indicator

### 4. Finish summary
- Completion state with positive feedback
- Total time and exercise count
- Repeat / New workout actions
- Subtle future premium teaser only if non-intrusive

## Tooling plan
Preferred options:
1. Figma/Stitch/Google Stitch if user provides/approves external account or API access.
2. If no external access: produce local SVG/PNG mockups from a deterministic design script and manually inspect alignment.
3. Translate accepted visual system into SwiftUI design tokens in `DesignSystem.swift`.

## Delivered artifact v0.2
A new high-fidelity mockup set v0.2 for the four screens, replacing v0.1.

Artifacts:
- `design/assets/mockups/abs-trainer-hifi-v02-home.png`
- `design/assets/mockups/abs-trainer-hifi-v02-workout.png`
- `design/assets/mockups/abs-trainer-hifi-v02-player.png`
- `design/assets/mockups/abs-trainer-hifi-v02-finish.png`

Generation source:
- `scripts/generate_design_mockups_v02.py`

## Acceptance checklist for A5
- [x] All four screens delivered as image artifacts.
- [x] Layout uses a deterministic aligned iPhone canvas/grid.
- [ ] Visual quality is acceptable to user before iOS styling lock.
- [x] SwiftUI implementation can map directly to the mockups.
- [x] Rejected v0.1 is clearly superseded.
