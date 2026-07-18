# Asset plan — 3D / placeholder exercise media

## Status
First verifiable content artifact for issue #5.

For accelerated MVP, placeholder media is approved. Final 3D videos are not a blocker for first working build.

## MVP exercise media table
```text
ID                 Exercise            Zones              MVP media                 Final media target
------------------------------------------------------------------------------------------------------
crunch             Crunch              upper              placeholder_crunch         3D loop video
reverse_crunch     Reverse Crunch      lower              placeholder_reverse_crunch 3D loop video
bicycle_twist      Bicycle Twist       obliques/full      placeholder_bicycle_twist  3D loop video
plank              Plank               full               placeholder_plank          3D loop video
mountain_climber   Mountain Climber    lower/full         placeholder_mountain       3D loop video
toe_touch          Toe Touch           upper              placeholder_toe_touch      3D loop video
leg_raise          Leg Raise           lower              placeholder_leg_raise      3D loop video
russian_twist      Russian Twist       obliques           placeholder_russian_twist  3D loop video
dead_bug           Dead Bug            full               placeholder_dead_bug       3D loop video
hollow_hold        Hollow Hold         full               placeholder_hollow_hold    3D loop video
```

## Placeholder strategy
- use SwiftUI placeholder cards/icons instead of video files;
- keep `mediaName` stable in `ExerciseCatalog.swift`;
- replace placeholders later with bundled `.mp4`/`.mov` assets without changing generator logic.

## Final 3D video requirements
```text
Format: mp4 or mov
Codec: H.264/H.265
Length: 5–10 sec loop per exercise
Orientation: portrait-friendly or square crop
Background: dark/transparent-looking studio style
License: owned, generated, or explicitly licensed for commercial use
```

## Licensing risk
Do not use random internet workout videos in a public/commercial app. For v1.0 monetization, each final asset needs source/license tracking.

## Next step
Add real placeholder files only if Xcode UI requires bundled media; otherwise current SwiftUI placeholder is enough for MVP skeleton.
