# ABS Trainer — QA evidence checklist (correction cycle 3)

## Scope and automation boundary

- Automated XCTest covers the pause/resume interaction, modal isolation of underlying controls, return to an interactive pause control, and full Setup/Plan/Active/Rest/Finish traversal for validation viewports 320×700 and 393×852 plus AX3 portrait and AX3 landscape. Every matrix run checks critical-control existence, hittability, non-empty frames, containment and relevant non-overlap.
- XCTest does **not** expose the real VoiceOver cursor or the spoken announcement queue. A green UI test must not be reported as proof of actual VoiceOver focus/announcement behavior.
- `hermes-xcode` currently selects its default available simulator (reported by the test log). Its public CLI/API exposes only health, one-way sync, inspect, build, test, status and logs; it exposes neither interactive Simulator/Accessibility Inspector control nor xcresult/artifact download. The validation viewport rows are asserted in-app and attached to xcresult, but are not claims that the runner selected physical devices with those native screen sizes.

## Manual VoiceOver gate (required for QA-P1-05A)

Record tester, date, device, iOS version and VoiceOver language in the evidence note.

1. Enable VoiceOver before launch; launch the app from a terminated state.
2. Confirm initial focus reaches “Соберите свой темп” and the Setup controls follow visual order.
3. Build the default plan and start the session.
4. Confirm entry announcement is “Упражнение 1 из 8…” and swipe order is: exit, progress, exercise/zone, media status/cue, timer context, pause, next.
5. Activate “Поставить тренировку на паузу”. Confirm focus moves into the “Пауза” dialog and player elements cannot be reached by swiping.
6. Activate “Продолжить тренировку”. Confirm the dialog disappears and focus returns to “Поставить тренировку на паузу”.
7. Enter Rest. Confirm “Отдых, N секунд”; verify only 10/5/3/2/1 are announced, not every second.
8. Attach a screen recording with audio or Accessibility Inspector evidence. Mark each step PASS/FAIL; do not infer PASS from code or XCTest.

## Responsive matrix gate (QA-P1-05B)

For each real run, record simulator/device name, logical viewport, iOS runtime, content-size category and orientation. Required rows:

- 393×852 validation viewport, default Dynamic Type: five core states.
- 320×700 validation viewport, default Dynamic Type: five core states.
- Accessibility 3 portrait: five core states.
- Landscape: five core states.

For each state verify: no horizontal overflow/clipping, primary controls are visible and hittable, frames are inside the app window, pause/next and finish controls do not overlap, and safe-area controls do not cover essential copy.

## Visual evidence gate (QA-P1-05C)

1. Export XCTest PNG attachments from `Tests.xcresult` preserving names `01-setup-reference.png` … `05-finish-reference.png`. On the current private runner this requires a runner-side export/download capability or a human with access to the Mac artifact path; Linux sync is one-way and cannot retrieve the bundle.
2. Run:

   `python3 scripts/compare_tempo_cut_screenshots.py --captured <exported-png-dir> --output <evidence-dir>`

3. Review `visual-report.html`, all five approved/actual/diff sets and `visual-report.json`. The comparator copies raw actual, approved baseline, normalized actual and amplified diff into the evidence directory so the report is portable.
4. The default MAE threshold (0.20) is a broad regression signal after full-viewport device-scale normalization. Human review remains mandatory for hierarchy, typography, copy, spacing, chrome and control placement.
5. Store exported PNG, approved baseline copies, normalized actual, generated diff PNG, HTML and JSON together. Pass `--review-outcome PASS|FAIL` only when an independent human has actually reviewed all five states; otherwise retain the explicit default `PENDING`. Record paths in the Kanban handoff.

Approved baselines are versioned at `design/tempo-cut/previews/`. No signing, archive, upload or App Store operation is part of this gate.
