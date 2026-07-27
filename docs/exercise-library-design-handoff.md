# ABS Trainer — high-fidelity Exercises library handoff

Status: implementation-ready design package; human motion/content review required before release

Kanban: `t_f1d72cf8`

Platform: iOS 16+, SwiftUI, local bundled media

Product/motion contract: `docs/exercise-library-product-motion-contract.md`

Production SwiftUI changed: **no**

## 1. Objective and user job

Design objective: let a person inspect the existing ten starter exercises, find one quickly, and understand its movement phases without changing Setup or starting a workout.

- User: a person preparing for a short local abdominal workout.
- Context: one-handed setup, possibly after exertion; media must also work offline and with Reduce Motion.
- Primary job: identify an exercise and inspect a concise, readable technique demonstration.
- Primary action in Setup remains `Собрать тренировку`; `Упражнения` is secondary navigation.
- Business outcome: improve confidence and comprehension without adding an account, backend, paywall, workout mutation, or medical positioning.
- Success: all 10 starter ids are findable; each detail remains useful with video unavailable or motion disabled; Setup selections survive Back.

## 2. Evidence and references

External browsing and Figma were unavailable in this task. Decisions use inspected repository evidence and platform conventions; no external screen, brand, motion asset, template, or stock character was copied.

| Evidence | Useful pattern | Deliberately not copied | Level |
|---|---|---|---|
| `docs/exercise-library-product-motion-contract.md` | Exact IA, copy, state, media, rights and performance contract | Nothing outside approved scope | observed |
| `design/user-review-v2/contact-sheet.png` and `README.md` | Chalk/Carbon field, one semantic accent per state, flat surfaces, large readable hierarchy | Active timer composition, workout rail, confirmation modal | observed |
| `design/tempo-cut/previews/duration-dial-spec.png` | 20 pt inset, rounded but flat controls, semantic colors, compact/AX/landscape annotations | Circular dial as a generic catalog motif | observed |
| `ios/AbsTrainer/Sources/AbsTrainer/DesignSystem.swift` | Actual Tempo tokens, spacing, radii, minimum 44 pt targets | Current placeholder aperture | observed |
| iOS NavigationStack/Search/VoiceOver conventions | familiar Back, search, selected traits, Dynamic Type, Reduce Motion | custom back behavior or gesture-only controls | inferred; verify on simulator/device |

The structural idea from the user reference is limited to `catalog → search/filter → detail`. Branding, graphics, materials, characters, and motion were not imported.

## 3. IA and critical flow

```text
Setup
  └─ secondary “Упражнения”
       └─ Library
            ├─ search × exact zone × difficulty
            ├─ reset
            ├─ loading / empty catalog / no results
            └─ Detail(id)
                 ├─ poster-first local loop
                 ├─ video fallback
                 └─ Reduce Motion static path
```

Back preserves in-memory Setup state. Library preserves query, filters, and approximate scroll position while its navigation stack is alive. Detail is read-only: no Start, Add, Buy, Favorite, medical result, or cadence promise.

## 4. Three visual directions considered

### A — Quiet Training Index

- Subject anchor: a coach’s compact paper exercise index.
- Layout thesis: dense one-column rows, poster left, facts right.
- Signature: thin horizontal “tempo cuts” and strict baseline rhythm.
- Motion: media appears only in detail.
- Risk: visually conservative and could feel like Settings.
- Decision: retained as the structural baseline.

### B — Kinetic Notation (selected)

- Subject anchor: movement notation on a studio training mat.
- Layout thesis: quiet scannable library; motion owns one large square aperture in detail.
- Signature: original faceless geometric mannequin inside two static trajectory arcs, with a short Ultramarine core seam and Vermilion orientation marker.
- Motion: controlled 4-second loop; alternating exercises show both sides; holds show subtle breathing/weight shift.
- Deliberately removed: gradients, muscle heat maps, floating card grid, autoplay in the list, and decorative performance metrics.
- Risk: stylized geometry cannot replace domain-aware anatomical review.
- Decision: selected because it belongs to movement comprehension while preserving Tempo/Cut restraint.

### C — Anatomical Focus Atlas

- Subject anchor: body-zone diagrams with colored overlays.
- Layout thesis: zone-first visual grid.
- Signature: anatomical map.
- Risk: implies medical/anatomical precision not supported by the product and relies on color.
- Decision: rejected.

The most generic element removed during critique was a repeated elevated card grid. The final library uses flat rows/dividers and gives visual emphasis only to posters and the detail aperture.

## 5. Design system

### 5.1 Semantic tokens

| Token | Value | Use |
|---|---:|---|
| `surface.canvas` | `#F5F1E8` | library/detail canvas |
| `surface.media` | `#ECE5D8` | poster/video field, search, skeleton |
| `text.primary` | `#171714` | titles, selected controls, core mannequin |
| `text.secondary` | `#55534D` | metadata/helper copy |
| `action.motion` | `#D13A25` | work label, orientation marker; never sole meaning |
| `action.filterSelected` | `#171714` | selected filter with text/trait |
| `context.rest` | `#2946C6` | rest label and no-results ring |
| `feedback.failure` | `#B74731` | unavailable media/catalog, with icon and copy |
| `border.subtle` | Carbon 16% / `#D5D0C6` preview | dividers and outlines |

Contrast inherits validated Tempo pairs. Vermilion is not used as normal-size body text on Chalk except bold metadata; implementation should use the production token values and run contrast assertions.

### 5.2 Type roles

- Navigation title: iOS inline title / `.headline`.
- Screen count: `.subheadline.weight(.semibold)`.
- Card title: `.headline`, wraps at AX sizes.
- Card metadata: `.caption.weight(.semibold)` standard; `.body` in accessibility sizes.
- Detail title: `.title.bold()`, unlimited lines.
- Section title: `.title3.bold()`.
- Phase body: `.body`; numbers are separate 24–28 pt Carbon circles, hidden as redundant decoration when ordered semantics are supplied.
- Utility labels: `.caption2.bold()`, uppercase only for brief metadata (`РАБОТА`, `ОТДЫХ`, motion state).

Do not hard-code preview point sizes in SwiftUI. Use semantic Dynamic Type styles and verify wrapping through AX3.

### 5.3 Spacing, shape and density

- Spacing scale: `4, 8, 12, 16, 20, 24, 32, 40` pt.
- Compact outer inset: 20 pt.
- Search height: 44 pt minimum.
- Filter chip height: 38 visual, 44 hit target through padding/content shape.
- List poster: 84 pt standard; 92 pt accessibility preview. Runtime may use 88/96 with stable row alignment.
- Row vertical rhythm: poster plus 12 pt divider gap.
- Radii: search 13, chips 19, aperture 28, empty-state button 18.
- No shadows, glass, blur, gradient, glow, elevated repeated cards, or floating bottom CTA.

## 6. Components and states

### `Exercises / SearchField`

Purpose: local Russian-title query. Standard iOS search semantics and clear action. States: empty, focused, populated, disabled while manifest prepares. It does not persist or log the query.

### `Exercises / ZoneChip / {Default, Selected}`

Single select: `Все зоны`, `Верхний`, `Нижний`, `Косые`, `Весь пресс`. Selected uses Carbon fill plus selected trait and text. The row scrolls horizontally. A separate visible `Сбросить` action remains reachable.

### `Exercises / DifficultyChip / {Default, Selected}`

Single select: `Любая сложность`, `Начальный`, `Средний`. `Продвинутый` is hidden because the starter set contains zero advanced items; this avoids a false affordance.

### `Exercises / ResultRow / {Ready, Pressed}`

One 44+ pt composite button. Poster is decorative because the row exposes a single combined label. Title and metadata wrap; chevron is decorative. Pressed feedback uses opacity/background only; Reduce Motion does not change meaning.

### `Exercises / MotionAperture / {Poster, LoadingVideo, Playing, Failed, ReduceMotion}`

- Poster paints first in every state.
- Playing: one local muted loop, aspect fit, no audio session.
- LoadingVideo: poster remains; compact progress has label `Загрузка демонстрации`.
- Failed: poster + caption `Анимация недоступна`; phases remain complete.
- ReduceMotion: poster + `Статичная демонстрация`; no autoplay/loop.
- Low Power Mode may use the same poster-first policy and is not shown as an error.

### `Exercises / EmptyState / {NoResults, CatalogUnavailable}`

- NoResults: neutral search icon, explanatory text, `Сбросить фильтры`.
- CatalogUnavailable: failure ring, `Каталог пока недоступен`, `Назад к настройке`.
- Neither pretends to be a network state.

### `Exercises / SkeletonRow`

Only for real local manifest/poster preparation. Same geometry as a result row; controls disabled; no indefinite spinner and no simulated delay.

Figma target names above are naming contracts. Figma storage is blocked because no approved workspace/destination or credentials were supplied.

## 7. Screens and source artifacts

All files are under `design/exercise-library/`.

- `source/render_exercise_library.py`: editable deterministic geometry/motion/screen source.
- `source/validate_assets.py`: measured decode, budget, checksum and seam validator.
- `exports/`: ten final MP4 + ten JPG poster files.
- `manifest/exercise-assets.json`: measured per-id manifest.
- `manifest/validation-report.txt`: validator output.
- `previews/contact-sheet.png`: all ten posters.
- `previews/motion-storyboards.png`: five sampled phases for all ten loops.
- `previews/all-exercises-preview.mp4`: all ten loops playing together.
- `previews/screens-contact-sheet.png`: high-fidelity screen/state overview.
- `previews/index.html`: local full-size review gallery.
- `previews/screens/01-default.png`: default ten-item library.
- `02-filtered.png`: exact zone/difficulty intersection.
- `03-no-results.png`: no-results recovery.
- `04-empty.png`: invalid/empty catalog fallback.
- `05-loading.png`: genuine local-preparation skeleton.
- `06-detail.png`: representative detail viewport.
- `07-video-fallback.png`: poster + unavailable caption.
- `08-reduce-motion.png`: static demonstration path.
- `09-compact-320x568.png`: compact portrait.
- `10-ax3-393x852.png`: accessibility-size list adaptation.
- `11-landscape-852x393.png`: two-column detail with preserved reading order.
- `12-ipad-1024x768.png`: regular-width two-column list.
- `13-detail-full-scroll.png`: inspectable full vertical detail content including both cues and disclaimer.

## 8. Motion system and per-id review

All runtime exports are 720×720, H.264 High, yuv420p, 30 fps, exactly 120 frames / 4.00 s, no audio. Start and final source pose are identical. Validator decodes frame 0 and frame 119 and measures a low compressed seam RMS.

| id | Readable phases | Designer review |
|---|---|---|
| `crunch` | shoulders rise and return; feet/hip stable | pass |
| `reverse_crunch` | tabletop → small pelvic curl → tabletop; no foot plant | pass after poster/leg correction |
| `bicycle_twist` | center → side A → center → side B → center | pass |
| `plank` | stable head-to-heel line plus subtle breathing shift | pass; static meaning remains in poster |
| `mountain_climber` | plank → knee A → center → knee B → center | pass |
| `toe_touch` | stable raised legs; shoulder/hand reach and return | pass |
| `leg_raise` | low comfortable angle → high → controlled return | pass |
| `russian_twist` | seated center → left → center → right → center | pass; feet remain grounded |
| `dead_bug` | overhead mat; opposite pair A/B extend around tabletop center | pass after mat/orientation correction |
| `hollow_hold` | compact bent-knee hold plus subtle breathing | pass; no rocking |

These passes confirm design/storyboard consistency, not medical certification. A domain-aware human must review all ten motions and Russian cues before release; the manifest records this residual gate.

## 9. Responsive and native behavior

### 320×568 / compact width

- One list column; posters 84 pt; root scrolls.
- Search and filter groups remain before count/results.
- Filter rows scroll horizontally; no horizontal page overflow.
- Detail remains one vertical ScrollView; square media is width-bound.

### 393×852 standard

- One list column with five visible rows and continued vertical content.
- Detail starts with 353×353 media, then title, chips, work/rest, phases, cues, disclaimer.
- Below-fold content is intentional and demonstrated in the full-scroll capture.

### Dynamic Type through AX3

- One column only.
- Card title and metadata receive intrinsic height; no critical truncation.
- Row hit target expands with content.
- Search label, count and reset scale.
- Filter chips can scroll; implementation must not force every chip into one viewport.
- Detail title, phases and cues wrap; media may reduce before text does.

The static AX3 PNG demonstrates intended reflow, not actual UIKit text metrics. Simulator/device Dynamic Type remains an iOS/QA gate.

### 852×393 landscape compact

- Two-column detail only: media left, text right.
- Reading/focus order remains media → title/metadata → phases → cues/disclaimer.
- Right column scrolls vertically; frame explicitly marks below-fold content.
- No horizontal scroll or overlay text on media.

### iPad regular

- Two result columns are allowed after visual QA; sort order remains starter order, row-major.
- Search/filters span the content container.
- Detail may use two columns with the same semantic order.

## 10. Accessibility contract

- Back uses NavigationStack semantics and restores focus to the opener/result.
- Search label: `Найти упражнение`; standard clear action.
- Zone group label: `Фильтр по зоне`; difficulty group label: `Фильтр по сложности`.
- Chips expose selected state; color is redundant.
- Result count announces after explicit query/filter changes, not every keystroke beyond system search feedback.
- Each row is one element: title, zones, difficulty, duration; hint `Открывает описание и демонстрацию`.
- Poster is hidden inside a labelled row; detail aperture is one element `Демонстрация упражнения «…»`.
- Phases are an ordered list; visual number circles are not separate focus stops.
- Minimum touch target: 44×44 pt.
- Reduce Motion disables autoplay and loop. No parallax, pulse, scale, spring or moving filter feedback.
- Increase Contrast strengthens chip/divider outlines and preserves text/shape redundancy.
- VoiceOver, Switch Control, actual focus restoration, and Dynamic Type are manual simulator/device gates; static PNG is not proof.

## 11. Content and safety

The ten titles, zones, difficulty, durations, three phases, two cues, and disclaimer are sourced from the parent contract. Copy describes observable motion, uses comfortable-range language, and makes no treatment, diagnostic, pain-relief, calorie, safety, or guaranteed-result claim.

Always show:

> Демонстрация носит ознакомительный характер. Выбирайте комфортную амплитуду и остановитесь, если движение вызывает дискомфорт.

## 12. iOS implementation contract

Suggested route shape:

```text
ContentView.Route.exerciseLibrary
ContentView.Route.exerciseDetail(Exercise.ID)
```

Suggested local data split:

```text
ExerciseCatalog.starter                existing immutable exercise metadata
ExerciseLibraryContentCatalog.local    phases, cues, poster filename, disclaimer
ExerciseAssetManifest                  measured media integrity/profile metadata
```

Implementation rules:

1. Add a secondary Setup toolbar/header action; disable it during generation.
2. Keep Setup state ownership in `ContentView`; navigation must not regenerate a plan.
3. Search via trimmed, case/diacritic-insensitive Russian title comparison.
4. Intersect query × exact zone × difficulty; preserve starter order.
5. Posters only in Library; instantiate at most one player in visible Detail.
6. Validate bundled filenames/ids/checksums before declaring media non-placeholder.
7. Pause/release player on disappear, background, lock, interruption and memory pressure.
8. Do not add remote fallback, URL, analytics, account, paywall, Start/Add action, or audio track.
9. Add all 20 media files and manifest to target resources only after build-time validation.
10. Production code should map `mediaName` to `exercise_<id>_v1`; only then set placeholder flags false.

## 13. Verification and design quality gate

Reproducible commands (use any local ffmpeg/ffprobe with equivalent capabilities):

```text
FFMPEG=/path/to/ffmpeg python3 design/exercise-library/source/render_exercise_library.py
FFMPEG=/path/to/ffmpeg python3 design/exercise-library/source/validate_assets.py
python3 -m py_compile design/exercise-library/source/render_exercise_library.py design/exercise-library/source/validate_assets.py
git diff --check
```

The checked package was generated with the `imageio-ffmpeg 0.6.0` bundled ffmpeg 7.0.2 tool. This is generation tooling, not an app/runtime dependency or distributed media input.

### Visual QA score

| Dimension | Score |
|---|---:|
| Task clarity / IA | 20/20 |
| Hierarchy / composition | 14/15 |
| Typography / content | 9/10 |
| Design-system consistency | 15/15 |
| Interaction states / feedback | 9/10 |
| Responsive/native adaptation | 9/10 |
| Accessibility | 14/15 |
| Appropriate distinctiveness | 5/5 |
| **Total** | **95/100** |

No P0/P1 visual defect remains in the generated artifacts after the second visual pass. Important fixes made during QA: removed an export-label/badge collision, replaced unsupported search glyphs with drawn geometry, corrected reverse-crunch leg orientation, added an overhead mat cue to dead bug, and improved storyboard samples/hold breathing visibility.

Weakest part: a geometric mannequin intentionally simplifies anatomy. It is clear enough for implementation handoff but still requires human domain review and real-device playback inspection before release.

## 14. Acceptance matrix

| Criterion | Result | Evidence |
|---|---|---|
| Catalog/search/filters/reset | pass design | screens 01–03; §§3, 6 |
| Empty/loading/fallback | pass design | screens 04, 05, 07 |
| Detail + all content | pass design | screens 06, 13; parent content contract |
| Reduce Motion | pass design | screen 08; §10 |
| Compact/AX3/landscape/iPad | pass design intent | screens 09–12; real device pending |
| 10 videos + 10 posters | pass automated | manifest and validation report |
| 720²/H.264/yuv420p/30fps/4s/no audio | pass automated | validation report |
| Seam and first/last decode | pass automated/designer | seam RMS report; motion storyboard |
| Per-file and total budget | pass automated | 0.507 MB total at latest measured run; report is source of truth |
| Original in-house provenance | pass source declaration | manifest; source script; no third-party inputs |
| Figma final storage | blocked | no approved destination/credentials supplied |
| Human anatomical/content review | required | explicit release gate |
| Production code unchanged | pass | only `design/` and `docs/` artifacts in task scope |

## 15. Risks and next role

- Human anatomical/content/provenance review remains required before release approval.
- Static previews cannot prove actual VoiceOver focus, Dynamic Type, safe areas, decode startup, app lifecycle pause, or Airplane Mode bundling.
- Figma transfer remains blocked until the team supplies an approved destination.
- iOS must run build-time manifest/resource equality checks and capture simulator evidence.

Next role: `ios` implements the secondary Setup entry, Library, Detail, local content mapping, playback/fallback/Reduce Motion, bundled media, accessibility semantics and tests. Completion requires real 320×568, 393×852, AX3, landscape and iPad screenshots plus unit/UI/media validation, followed by independent QA.

Applicable standards:

- `/home/hermes/.hermes/team-agent-os/standards/design/ui-ux.md`
- `/home/hermes/.hermes/team-agent-os/standards/delivery/task-lifecycle.md`
- `/home/hermes/.hermes/team-agent-os/standards/delivery/handoff.md`
- `/home/hermes/.hermes/team-agent-os/standards/engineering/security.md`
