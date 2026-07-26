# ABS Trainer v2 — independent QA matrix

Status: pre-implementation plan; every runtime criterion is **NOT RUN** until evidence is collected from the exact implementation commit.

Target implementation: Kanban `t_1d470ae0`; independent verifier: `t_8dff333f`.

This document defines acceptance evidence. It does not approve the implementation, and the design PNG under `design/user-review-v2/` are references only — never runtime evidence.

## 1. Sources and fixed contract

- Product scope: `docs/product-spec.md`.
- Approved v2 design handoff: `t_828db5c4`, `design/user-review-v2/README.md`, five PNG `01-setup.png`…`05-confirmation.png`, and `contact-sheet.png`.
- Duration contract: `docs/design-duration-dial.md`.
- Active/Rest/Finish contract: `docs/design-active-rest-finish-audit.md`.
- Existing five-state contract: `docs/tempo-cut-five-state-visual-spec.md`.
- Current evidence boundary: `docs/tempo-cut-qa-evidence-checklist.md`, blockers from `t_e73a2dc0` and `t_aa6c0eab`.
- Shared standards: `/home/hermes/.hermes/team-agent-os/standards/testing/verification.md`, `delivery/task-lifecycle.md`, `delivery/handoff.md`, `engineering/security.md`, `mobile/ios.md`.

Verified repository facts at plan authoring time:

- Project: `ios/AbsTrainer/AbsTrainer.xcodeproj`; shared scheme: `AbsTrainer`.
- GitHub workflow: `.github/workflows/hermes-xcode-ci.yml`; manual `workflow_dispatch`, standard `macos-26`, signing disabled, result bundle and attachments exported.
- Current UI suite: `AbsTrainerUITests`; current unit suites: `WorkoutSessionStoreTests`, `WorkoutGeneratorTests`, `TempoContrastTests`, `DurationDialContractTests`.
- Existing runtime identifiers include `validation.viewport`, `setup.durationDial`, `setup.durationDial.decrement`, `setup.durationDial.increment`, `session.active.timer`, `session.active.timerContext`, `session.active.countdownGroup`, `session.pause`, `session.exit`, `session.rest.nextEyebrow`, `session.rest.nextTitle`, `session.rest.nextDuration`, `session.rest.skip`, confirmation identifiers, `finish.repeat`, and `finish.newWorkout`.
- Domain model has focus zones (`AbsZone`) and duration, but no intensity field. Approved v2 explicitly excludes intensity rather than inventing behavior.

## 2. Evidence policy and artifact layout

Use one evidence root per exact tested commit:

`artifacts/t_8dff333f/<full-commit-sha>/`

Required children:

- `xcode/`: `build.log`, `test.log`, `test-summary.json`, `TestResults.xcresult.zip`, `commit.txt`, simulator metadata.
- `screenshots/<matrix-row>/`: exported actual XCTest PNG.
- `visual-v2/`: actual, approved, normalized, diff, `visual-report.json`, `visual-report.html`, and independent review note.
- `manual/voiceover/`, `manual/increase-contrast/`, `manual/reduce-motion/`, `manual/tap-targets/`: environment note plus recording/screenshots/Inspector export.
- `qa-verdict.md`: per-AC PASS/FAIL/BLOCKED result and defect links.

Evidence ownership:

- **Automated / CI:** iOS implementer produces a focused pushed task commit and CI bundle; independent QA reads the bundle and reruns where needed.
- **Independent QA:** evaluates all automated assertions and actual-vs-approved visual diffs; implementer self-review is not final approval.
- **Human Mac/device QA:** real VoiceOver cursor/announcements, Accessibility Inspector interaction, and physical-device-only behavior.

Global verdict rule:

- `PASS`: exact-commit evidence exists and all listed rules pass.
- `FAIL`: behavior or evidence violates any mandatory rule; record environment, preconditions, steps, expected, actual, severity, and artifact path.
- `BLOCKED`: the required runner/device capability or artifact is unavailable; never convert missing evidence to PASS.
- Final release verdict is PASS only when every mandatory AC is PASS or a named release owner explicitly accepts a documented manual/device residual risk.

## 3. Reproducible execution baseline

### 3.1 GitHub Xcode CI (preferred unattended path)

Preconditions: focused task branch, pushed exact commit, no secrets or generated result bundles committed, never `main` directly.

```bash
git status --short --branch
git rev-parse HEAD
python3 scripts/artifact_gate.py
git diff --check
hermes-github-xcode run \
  --ref "$(git branch --show-current)" \
  --task-id t_8dff333f \
  --wait \
  --download
```

PASS: static gates exit 0; GitHub job conclusion `success`; downloaded `commit.txt` equals `git rev-parse HEAD`; Xcode build and full test exit 0; no failed tests; result bundle, logs, summary, screenshots, and simulator metadata exist under the evidence root. FAIL on any mismatch, missing artifact, test failure, or evidence from another SHA. If included Actions quota/billing prevents assignment, mark BLOCKED/`needs_input`; do not select a paid/larger runner.

### 3.2 Local Mac alternative

When used, follow `xcode-runner`: `hermes-xcode health`, then sync the exact task workspace, `inspect`, `build`, and relevant/full `test`; record every exit code, output tail, logs, and `.xcresult`. Local Mac being offline does not invalidate the GitHub path. No signing, archive, export, upload, TestFlight, or App Store action is permitted.

### 3.3 Targeted test commands inside Xcode-capable CI/Mac

```bash
xcodebuild test \
  -project ios/AbsTrainer/AbsTrainer.xcodeproj \
  -scheme AbsTrainer \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -resultBundlePath artifacts/Targeted.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:AbsTrainerTests/WorkoutSessionStoreTests \
  -only-testing:AbsTrainerTests/WorkoutGeneratorTests \
  -only-testing:AbsTrainerTests/TempoContrastTests \
  -only-testing:AbsTrainerTests/DurationDialContractTests

xcodebuild test \
  -project ios/AbsTrainer/AbsTrainer.xcodeproj \
  -scheme AbsTrainer \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -resultBundlePath artifacts/UITests.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:AbsTrainerUITests/AbsTrainerUITests
```

The final gate still requires the full scheme test from `.github/workflows/hermes-xcode-ci.yml`; targeted green tests alone are insufficient.

## 4. Acceptance matrix

| ID | Acceptance criterion | Evidence type / owner | Exact command or reproducible steps | PASS rule | Required artifact |
|---|---|---|---|---|---|
| AC-01 | Five approved runtime surfaces exist: Setup/Home, Active, Rest, Finish, completion confirmation. Plan remains a required transition state but is not one of the five v2 visual references. | Automated UI traversal + actual screenshots; CI, reviewed by QA | Run full `AbsTrainerUITests`; traverse Setup → Plan → Active → Rest → Finish and separately open completion confirmation before destructive resolution. | Each surface is reachable from a cold launch without debug-only UI; expected state identifiers/controls exist; five actual screenshots are exported. | `xcode/UITests.xcresult*`; `screenshots/reference/{01-setup,02-active,03-rest,04-finish,05-confirmation}.png` |
| AC-02 | Route and state transitions are correct and safe. | UI test + unit state-machine tests; CI/QA | Run `WorkoutSessionStoreTests` and UI suite. Manually verify Plan Back → Setup preserves selection; Active next/timer → Rest; Rest skip/timer → next Active; last exercise → confirmation/Finish; Finish repeat → same Plan; new → Setup. | No illegal/duplicate transition; destructive completion occurs only after confirmation; cancel leaves session active and restores opener focus intent; repeat/new routes match contract. | `xcode/test.log`, `.xcresult`, `qa-verdict.md#AC-02` |
| AC-03 | Workout logic is local and deadline-based: start, pause/resume, late tick reconciliation, rest skip, final completion. | Unit; CI/QA | `-only-testing:AbsTrainerTests/WorkoutSessionStoreTests`. | All session-store tests pass; pause time does not elapse while paused; late ticks reconcile across boundaries; final exercise sets `.finished`; no network/backend dependency appears. | `xcode/test-summary.json`, `xcode/Targeted.xcresult.zip` |
| AC-04 | Focus-zone contract is honest. | Unit/UI + code/data inspection; QA | Select each zone and multi-zone combinations; generate a plan; inspect plan labels/items. Deselect the final specific zone. | `full` permits full catalog; specific zones filter/intersect with allowed full-zone fallback; empty selection normalizes to `.full` and is announced; plan records actual selected zones. | `screenshots/contract/focus-*.png`, test log, `qa-verdict.md#AC-04` |
| AC-05 | Intensity contract is intentionally absent. | Independent design/domain review; QA | Inspect Setup accessibility hierarchy and visible controls against `Models.swift`, `design/user-review-v2/README.md`, and actual screenshot. | No intensity control, copy, value, persistence, or generated-plan claim exists. If implementation adds intensity, FAIL until product/domain approval and tests exist. | `qa-verdict.md#AC-05`, actual Setup screenshot |
| AC-06 | Duration remains exactly 5/10/15, default 10, in-memory, and generator receives only allowed values. | Unit + UI; CI/QA | Run `DurationDialContractTests`, `WorkoutGeneratorTests`, and `testDurationDialStepControlsPreserveAllowedValuesAndEndpointStates`; exercise adjustable `−/+`, tap, and drag paths. | Cold default 10; sequence/bounds 5↔10↔15; endpoints disabled; Setup → Plan → Setup keeps current in-memory value; cold relaunch resets 10; generated plan label/input matches selection; no 6–14 values. | targeted `.xcresult`; `screenshots/contract/duration-{5,10,15}.png` |
| AC-07 | Reference 393×852 portrait has correct hierarchy, copy, palette, rhythm, and control placement. | Geometry UI tests + screenshot comparison + human review; CI/QA | Run `testCriticalStatesFitCompact320By700And393By852`; export 393×852 screenshots; execute v2 visual process in §6. | Geometry assertions pass; independent reviewer marks every v2 state PASS after reviewing actual/approved/diff. MAE alone cannot approve. | `screenshots/393x852/`; `visual-v2/`; review note |
| AC-08 | Compact 320×700 is usable without clipping/overlap/hidden critical controls. | UI geometry + screenshots; CI/QA | Run `testCriticalStatesFitCompact320By700And393By852`; inspect all five state captures and complete the flow by taps/scroll. | No horizontal overflow; essential text is not truncated; all critical controls are non-empty, contained, hittable, and reachable; pinned CTA does not cover dial/steps/content; flow completes. | `screenshots/320x700/`; `.xcresult`; `qa-verdict.md#AC-08` |
| AC-09 | AX3 portrait and AX3 landscape preserve task completion. | UI geometry + screenshots; CI/QA | Run `testAccessibility3PortraitAndLandscapeGeometry` at `UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge`; inspect all state captures and finish the flow in both orientations. | Essential copy wraps; no horizontal scrolling/clipping; dial/−/+ and bottom actions remain reachable; modal body scrolls before actions clip; decorative ring/media may shrink/hide only per contract. | `screenshots/ax3-portrait/`, `screenshots/ax3-landscape/`, `.xcresult` |
| AC-10 | Active and Rest geometry/contrast match corrective contract. | Geometry UI + contrast unit + screenshots; CI/QA | Run `TempoContrastTests`; UI suite asserts Active timer/context containment/composition and Rest next-up pairwise non-overlap. Review actual Active/Rest captures. | Active horizontal midY difference ≤4 pt or vertical gap 0…12 pt, no overlap; pause target ≥58×58; Rest critical text ≥4.5:1 and interactive outline ≥3:1; next-up/skip do not overlap. | targeted test summary; `screenshots/*/active.png`, `rest.png` |
| AC-11 | Finish and completion confirmation are safe, aligned, and factual. | UI geometry/semantics + manual visual; CI/QA | Open both exit and early-finish confirmation variants; attempt outside tap; cancel; reopen and confirm. Reach Finish and activate repeat/new. | Modal order title → body → safe → destructive; outside tap does nothing; background non-hittable/hidden; cancel restores opener; destructive transitions once. Finish shows only factual elapsed/count; actions share edges/center axis, remain reachable, and routes are correct. | `screenshots/reference/05-confirmation.png`, Finish capture, UI `.xcresult`, review note |
| AC-12 | VoiceOver labels, traits, order, focus scope/return, and sparse announcements work in reality. | Mandatory manual VoiceOver; human Mac/device QA | Follow §5.1 from terminated launch with VoiceOver enabled; record tester/device/iOS/language and audio/Inspector evidence. | Every step passes; cursor enters modal and cannot reach background; cancel/resume returns to opener; adjustable dial announces value/boundaries; state announcements and 10/5/3/2/1 are sparse. XCTest focus probes are supporting evidence only. | `manual/voiceover/environment.md`, recording/Inspector export, step checklist |
| AC-13 | Increase Contrast, Reduce Motion, and non-color semantics work. | Manual settings matrix + unit/token support; human/QA | Follow §5.2 for each setting at reference portrait and AX3 landscape. | Increased contrast uses explicit stronger tokens/strokes; all content/control thresholds pass; Reduce Motion uses opacity-only ≤120 ms and no scale/translation/breath travel; selected/destructive/current state remains understandable without color. | `manual/increase-contrast/`, `manual/reduce-motion/`, Inspector note |
| AC-14 | Tap targets and safe areas satisfy the contract. | Geometry XCTest plus Accessibility Inspector; CI + human | Inspect dial, `−/+`, zones, close, pause, next, skip, Finish actions, and both modal actions in each matrix row. | Every visible control is ≥44×44 pt; primary ≥56, pause ≥58, skip ≥56, Finish secondary ≥48; controls are contained, non-overlapping, and not covered by safe-area actions. `isHittable` without measured frame is insufficient. | `manual/tap-targets/inspector-export.*`, frame table, UI test log |
| AC-15 | Actual SwiftUI screenshots are compared to the approved v2 design references, not to themselves. | Comparator signal + independent human review; QA | Export actual five v2 PNG; normalize/compare per §6; review side-by-side and amplified diffs. | Each actual is paired with the corresponding `design/user-review-v2/01…05` PNG; no self-vs-self input; report outcome is explicitly PASS by independent reviewer; hierarchy/copy/tokens/spacing/control placement pass. | `visual-v2/visual-report.{json,html}`, 5× actual/approved/normalized/diff, review note |
| AC-16 | Localization and accessibility copy remain complete Russian strings. | UI review + String Catalog validation; CI/QA | Run full tests; inspect long/wrapped strings in AX3, modal, countdown context, next-up, dial labels/hints, and actions. | No essential truncation or sentence assembly bug; plural-aware duration is correct; glyphs do not replace labels; placeholder media is honestly announced unavailable. | AX3 screenshots, hierarchy excerpt without private data, test log |
| AC-17 | Regression/build evidence is complete and exact-commit bound. | Full Xcode workflow + static gates; CI/QA | Execute §3.1 and archive downloaded evidence. | Artifact gate and diff check exit 0; build and full unit/UI suite pass; `commit.txt` equals reviewed SHA; logs, summary, `.xcresult`, screenshot attachments exist. | entire `artifacts/t_8dff333f/<sha>/xcode/` |

## 5. Manual procedures

### 5.1 VoiceOver gate

Record tester, date, hardware/simulator, iOS version, app commit, VoiceOver language, Dynamic Type, orientation.

1. Enable VoiceOver before a terminated cold launch.
2. Confirm initial focus reaches `Соберите свой темп`; swipe order is heading → adjustable duration → decrement → increment → zones → CTA.
3. On the dial, swipe up/down through 5/10/15. Confirm value and min/max boundary announcements; repeat with `−/+`.
4. Generate the default plan and start. Confirm entry announcement `Упражнение N из M`; order is exit → progress → exercise/zone → media status/cue → combined countdown → pause → next.
5. Pause. Confirm focus enters the Pause title and background player cannot be reached. Resume and confirm focus returns to pause.
6. Open exit confirmation. Confirm title → body → safe → destructive, modal trap, VoiceOver escape acts as safe cancel, and focus returns to exit.
7. Enter Rest. Confirm state announcement and only 10/5/3/2/1 countdown announcements, not every second; verify next-up then skip order.
8. Open early-finish confirmation and verify the same modal rules. Finish and verify order H1/body/results/repeat/new; decorative ring is skipped.
9. Attach screen recording with audio or Accessibility Inspector evidence. Mark each step PASS/FAIL.

### 5.2 Accessibility settings gate

For each setting, cold-launch and traverse Setup → Active → Rest → confirmation → Finish at 393×852 portrait and AX3 landscape:

- Increase Contrast ON: inspect inverse secondary, interactive outlines, destructive outline, dial track/ticks/handle; record measured ratios or Inspector result.
- Reduce Motion ON: change duration, pause/resume, cross Active↔Rest, open/close confirmation; record screen video and verify no angular travel, scale, translation, or breath animation.
- Differentiate Without Color ON where available: verify selected zones, dial value/endpoints, progress/state, and destructive action remain labelled/structured.

### 5.3 Defect template

- ID/severity: P0 blocks core task/data safety; P1 blocks release/accessibility; P2 significant quality; P3 minor.
- Environment: exact SHA, device/simulator, iOS, viewport, Dynamic Type, orientation, accessibility settings.
- Preconditions and numbered steps.
- Expected vs actual.
- Reproducibility count.
- Artifact paths and failing test/assertion.
- Safe next action: correction task for `ios`; QA does not silently edit production code.

## 6. Visual comparison against `design/user-review-v2`

The current `scripts/compare_tempo_cut_screenshots.py` maps the older baseline set `home/plan/active/rest/finish`; it does **not** map the new v2 five-state set because v2 replaces Plan with completion confirmation. Therefore it must not be presented as AC-15 evidence without an explicitly reviewed v2 mapping/update.

Required v2 pairing:

| Actual attachment | Approved reference |
|---|---|
| `01-setup.png` | `design/user-review-v2/01-setup.png` |
| `02-active.png` | `design/user-review-v2/02-active.png` |
| `03-rest.png` | `design/user-review-v2/03-rest.png` |
| `04-finish.png` | `design/user-review-v2/04-finish.png` |
| `05-confirmation.png` | `design/user-review-v2/05-confirmation.png` |

A verifier may use a reviewed extension of the existing comparator with:

```bash
python3 scripts/compare_tempo_cut_screenshots.py \
  --captured artifacts/t_8dff333f/<sha>/screenshots/reference \
  --baselines design/user-review-v2 \
  --output artifacts/t_8dff333f/<sha>/visual-v2 \
  --review-outcome PENDING
```

But this command is valid for v2 only after the script mapping is updated to the table above and its test/smoke gate passes. Until then, use reproducible side-by-side review and record the tooling gap as BLOCKED for automated diff, not PASS. Never set `--review-outcome PASS` before independent inspection of all five actual/approved/diff sets.

Review dimensions: surface/palette; hierarchy; exact Russian copy; typography and wrapping; spacing/rhythm; safe-area placement; control dimensions; modal opacity/order; absence of foreign AI branding/bottom navigation/intensity; no cards/gradients/glow/decorative metrics/second primary CTA. Adaptation differences required for compact/AX3 are not pixel failures when task completion, semantics, and hierarchy are preserved.

## 7. Current coverage map and gaps before implementation verification

### Existing automated coverage that can be reused

- Full flow screenshot capture and five-state geometry traversal.
- 320×700 and 393×852 validation viewports.
- AX3 portrait and landscape traversal.
- Session start/exercise→rest/rest skip/final finish/pause/late-tick logic.
- Duration allowed values, normalization, snap fractions, and endpoint UI states.
- Active timer/context containment and composition.
- Rest next-up containment/non-overlap.
- Rest/Active token contrast calculations.
- Pause and confirmation hierarchy/background-blocking/focus-intent probes.
- GitHub workflow exports `.xcresult`, screenshots, logs, summary, commit, and simulator metadata.

### Gaps that must remain explicit

1. Real VoiceOver cursor, announcement queue, modal trap, and focus return are not exposed by XCTest probes.
2. `isHittable` does not prove all required minimum target dimensions; Inspector/frame assertions are needed.
3. Existing comparator targets the older home/plan/active/rest/finish set, not v2 setup/active/rest/finish/confirmation.
4. Design PNG are static and cannot prove runtime safe areas, Dynamic Type, gestures, haptics, focus, or motion.
5. Increase Contrast and Reduce Motion branches exist in code, but runtime evidence across the required matrix is still mandatory.
6. Intensity is absent by approved product decision; adding it is scope change, not a test gap to “fill”.
7. Latest implementation must be tested on its exact SHA. Older green run or older `.xcresult` cannot satisfy AC-17.
8. GitHub included-runner quota/billing or local Mac outage may BLOCK execution; neither justifies PASS or use of paid/signing/archive alternatives.

## 8. Final handoff format for `t_8dff333f`

- **Result:** independent verdict (`PASS`, `FAIL`, or `BLOCKED`) for exact SHA.
- **Artifact:** this plan plus absolute evidence root.
- **AC matrix:** AC-01…AC-17 each with verdict and artifact link.
- **Coverage gaps:** unresolved manual/capability/tooling gaps; no implied closure.
- **Verification:** commands, exit codes, test counts, run ID/URL, SHA, simulator/runtime, `.xcresult` path.
- **Risks:** accepted and unaccepted residual risks.
- **Suggested next step:** if any failure, create a focused correction card for `ios`; if all mandatory gates pass, return to teamlead/release owner. No signing/archive/upload.
