# Design direction — ABS Trainer iOS MVP v0.2

## Status
First verifiable design artifact for issue #2. The v0.1 polished mockup image was rejected by the user on 2026-07-18 and is not A5-approved. Redesign brief: `docs/design-redesign-brief.md`. Final polished mockups still require approval checkpoint A5.

## Visual direction
```text
Style: Apple Fitness-like / premium dark
Tone: focused, clean, energetic, not overloaded
Primary UI: dark background, rounded cards, large timer, strong green/blue accents
Typography: SF Pro / iOS system typography
```

## Screen set
1. Home / Parameters — duration, zones, Generate workout.
2. Generated Workout — list, total time, zones, placeholder badge.
3. Exercise Player — large 3D/video area, title, timer, Pause/Resume, Next/Finish.
4. Finish — completion summary, total exercises/time, repeat/new workout.
5. Settings / About — install/build notes, future premium placeholder.

## Component rules
```text
Cards: 24–32 radius, dark elevated surface
CTA: high-contrast green accent
Timer: biggest element on Exercise Player
Media: 16:9 or tall rounded rectangle placeholder until final 3D video
Badges: small capsule labels for zones/media status
```

## Current implementation link
Initial SwiftUI skeleton uses this direction in:
- `ios/AbsTrainer/Sources/AbsTrainer/DesignSystem.swift`
- `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift`
- `ios/AbsTrainer/Sources/AbsTrainer/ExercisePlayerView.swift`

## Next approve
A5 — high-fidelity mockups acceptance.

Pending next artifact: polished image/mockup set for the 4 core screens.

## Polished mockup artifact v0.1

Image artifact:
`design/assets/mockups/abs-trainer-polished-v01.png`

Scope shown:
- Home / Parameters;
- Generated Workout;
- Exercise Player with 3D placeholder;
- Finish summary.

This is the first polished visual artifact for A5 review. Final high-fidelity can refine spacing, real iPhone dimensions, and final 3D media.

