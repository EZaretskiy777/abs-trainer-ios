# ABS Trainer Audio Coach — design and iOS handoff

Статус: developer-ready design/audio package; production Swift не изменён

Kanban: `t_855239fc`

Upstream contract: `docs/audio-coach-product-contract.md`

Downstream: `t_7304a9b5` (`ios`)

## 0. Result

Подготовлен полностью локальный package для музыки тренировки и голосового тренера:

- два оригинальных instrumental seamless-loop варианта из inspectable procedural synthesis;
- выбран `workout_music_pulse_grid_v1`;
- WAV masters 48 kHz stereo 24-bit и AAC-LC/M4A previews/runtime asset;
- измеренные loudness, true peak, decode, DC и seam evidence;
- source, seeds, manifest, SHA-256 и `third_party_inputs: []`;
- high-fidelity Setup/Plan/Player states в существующей системе «Темп / Срез»;
- точная speech hierarchy, phrase/cadence storyboard, accessibility labels и iOS integration contract.

Ни один production Swift-файл, entitlement, dependency или network path не изменён.

## 1. Product frame

- Пользователь: человек, выполняющий короткую тренировку пресса дома и смотрящий на экран эпизодически.
- Контекст: движение, расстояние от телефона, speaker/headphones, иногда VoiceOver.
- Главная задача: слышать темп и переходы, не теряя визуальный контроль и не борясь с громкостью музыки.
- Primary action: собрать/начать/продолжить тренировку; audio остаётся optional enhancement.
- Business/product outcome: повысить уверенность в темпе без аккаунта, сети, микрофона, чужого контента и новой метрики повторов.
- Constraints: iOS 16+, SwiftUI, system `ru-RU` TTS, локальные preferences, no background playback, no production code in this task.

## 2. Evidence and design references

| Reference | Useful pattern | What not to copy | Evidence |
|---|---|---|---|
| `design/user-review-v2/contact-sheet.png` | Режимные surfaces Chalk/Carbon/Ultramarine, 20 pt grid, один primary CTA | Не добавлять карточки/градиенты/второй primary CTA | observed/approved |
| `docs/design-active-rest-finish-audit.md` | Explicit inverse roles, 44–58 pt controls, AX3 reflow | Не наследовать tint; не клиповать essential copy | approved contract |
| `ios/.../ContentView.swift` | Setup scroll + bottom safe-area CTA | Не привязывать audio controls абсолютными Y | observed implementation |
| `ios/.../WorkoutPlanView.swift` | Summary, list и bottom start CTA | Не превращать audio summary в competing card | observed implementation |
| `ios/.../ExercisePlayerView.swift` + product contract | Existing phase/countdown announcements | Не дублировать VoiceOver coaching TTS | observed/approved |
| Native iOS conventions | Familiar toggle/slider semantics, adjustable actions | Не рисовать неизвестный custom interaction | platform constraint |

Внешний browsing не требовался: задача расширяет уже утверждённую локальную систему, а не ищет новый visual language.

## 3. Structure before style

### Critical path

```text
Setup
  ├─ Music toggle (default OFF)
  ├─ Music volume (50%, disabled but retained when music OFF)
  └─ Voice coach toggle (default ON)
      ↓
Plan
  └─ Compact audio summary + Edit
      ↓
Player
  ├─ top-right session mute/unmute
  ├─ quiet speech/mute status row
  └─ existing pause + next controls unchanged
```

### Information hierarchy

1. Workout content/timer/primary CTA.
2. Session safety and pause/next.
3. Speech transition/countdown.
4. Optional music controls/status.

Audio never becomes the only representation of phase, time, next exercise, mute, error or completion.

## 4. Explored UI directions

### A — Chosen: inline system-semantic rows

- Flat rows separated by existing hairlines; no new card surface.
- Familiar switch/slider semantics.
- Plan shows one compact summary row.
- Player mute occupies the balanced top-right 48 pt slot.
- Signature element: quiet hairline speech status strip above the timer.
- Why: preserves Tempo/Cut density and keeps the workout primary.

### B — Rejected: expandable audio card

- Easier visual grouping, but creates another card language and pushes Setup/Plan content.
- Risks repeated containers and a second local hierarchy.

### C — Rejected: global settings sheet only

- Keeps screens sparse, but settings become hard to discover immediately before a workout and require recall.
- Adds navigation/modal work without benefit for three narrow preferences.

## 5. Audio composition directions

### Candidate A — Pulse Grid (selected)

- 120 BPM, 32 bars, 64.000 seconds, seed `85523901`.
- Focused half-time pulse, sparse tonal motif, controlled stereo movement.
- Selected because it leaves the clearest midrange for short `ru-RU` speech while retaining exercise momentum.
- Measured: `-17.98 LUFS-I`, `1.30 LU LRA`, `-2.12 dBTP`, seam delta `-100.30 dBFS`.

### Candidate B — Forward Arc

- 128 BPM, 32 bars, 60.000 seconds, seed `85523902`.
- Brighter syncopation and wider-feeling motion.
- Valid candidate but intentionally busier around speech; retained for review, not app runtime.
- Measured: `-18.06 LUFS-I`, `0.80 LU LRA`, `-2.40 dBTP`, seam delta `-116.89 dBFS`.

Both are synthesized by `source/generate_workout_music.py`; no samples, MIDI, model audio, reference audio, vocals or network input are read.

## 6. Deliverable assets

### Audio

| Purpose | Path |
|---|---|
| Selected 24-bit master | `design/audio-coach/masters/workout_music_pulse_grid_v1.wav` |
| Candidate 24-bit master | `design/audio-coach/masters/workout_music_forward_arc_v1.wav` |
| Selected listenable preview | `design/audio-coach/previews/workout_music_pulse_grid_v1_preview.m4a` |
| Candidate listenable preview | `design/audio-coach/previews/workout_music_forward_arc_v1_preview.m4a` |
| Runtime app-size AAC-LC | `design/audio-coach/app/workout_music_pulse_grid_v1.m4a` |
| Waveform evidence | `design/audio-coach/previews/waveform-contact-sheet.png` |
| Manifest/hashes | `design/audio-coach/manifest/audio-assets.json` |
| Measured report | `design/audio-coach/manifest/validation-report.txt` |
| Reproducibility report | `design/audio-coach/manifest/reproducibility-report.txt` |

Runtime inclusion rule: copy only `app/workout_music_pulse_grid_v1.m4a` and the final manifest fields needed by the app/release evidence. Do not bundle candidate master/preview.

### UX

- `design/audio-coach/ux/audio-controls-contact-sheet.png`
- `design/audio-coach/ux/screens/01-setup-music-on.png`
- `design/audio-coach/ux/screens/02-setup-music-off.png`
- `design/audio-coach/ux/screens/03-plan-audio-summary.png`
- `design/audio-coach/ux/screens/04-player-coach-speaking.png`
- `design/audio-coach/ux/screens/05-player-muted.png`
- `design/audio-coach/ux/screens/06-setup-ax3.png`

Figma destination is not configured in this repository/session. Repository source PNGs plus generator and this measured contract are the inspectable source of truth; importing final frames into the approved Figma workspace remains a human/project-ops follow-up, not an iOS blocker.

## 7. Component contracts

### `WorkoutAudioSettingsRows`

Purpose: edit persistent music/coach preferences before session.

Anatomy:

1. section title `Звук тренировки` + `Локально`;
2. music row with description `Оригинальный ритм` and toggle;
3. volume row with integer percentage and slider;
4. voice row with description `Переходы и темп` and toggle;
5. explanatory copy, not a second CTA.

Layout:

- horizontal inset 20 pt; hairline separators;
- row visual height 64 pt default, intrinsic at Dynamic Type;
- switch visual can remain native; complete hit target at least 44×44 pt;
- slider track full available width, thumb target at least 44×44 pt;
- no card background, shadow or disclosure chevron.

States:

| State | Visual/behavior |
|---|---|
| Music ON | Ultramarine switch; active slider; percentage visible |
| Music OFF | neutral switch; slider remains visible/disabled at retained value; explanatory copy |
| Volume 0% | slider active if toggle ON; does not switch music or voice off |
| Coach OFF | only voice toggle neutral; music unchanged |
| Disabled/generating | controls 38% opacity, same geometry, no repeated activation |
| Corrupt saved value | clamped before rendering; no error card |

Accessibility:

- group order: section → music → volume → voice → explanation;
- no combined row that hides individual adjustable controls;
- exact labels/values in §10.

### `PlanAudioSummary`

Purpose: confirm audible configuration before Start without repeating controls.

- One hairline-bounded row under plan summary and before workout list.
- Leading audio icon decorative.
- Primary: `Музыка · 50%` or `Музыка выключена`.
- Secondary: `Голосовой тренер включён/выключен`.
- Trailing `Изменить` returns to Setup audio controls and places accessibility focus on section title.
- At AX3, trailing action moves below text, leading aligned; nothing truncates.

### `SessionAudioButton`

Purpose: session-only mute for both app music and coaching TTS.

- Top-right circular 48×48 pt, balancing existing 48 pt exit control.
- Default glyph: speaker; muted glyph: crossed speaker.
- White symbol and White 50% interactive outline on Carbon; Increase Contrast uses White/2 pt.
- Does not move pause/next controls or create a third bottom action.
- State persists only for active session; persistent preferences are retained.
- Pressed: White 10% fill and opacity 0.88/120 ms; no scale with Reduce Motion.

### `SpeechStatusRow`

Purpose: optional sighted status, not critical content.

- Hairline-bounded uppercase caption above timer.
- Examples: `Голосовая подсказка · Раз`, `Звук тренировки выключен`, `VoiceOver · музыка приглушена`.
- Never animates on every cadence cue; updates discretely.
- `accessibilityHidden(true)` because speech/mute button/VoiceOver already expose the state.
- Not a live region and never posts an accessibility announcement.

## 8. Exact speech hierarchy

Highest to lowest:

1. VoiceOver/system accessibility announcement;
2. interruption/route-loss safety;
3. finish and phase transition TTS;
4. remaining-time TTS;
5. static-hold cue;
6. dynamic cadence;
7. background music.

Mixing contract:

- normal music gain `V`;
- coaching speech target `V × 0.20`, attack 150 ms, release 300 ms after at least 250 ms;
- contiguous phrase gap ≤500 ms remains ducked;
- VoiceOver active: no coaching TTS; cap music at `V × 0.35`, acceptance fallback pause music;
- session mute: app music + coaching TTS at zero, existing accessibility announcements stay active;
- Reduce Motion does not alter music, TTS, cadence or gain.

## 9. Phrase and cadence storyboard

### Phase/event phrases

| Moment | Channel | Exact visible/spoken intent | Music | Cancel/drop rule |
|---|---|---|---|---|
| Session start | TTS | `Начинаем тренировку.` | duck | once; no replay after resume |
| First intro | TTS | `Упражнение {i} из {n}. {title}.` | remain ducked | required pre-roll |
| First prepare | TTS | `Приготовились.` | remain ducked | work starts after queue/watchdog |
| Rest entry | TTS | `Отдых.` | duck | cancels old cadence/static |
| Next intro | TTS | `Дальше — упражнение {i} из {n}. {title}.` | remain ducked | drop if phase changes |
| Rest remaining 3 | TTS | `Приготовились.` | duck | drop on rest skip |
| Remaining 10 | TTS | `Осталось десять секунд.` | duck | higher than cadence |
| Remaining 5/3/2/1 | TTS | `Пять.` / `Три.` / `Два.` / `Один.` | duck | latest useful threshold only |
| Finish | TTS | `Тренировка завершена.` | duck then stop | cancel all old queue; once |
| Audio unavailable | visual | `Звук тренировки недоступен` | disable failed channel | once per screen/session |

When VoiceOver is active, every coaching TTS row above is suppressed; existing phase/countdown accessibility announcements remain the single speech source.

### Dynamic two-beat cadence

| Active elapsed | Intent | Guard/status row |
|---:|---|---|
| 0–3 s | no cadence | no speech status |
| 4 s | `Раз.` | `Голосовая подсказка · Раз` |
| 6 s | `Два.` | `Голосовая подсказка · Два` |
| 8/10/12… | repeat 4-second grid | only while remaining ≥12 |
| remaining 10 | countdown replaces cadence | `Осталось десять секунд` |
| pause/skip/phase change | cancel queue | no stale replay |

This is a timing cue, not measured repetition completion. No rep count appears in UI.

### Static hold cadence

| Trigger | Intent | Rule |
|---:|---|---|
| elapsed 4 s | `Удерживаем положение.` | only if remaining >12 |
| first 50% crossing | `Половина.` | once; if within 2 s of first cue, only midpoint |
| remaining 10/5/3/2/1 | shared countdown | no `Раз/Два` ever |

## 10. Exact accessibility contract

| Element | Label | Value / hint / trait |
|---|---|---|
| Music toggle | `Музыка тренировки` | `Включена` / `Выключена`; switch |
| Music volume | `Громкость музыки` | integer percent; hint `Настройте громкость фоновой музыки`; adjustable 5% |
| Voice toggle | `Голосовой тренер` | `Включён` / `Выключен`; switch |
| Plan edit | `Изменить настройки звука тренировки` | button |
| Player audible | `Выключить звук тренировки` | button |
| Player muted | `Включить звук тренировки` | button |
| Audio unavailable | `Звук тренировки недоступен` | status once, not repeated |

Suggested stable identifiers:

```text
setup.audio.section
setup.audio.musicToggle
setup.audio.musicVolume
setup.audio.voiceToggle
plan.audio.summary
plan.audio.edit
session.audio.mute
session.audio.status     # accessibility hidden visual node
```

VoiceOver order:

- Setup: header → existing workout setup → audio section/three controls → primary CTA.
- Plan: top bar → summary → audio summary/edit → exercise list → Start.
- Player: exit → progress → exercise/media → speech-hidden visual row → countdown group → session mute → pause → next.

At AX3, controls use intrinsic row heights; horizontal value/action pairs stack. CTA remains in `safeAreaInset`; content scrolls above it. No essential string uses `lineLimit(1)`.

## 11. iOS integration contract

### Resource

- Bundle name: `workout_music_pulse_grid_v1.m4a`.
- AAC-LC, 48 kHz stereo, approximately 144 kbps, 64 s.
- Runtime loop must use gapless looping supported by the chosen engine/player; do not re-fade each repeat.
- Asset failure is nonblocking and does not disable timer/TTS.

### Preferences

```text
audio.v1.musicEnabled     Bool   default false
audio.v1.musicVolume      Double default 0.50, clamp 0...1
audio.v1.voiceCoachEnabled Bool  default true
sessionMuted              Bool   session memory only, default false
```

### Views and state ownership

- Preferences/coordinator own audio state; views send intents and render state.
- Do not place `AVSpeechSynthesizer` or `AVAudioPlayer` construction in SwiftUI `body`.
- Setup and Plan observe the same preference source.
- Player mute never rewrites persistent settings.
- Existing `WorkoutSessionStore` remains timer/phase source of truth.
- Existing `UIAccessibility.post` countdown/state events remain unchanged.

### Gain/state behavior

| Runtime state | Music | Coaching TTS | Accessibility announcements |
|---|---|---|---|
| Music off, coach on | off | event-driven | preserved |
| Music on, idle speech | `V` | idle | preserved |
| Coaching utterance | ramp to `V×0.20` | active | VoiceOver must be off |
| Session muted | zero | suppressed/cancelled | preserved |
| VoiceOver on | cap `V×0.35` or pause | suppressed/cancelled | sole speech source |
| User pause/interruption/background | paused at position | cancel | visual paused state |
| Resume | continue future audio only | future events only | no backlog |
| Finish/exit | stop/deactivate | finish phrase then stop | existing finish announce |

## 12. Reproduction and verification

Environment-safe setup:

```bash
python3 -m venv .venv-audio
.venv-audio/bin/pip install imageio-ffmpeg==0.6.0
.venv-audio/bin/python design/audio-coach/source/generate_workout_music.py
.venv-audio/bin/python design/audio-coach/source/validate_audio.py
python3 design/audio-coach/source/render_audio_ux.py
```

Waveform renderer needs the ffmpeg binary on `PATH` and Pillow available to the selected Python.

Measured PASS rules:

- both masters decode;
- 60–90 seconds, 48 kHz, stereo, PCM 24-bit;
- integrated loudness `-18 LUFS-I ±1`;
- true peak ≤`-1 dBTP`;
- seam first/last delta <`-80 dBFS`;
- no material DC; measured below `-120 dBFS` after 20 Hz high-pass;
- both previews decode as AAC-LC/M4A;
- runtime asset SHA matches selected preview;
- manifest provenance and third-party arrays are explicit.

## 13. Visual and accessibility QA

Final screenshot inspection:

| Dimension | Score |
|---|---:|
| Task clarity / information architecture | 19/20 |
| Hierarchy / composition / density | 14/15 |
| Typography / content | 9/10 |
| Design-system consistency | 14/15 |
| Interaction states / feedback | 9/10 |
| Native adaptation | 9/10 |
| Accessibility | 14/15 |
| Appropriate distinctiveness | 4/5 |
| **Total** | **92/100** |

Verdict: PASS, no P0/P1 in design artifact. Fixed during QA: long Setup helper copy and AX3 title previously clipped; both now wrap. Remaining P2: actual SwiftUI slider/switch metrics and VoiceOver focus cannot be proven from PNG and require simulator/device evidence.

## 14. Acceptance mapping

| AC | Designer evidence | Status |
|---|---|---|
| AC-05 | mute/unmute states and ownership contract | PASS design; runtime pending iOS |
| AC-06 | exact phrase table/storyboard | PASS design |
| AC-07 | dynamic schedule storyboard | PASS design; fake-clock pending iOS |
| AC-08 | static schedule/no cadence | PASS design; runtime pending iOS |
| AC-09 | VoiceOver arbitration and status state | PASS contract; device pending |
| AC-10 | gain targets/ramps and music headroom | PASS contract/asset; route listening pending |
| AC-11 | two assets, source, manifests, hashes, measurements, waveforms | PASS automated; headphones human check pending |
| AC-17 | labels, order, targets, AX3 artifact | PASS design; Accessibility Inspector pending |
| AC-18 | Reduce Motion independence | PASS contract; runtime pending iOS |
| AC-19 | no external input/network/mic/production dependency | PASS artifact review |

## 15. Decisions and rejected alternatives

Decisions:

- Pulse Grid is the single runtime track.
- Music default OFF, coach default ON, volume 50%.
- Setup controls are inline; Plan only summarizes and links back.
- Mute uses top-right balanced control to avoid overloading bottom actions.
- Speech visual status is decorative/non-live.
- VoiceOver owns speech whenever active.

Rejected:

- cloud/recorded/AI voice files;
- stock samples, loop packs or artist imitation;
- cadence synchronized to music/beat detection;
- separate TTS volume slider;
- repeating audio settings card on every screen;
- three bottom player actions;
- Reduce Motion changing audio behavior.

## 16. Risks and manual gates

- Headphones listen and broad musical-similarity review remain human gates; measurements/provenance are not universal legal guarantees.
- AAC gapless behavior, real speaker/headphone ratio and duck ramps require iOS runtime/device QA.
- Installed `ru-RU` voice, Bluetooth latency, interruptions and VoiceOver intelligibility vary by device.
- Figma import/link is unavailable in this environment; repository artifacts are complete but not stored in Figma.
- Large masters/candidate previews are design evidence only; do not ship them.

## 17. Next role

`ios`, task `t_7304a9b5`:

1. implement the upstream minimal file plan;
2. include only selected app M4A at runtime;
3. implement these exact controls/labels/states without changing current primary flow;
4. run AC-01…AC-20 and capture simulator/device evidence;
5. preserve existing phase/countdown VoiceOver announcements;
6. route completed implementation to independent QA before merge/release.
