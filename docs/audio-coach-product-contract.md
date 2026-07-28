# ABS Audio Coach — продуктовый и audio contract

Статус: implementation-ready contract для analyst → audio designer → iOS

Kanban: `t_56471f7b`

Следующая задача: `t_855239fc` (`designer`), затем `t_7304a9b5` (`ios`)

Платформа: iOS 16+, SwiftUI, полностью локально

## 0. Решение и границы

Документ задаёт единый контракт для четырёх связанных изменений ABS Trainer:

1. длительность тренировки выбирается от **5 до 15 минут включительно, строго шагом 1 минута**, default 10;
2. пользователь может включить локальную фоновую музыку и настроить её громкость;
3. системный TTS `ru-RU` озвучивает начало, переходы, окончание и cadence-подсказки;
4. существующие accessibility announcements `ExercisePlayerView` для phase и countdown `10/5/3/2/1` сохраняются и имеют приоритет над coaching speech.

Этот контракт уточняет и для duration **заменяет** прежние `[5, 10, 15]` из `docs/product-spec.md` и `docs/abs-trainer-v2-domain-contract.md`. Конечные границы 5/15 и default 10 сохраняются; новыми являются промежуточные целые минуты и шаг `±1`.

В scope:

- локальные настройки audio;
- одна оригинальная instrumental loop-композиция в app bundle;
- system TTS без записанных голосов и cloud API;
- cadence только как временная подсказка, не как измерение выполненных повторов;
- детерминированный scheduler, audio session/mixing/interruption policy;
- доступные controls и тестовый контракт.

Не в scope:

- backend, аккаунт, streaming, analytics, подписка, remote audio;
- распознавание речи, микрофон, HealthKit, пульс, калории и медицинские рекомендации;
- пользовательские playlists, импорт файлов, AirPlay/CarPlay/lock-screen controls;
- фоновое выполнение тренировки после lock/background;
- чужие samples, stock loops, artist imitation, vocals, trademarks;
- production-код, signing, archive, upload или публикация в этой карточке.

## 1. Проверенный baseline

| Наблюдение | Evidence |
|---|---|
| Setup хранит `selectedDuration = 10`, создаёт локальный `WorkoutSetup` и передаёт значение generator | `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift:12-18`, `:152-159`, `:267-289` |
| Текущий dial разрешает только `[5, 10, 15]` | `ios/AbsTrainer/Sources/AbsTrainer/DesignSystem.swift:333-341` (`DurationDialContract`) |
| `WorkoutSetup.normalized` нормализует duration через тот же contract | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:56-75` |
| Generator работает в секундах и принимает `Int`; starter tests проверяют только текущие allowed values | `ios/AbsTrainer/Sources/AbsTrainer/WorkoutGenerator.swift:10-25`; `Tests/AbsTrainerTests/WorkoutGeneratorTests.swift:118-130` |
| Session phases сейчас `exercise/rest/finished`, source of truth — deadline; pause разрешена только в exercise | `ios/AbsTrainer/Sources/AbsTrainer/WorkoutSessionStore.swift:5-30`, `:49-82`, `:94-129` |
| Player уже публикует phase announcements и countdown на `10/5/3/2/1` | `ios/AbsTrainer/Sources/AbsTrainer/ExercisePlayerView.swift:101-120`, `:463-484` |
| Starter catalog: 10 exercises; статические holds фактически `plank` и `hollow_hold` | `ios/AbsTrainer/Sources/AbsTrainer/ExerciseCatalog.swift:3-15` |
| Exercise media не имеет audio track по существующему motion contract | `docs/exercise-library-product-motion-contract.md:242-260` |
| Audio coach/music implementation в production-коде отсутствует | repository inspection для этой карточки; новых audio imports/resources не обнаружено |

Следствие: iOS не должен строить параллельный таймер. Audio scheduler получает канонические phase/deadline events от session store и не меняет `completedExerciseCount` или transitions.

## 2. User stories

### US-1 — точная длительность

Как пользователь, я хочу менять длительность по одной минуте, чтобы выбрать короткую тренировку между 5 и 15 минутами без скрытого округления.

Acceptance: каждое нажатие `−/+` изменяет значение ровно на 1; endpoints недоступны; plan получает отображённое целое значение.

### US-2 — опциональная музыка

Как пользователь, я хочу включить локальную музыку и выбрать комфортную громкость, чтобы тренироваться с ритмом, но слышать голосовые подсказки.

Acceptance: музыка по умолчанию выключена; включение и громкость сохраняются только локально; speech автоматически приглушает музыку.

### US-3 — голосовые переходы

Как пользователь, я хочу слышать начало, название/номер упражнения, отдых, подготовку и завершение, чтобы реже смотреть на экран.

Acceptance: фразы соответствуют таблице §7, не накапливаются после позднего tick и не дублируют VoiceOver announcements.

### US-4 — корректный cadence

Как пользователь динамического упражнения, я хочу слышать чередующиеся «Раз»/«Два» в ровном темпе; во время статического удержания я не должен слышать фиктивные повторы.

Acceptance: cadence зависит от explicit `coachingMode`, а не от title/эвристики; holds получают временные cues §8.4.

## 3. Duration contract

### 3.1 Значения и normalization

| Поле | Контракт |
|---|---|
| Allowed domain | все целые минуты `5...15` |
| Canonical list | `[5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]` |
| Minimum / maximum | `5` / `15` минут |
| Step | строго `1` минута на одно действие |
| Default / first install | `10` минут |
| Invalid integer | clamp в `5...15`; дробных значений в модели нет |
| Plan input | только normalized integer из canonical domain |
| Persistence | существующее in-memory Setup поведение; duration на диск не сохраняется |

Это изменение не расширяет endpoints и не меняет допуск generator: `abs(plan.totalDurationSec - targetDurationMin * 60) <= 30` для каждой минуты 5…15 и каждой intensity на starter catalog.

### 3.2 UI и accessibility

- Центральное значение dial остаётся primary representation.
- `−` и `+` обязательны; one activation/keyboard/adjustable action = ровно `−1/+1` minute.
- Tap/drag snap-ятся к одному из 11 integer stops; промежуточное дробное значение никогда не показывается и не передаётся.
- Визуально допустимы labels только `5`, `10`, `15`, но все 11 stops должны иметь одинаково достижимую snap-семантику. Не рисовать 11 тяжёлых подписей.
- Endpoint controls остаются видимыми и disabled.
- Dial disabled во время generation.
- Haptic — один selection feedback только при фактическом изменении целого значения.
- Accessibility label dial: `Длительность тренировки`.
- Accessibility value: plural-aware `5 минут`, `11 минут` и т. п.
- Hint: `Смахните вверх или вниз, чтобы изменить на одну минуту. Также доступны кнопки уменьшения и увеличения.`
- `−` label: `Уменьшить длительность на одну минуту`.
- `+` label: `Увеличить длительность на одну минуту`.
- Boundary announcement: `Минимум — 5 минут` / `Максимум — 15 минут`.

## 4. Настройки и persistence

### 4.1 Канонические настройки

| Key / domain field | Type | Default | Persistence | UI |
|---|---|---:|---|---|
| `musicEnabled` | `Bool` | `false` | local `UserDefaults`/`@AppStorage` | toggle `Музыка` |
| `musicVolume` | `Double` `0...1` | `0.50` | local `UserDefaults`/`@AppStorage` | slider `Громкость музыки` |
| `voiceCoachEnabled` | `Bool` | `true` | local `UserDefaults`/`@AppStorage` | toggle `Голосовой тренер` |
| `sessionMuted` | `Bool` | `false` | active session only | player button `Выключить звук тренировки` |

Точные stable keys выбирает iOS, но они должны быть versioned/prefixed, например `audio.v1.musicEnabled`. Не хранить audio settings в `WorkoutPlan`: они mutable preferences, а не параметры генерации.

### 4.2 Правила UI

- На Setup/Plan допустим компактный блок `Звук тренировки`; designer определяет placement без второго primary CTA.
- При `musicEnabled == false` slider виден, disabled и сохраняет последнее значение.
- Slider: `0...1`, UI display `0...100%`, step 5%; default 50%.
- `0%` означает silent music, но не автоматически меняет toggle и не выключает speech.
- Session mute обнуляет output **музыки и coaching TTS**, но сохраняет persistent toggles/volume. Повторное нажатие восстанавливает текущие preferences.
- Session mute не блокирует существующие `UIAccessibility.post` announcements.
- `voiceCoachEnabled == false` выключает только TTS phrases/cadence; visual timer и accessibility announcements сохраняются.
- First install/corrupt value: defaults выше; volume clamp-ится в `0...1`; unknown keys игнорируются.
- Никакой синхронизации через iCloud, логирования preferences или PII.

Accessibility labels:

| Control | Label | Value / hint |
|---|---|---|
| Music toggle | `Музыка тренировки` | `Включена` / `Выключена` |
| Volume | `Громкость музыки` | integer percent; `Настройте громкость фоновой музыки` |
| Voice toggle | `Голосовой тренер` | `Включён` / `Выключен` |
| Player mute | `Выключить звук тренировки` | после mute label меняется на `Включить звук тренировки` |

## 5. Музыкальный asset contract

Designer task `t_855239fc` создаёт минимум два оригинальных варианта и выбирает один final. В runtime включается только выбранный final app-size asset.

### 5.1 Content и права

- instrumental workout loop, без vocals, spoken words, узнаваемых melodies, trademarks и artist imitation;
- только original-in-house notes и procedural/synthesized sounds;
- никаких чужих/stock/AI-training-extracted samples, loop packs или copyrighted reference inputs;
- inspectable source/generator script + seed + manifest;
- provenance `original_in_house`, license declaration `owned_original_work`, `third_party_inputs: []`;
- human review подтверждает отсутствие очевидного сходства; этот review не является универсальной юридической гарантией.

### 5.2 Runtime export

| Property | Contract |
|---|---|
| Final master | WAV, PCM, 48 kHz, stereo, 24-bit preferred |
| App asset | AAC-LC in `.m4a`, 48 kHz stereo, 128–160 kbps |
| Duration | 60–90 s seamless loop |
| Loudness target | `-18 LUFS-I ±1 LU` |
| True peak | `<= -1.0 dBTP` |
| DC/clipping | no clipping; no material DC offset |
| Seam | no click/drop/duplicate transient; measured and listened at last→first |
| Audio track naming | `workout_music_<variant>_v1`; selected final marked in manifest |
| Runtime loop | gapless where AVAudioPlayer/engine supports it; no fade on every loop |

Music is supportive, not a metronome promise. BPM may guide composition, but cadence TTS timing is owned by scheduler §8 and must not derive from decoded beat detection.

### 5.3 Required designer evidence

- two listenable previews + waveform/contact sheet;
- chosen final rationale;
- decode/sample rate/channels/duration/codec/bitrate measurements;
- integrated loudness, loudness range and true peak report;
- seam measurement and headphones listen check;
- source reproducibility command and seed;
- SHA-256 for source/master/app asset;
- manifest with empty third-party inputs.

## 6. Audio architecture and state machine

### 6.1 Logical components

| Component | Responsibility |
|---|---|
| `WorkoutAudioPreferences` | validated local settings only |
| `WorkoutAudioCoordinator` | lifecycle, priorities, AVAudioSession, music duck/mute/pause |
| `CoachingScheduler` | maps canonical session events/deadlines to speech intents |
| `SpeechEngine` | `AVSpeechSynthesizer`, cancellation/completion callbacks |
| `MusicEngine` | one bundled loop, gain ramps and pause/resume |
| `AccessibilityStatus` | observes VoiceOver state; never replaces existing announcements |

Один coordinator владеет audio session. View не должна запускать ad-hoc synthesizers на каждом render/tick.

### 6.2 State machine

```text
idle
  └─ start(plan) → preparingFirstExercise
preparingFirstExercise
  └─ phrase queue complete/cancelled → active.dynamic | active.static
active.dynamic
  ├─ deadline → rest | finished
  ├─ user pause/interruption/route loss → paused(previous=dynamic)
  └─ skip → rest | finished
active.static
  ├─ deadline → rest | finished
  ├─ user pause/interruption/route loss → paused(previous=static)
  └─ skip → rest | finished
rest
  ├─ deadline/skip → active.dynamic | active.static
  └─ interruption/route loss → paused(previous=rest)
paused(previous)
  └─ explicit user resume → previous state with rebased session deadline
finished
  └─ stop/deactivate → idle
```

`preparingFirstExercise` — presentation/audio pre-roll, не новый `WorkoutSessionStore.Phase`. First exercise work deadline запускается после completion/cancellation стартовой обязательной phrase queue, чтобы речь не съедала первые секунды. Если speech выключен/muted/VoiceOver active/unavailable, pre-roll завершается немедленно. Максимальный watchdog pre-roll — 8 секунд; по timeout queue отменяется и exercise начинается.

Для последующих упражнений title/preparation звучат внутри уже существующего rest; work deadline не задерживается. При `restAfterSec == 0` transition phrase сокращается до title, stale speech отменяется при входе в exercise.

### 6.3 Canonical events

Coordinator получает события, а не вычисляет transitions по собственному timer:

- `workoutStarted(planID)`;
- `exerciseWillStart(index, total, exercise, workDeadline)`;
- `exerciseTick(index, elapsedSecond, remainingSecond)`;
- `exercisePaused(index, remaining)` / `exerciseResumed(index, deadline)`;
- `exerciseCompleted(index)` / `exerciseSkipped(index)`;
- `restStarted(nextIndex, total, nextExercise, restDeadline)`;
- `restTick(remainingSecond)` / `restSkipped`;
- `workoutFinished(completedCount)`;
- `sessionMutedChanged`, `voiceOverChanged`, `interruptionChanged`, `routeChanged`, `sceneChanged`.

Каждый event имеет monotonic session sequence. Intents от старого `planID/index/phase/sequence` отбрасываются. Scheduler не меняет domain state.

## 7. Exact phrase/event table

Все строки локализуются как целые format strings, без ручной конкатенации пользовательской фразы. Для `exercise.title` используется фактическая локализованная title из plan; номер — `index + 1`.

| ID | Event / guard | Exact ru-RU text | Queue policy |
|---|---|---|---|
| `workout.start` | start; coach audible; first pre-roll | `Начинаем тренировку.` | required, once per session start; не повторять после resume |
| `exercise.intro.first` | first pre-roll | `Упражнение {i} из {n}. {title}.` | required после start |
| `exercise.prepare.first` | first pre-roll | `Приготовились.` | required; затем start work deadline |
| `rest.start` | enter rest | `Отдых.` | transition; cadence/static queue cancel |
| `exercise.intro.next` | immediately after `rest.start` | `Дальше — упражнение {i} из {n}. {title}.` | transition; one per next exercise |
| `exercise.prepare.next` | first crossing `remainingRest == 3` | `Приготовились.` | drop if rest skipped/phase changed |
| `time.ten` | active first crossing `remaining == 10` | `Осталось десять секунд.` | higher than cadence/static cue |
| `time.five` | active first crossing `remaining == 5` | `Пять.` | countdown priority |
| `time.three` | active first crossing `remaining == 3` | `Три.` | countdown priority |
| `time.two` | active first crossing `remaining == 2` | `Два.` | countdown priority; не cadence intent |
| `time.one` | active first crossing `remaining == 1` | `Один.` | countdown priority |
| `workout.finish` | enter finished | `Тренировка завершена.` | cancel all old queue; once |
| `audio.unavailable` | no usable `ru-RU` voice/asset failure | no TTS promise | visual nonblocking status `Звук тренировки недоступен`; once per screen/session |

Правила:

1. При VoiceOver active **ни одна строка этой таблицы через TTS не произносится**. Источник phase/countdown speech — существующие accessibility announcements.
2. Existing texts `Упражнение i из n. title`, `Отдых, N секунд`, `Тренировка завершена`, `Осталось N секунд` и trigger set `10/5/3/2/1` в `ExercisePlayerView.swift:463-484` не удаляются и не меняют event timing без отдельного accessibility review.
3. При VoiceOver inactive `UIAccessibility.post` может оставаться в коде, но coordinator произносит TTS table. Это не считается audible duplicate, потому что каналы взаимоисключены по `UIAccessibility.isVoiceOverRunning`.
4. При переходе phase queued cadence/time intents старой phase отменяются; transition/final не ждёт их.
5. Если late tick перескочил несколько thresholds, произносится только самый актуальный highest-priority intent текущей phase. Нельзя догонять `10, 5, 3, 2, 1` пачкой.

## 8. Coaching mode и cadence

### 8.1 Explicit domain

Добавить audio/content classification, не выводить её из русского title:

```text
ExerciseCoachingMode
  dynamicTwoBeat
  staticHold
```

Это content metadata. Оно не означает подсчитанные repetitions и не меняет work/rest durations.

### 8.2 Mapping starter catalog

| Mode | Exercise ids |
|---|---|
| `dynamicTwoBeat` | `crunch`, `reverse_crunch`, `bicycle_twist`, `mountain_climber`, `toe_touch`, `leg_raise`, `russian_twist`, `dead_bug` |
| `staticHold` | `plank`, `hollow_hold` |

Unknown/missing mode fail-safe: **без cadence**, только transition/time phrases. Не угадывать по duration/zones/media.

### 8.3 Dynamic two-beat schedule

- Work start = elapsed second `0` after pre-roll.
- Warm-in: первые 4 секунды без cadence.
- `Раз.` на elapsed `4 + 4k` seconds.
- `Два.` на elapsed `6 + 4k` seconds.
- Intent создаётся только если на trigger `remaining >= 12`.
- Значит полный cue cycle = 4 s, между beats = 2 s; cadence не утверждает, что repetition выполнено.
- Threshold at remaining 10 и final countdown имеют приоритет; cadence после remaining 12 не создаётся.
- На pause scheduler замораживается; на resume следующий beat вычисляется от **active elapsed time**, а не wall clock, и старый cue не replay-ится.
- Skip/phase change немедленно отменяет pending cadence.
- Не синхронизировать TTS с 4-second exercise demo loop и не менять скорость media.

### 8.4 Static hold schedule

Для `staticHold` слова `Раз/Два` запрещены.

| Trigger | Text | Guard |
|---|---|---|
| elapsed 4 s | `Удерживаем положение.` | remaining > 12 |
| first crossing 50% work duration | `Половина.` | remaining > 12; once |
| remaining 10/5/3/2/1 | общие time phrases §7 | same priority rules |

Если elapsed 4 и midpoint совпадают/находятся ближе 2 секунд, произнести только `Половина.`. Эти cues описывают время, не качество техники и не медицинскую безопасность.

### 8.5 Speech voice

- `AVSpeechSynthesizer` + `AVSpeechSynthesisVoice(language: "ru-RU")`.
- Использовать установленный system voice; не инициировать download и не включать записанные voice assets.
- Suggested baseline: rate `0.48` от допустимого AVFoundation range, pitch `1.0`, volume `1.0`; designer может уточнить rate в пределах разборчивости, но event timing/words не меняет.
- System output volume остаётся под контролем пользователя; приложение не обещает отдельный TTS volume slider.
- Если `ru-RU` voice отсутствует/offline unavailable, session продолжается визуально; coordinator не подменяет язык автоматически.
- Utterance objects short-lived; не кэшировать персональные данные (их здесь нет).

## 9. Arbitration, mixing and ducking

### 9.1 Priority

От высшего к низшему:

1. VoiceOver/system accessibility announcement;
2. interruption/route-loss/system safety action;
3. final и phase transition speech;
4. remaining-time speech;
5. static-hold cue;
6. dynamic cadence;
7. background music.

Правила preemption:

- transition/final/time may stop cadence at `.word` boundary; stale cadence удаляется;
- cadence никогда не прерывает другую speech;
- queue содержит максимум один future cadence intent;
- duplicate event key `(session, phase, index, phraseID, threshold)` произносится максимум один раз;
- music не останавливается для обычной phrase, а duck-ится.

### 9.2 App music ducking

Пусть persistent volume = `V` в `0...1`:

- normal music gain = `V`;
- speech duck target = `V × 0.20` (примерно −14 dB relative);
- attack ramp = 150 ms до начала utterance;
- release = 300 ms, не раньше 250 ms после completion последней contiguous utterance;
- между фразами одной queue с gap ≤500 ms оставаться ducked;
- muted/paused/background/interrupted gain = 0;
- VoiceOver active: coaching TTS off, music cap = `V × 0.35`, чтобы системная речь оставалась главным каналом. Designer/iOS проверяют реальным VoiceOver; если системная речь всё равно недостаточно разборчива, acceptance fallback — автоматически pause app music while VoiceOver runs.

TTS gain программно не нормализуется относительно system voice. Финальное соотношение проверяется на speaker и wired/Bluetooth headphones при system volume 30/60/90%.

## 10. AVAudioSession и lifecycle policy

### 10.1 Session configuration

| Runtime case | Category / mode / options | Other audio behavior |
|---|---|---|
| App music enabled and audible | `.playback`, `.default`, без `mixWithOthers` | приложение становится primary playback; внешняя музыка приостанавливается |
| App music off, coaching TTS audible | `.playback`, `.spokenAudio`, `.duckOthers` | session активируется только на speech queue; external audio приглушается на фразу и восстанавливается после deactivation |
| Coach off/muted и music off | audio session не активировать | external audio не затрагивается |
| VoiceOver active + app music on | `.playback`, `.default`; coaching TTS suppressed | app music capped/paused по §9.2; accessibility speech priority |

- Активировать session непосредственно перед первым audible output, не при launch.
- После finish/exit и отсутствия pending speech/music: `setActive(false, options: .notifyOthersOnDeactivation)`.
- Не использовать `.record`, microphone permission, Bluetooth input или `.playAndRecord`.
- Category `.playback` означает audible output при silent switch, но только после явного старта workout и с учётом user audio settings.
- Не добавлять Background Audio capability.

### 10.2 User pause/resume

- Pause замораживает workout deadline существующим domain action, pause music с сохранением loop position, отменяет current/queued TTS и cadence.
- Pause phrase не нужна: visual modal уже объясняет состояние.
- Resume только по явному user action; rebase deadline, resume music с сохранённой позиции, schedule only future cues.
- Не replay `Начинаем тренировку`, intro, elapsed cadence или crossed countdown.

### 10.3 System interruption

На `.began` (call/Siri/alarm/media service):

- atomically pause domain session;
- stop TTS immediately, pause music;
- mark interruption reason без PII.

На `.ended`:

- восстановить audio session только если option permits, но **не auto-resume workout/audio**;
- показать существующий paused UI; пользователь нажимает `Продолжить тренировку`;
- после explicit resume применить future-event rule.

### 10.4 Headphones/Bluetooth route changes

- `oldDeviceUnavailable` во время audible session: pause workout/audio, чтобы речь/музыка неожиданно не перешли на speaker; explicit resume required.
- New device/route available: не auto-resume; после user resume coordinator использует current route.
- Bluetooth latency не меняет domain deadlines; допускается небольшая audible latency, но scheduler не догоняет skipped cues.
- Route-change reason/port можно диагностировать локально без device name/PII.

### 10.5 Background, lock и foreground

- На scene inactive/background или lock: pause domain session, TTS и music; no background playback.
- На foreground: сохранить paused state и ждать explicit resume.
- Это заменяет рискованное catch-up поведение для audio coach: workout не должен завершиться молча в background, а затем выдать пачку stale phrases.
- Process termination не восстанавливает active session; persistent audio preferences сохраняются.

### 10.6 Failures

| Failure | Behavior |
|---|---|
| Music asset missing/decode error | disable music for session, keep speech/timers, show one nonblocking status |
| TTS voice/synth failure | disable coach for session, keep music/timers/accessibility announcements |
| Audio session activation fails | remain visual-only, no retry loop; user may retry after route/interruption changes |
| Media services reset | rebuild engines lazily; remain paused until user resume |
| Late timer/tick | current phase only; drop stale cues and crossed low-priority thresholds |

## 11. VoiceOver, accessibility and Reduce Motion

### 11.1 VoiceOver arbitration

- Observe `UIAccessibility.voiceOverStatusDidChangeNotification`.
- VoiceOver ON at start: coaching TTS and cadence disabled before first utterance; existing announcements remain unchanged.
- VoiceOver turns ON mid-utterance: stop coaching TTS immediately, clear queue, reduce/pause music; do not post replacement announcement.
- VoiceOver turns OFF: do not replay missed phrases; TTS resumes only from the next future canonical event.
- Existing phase/countdown announcements remain the single accessibility source; audio implementation must not add second `UIAccessibility.post` for the same events.
- Screen-reader focus and announcement timing take priority over audio decoration.

### 11.2 Other accessibility

- Audio controls are reachable at Dynamic Type AX3, have ≥44×44 targets, visible labels/value and do not depend on color/waveform.
- Slider supports adjustable actions in 5% steps and announces integer percent.
- Toggle/mute selected state is exposed semantically, not as decorative icon only.
- Speech indicators are not live regions on every cadence beat. Optional visual `Голосовая подсказка` indicator is accessibility hidden if it duplicates spoken content.
- Hearing-impaired users retain all critical meaning in visible title, timer, phase, next exercise and finish UI; audio is enhancement, not sole channel.
- No haptics on every cadence beat; existing duration selection haptic remains separate.

### 11.3 Reduce Motion

`accessibilityReduceMotion` **не отключает, не замедляет и не меняет** music, TTS или cadence. Оно влияет только на visual transitions/indicators. Session mute/audio preferences остаются единственными user controls audio. Это отдельно от Reduce Loud Sounds/system volume, которыми управляет iOS.

## 12. Deterministic scheduler rules

1. Source of truth: session phase/index/deadline + active elapsed time from `WorkoutSessionStore`, не `Timer` count и не TTS completion.
2. Trigger — первое observed crossing threshold; exact equality не требуется.
3. Event identity дедуплицируется по session/phase/index/ID/threshold.
4. Phase transition invalidates all pending intents старой phase.
5. Late tick emits at most one relevant speech intent: highest priority that is still useful now.
6. Pause excludes wall-clock duration from active elapsed cadence grid.
7. Speech completion не сдвигает work/rest deadlines, кроме явно описанного first pre-roll.
8. `AVSpeechSynthesizer` callbacks управляют duck release, но не domain timer.
9. Tests use fake clock, fake speech engine completion and event recorder; UUID/system voice/audio hardware не входят в deterministic assertions.
10. Scheduler tests assert intents/ordering/cancellation, а integration tests отдельно проверяют реальный audible output.

## 13. Acceptance and test matrix

| ID | Acceptance | Automated evidence | Manual/device evidence | Pass rule |
|---|---|---|---|---|
| AC-01 | Duration domain/default | unit tests canonical list + cold Setup UI test | Setup screenshot | 5…15 inclusive, default 10 |
| AC-02 | Strict step | component/UI actions for button, adjustable, keyboard, tap/drag | interaction pass | every action exactly ±1; no skipped/decimal/out-of-range value |
| AC-03 | Generator every minute | 11 durations × 3 intensities; relevant focus fixtures | plan totals review | normalized target copied; starter total within ±30 s |
| AC-04 | Preferences defaults/persistence | clean/migrated/corrupt UserDefaults tests | terminate/relaunch walkthrough | music off, 50%, voice on; clamp; no cloud |
| AC-05 | Mute/pause/resume | coordinator state tests | speaker/headphones walkthrough | all app audio mutes/pauses; values retained; no stale replay |
| AC-06 | Exact phrase table | localization/intent snapshot tests | listen to full flow | exact §7 copy and event order; once semantics |
| AC-07 | Dynamic cadence | fake-clock durations 35/40/45, pause/late tick/skip | listen one dynamic item | 4/6 then 4-second grid; stop at remaining <12; no backlog |
| AC-08 | Static holds | mapping + scheduler tests | plank/hollow listen | no `Раз/Два`; hold/midpoint/time cues only |
| AC-09 | VoiceOver priority | status toggle/preemption tests | real VoiceOver full flow | coaching TTS absent; existing phase + 10/5/3/2/1 announcements intact, no duplicates |
| AC-10 | Ducking | gain-envelope unit test with fake engines | speaker + wired/Bluetooth at 30/60/90% | target/ramp §9; speech intelligible, no pumping/click |
| AC-11 | Music asset | manifest validator + decode/loudness/peak/seam commands | headphones seam/content review | one selected original asset meets §5; no third-party inputs |
| AC-12 | Other audio | coordinator configuration tests | Apple Music/podcast scenario | app music interrupts; speech-only transiently ducks; notify on deactivation |
| AC-13 | Interruptions | injected notification/state tests | call/Siri/alarm simulation | domain/audio pause; never auto-resume; no stale cues |
| AC-14 | Route change | injected old-device-unavailable test | wired/Bluetooth disconnect | pause before speaker playback; explicit resume |
| AC-15 | Background/lock | scene transition tests | Home/lock/unlock | no background audio/catch-up; remains paused |
| AC-16 | Failure fallback | missing asset/voice/activation/media reset tests | Airplane Mode clean install | visual session remains operable; one status; no retry loop/crash |
| AC-17 | Accessibility controls | identifiers/labels/values/traits UI tests | VoiceOver + AX3 | exact §4/§11 semantics, reachable, ≥44×44 |
| AC-18 | Reduce Motion | environment branch test | setting ON full flow | audio behavior identical; only visual motion changes |
| AC-19 | Offline/security/scope | dependency/import/resource/diff review | Airplane Mode | no network/mic/account/analytics/background entitlement/secret |
| AC-20 | Regression | existing session/store/UI suites | full Setup→Finish pass | current transitions, pause, skip and announcements not broken |

### 13.1 Required deterministic fixtures

| Fixture | Expected intent highlights |
|---|---|
| Dynamic 40 s, normal ticks | intro; cadence at elapsed 4/6/8/10/… while remaining ≥12; time at remaining 10/5/3/2/1 |
| Static 45 s | hold at 4; half on first 50% crossing; no cadence; final time cues |
| Pause dynamic at elapsed 9 for 20 s | no cues while paused; resume future active-elapsed grid, no replay 4/6/8 |
| Late tick from remaining 13 to 4 | no backlog; current highest useful countdown only (`Три/Два/Один` only when subsequently crossed) |
| Skip during utterance | old utterance cancelled; one rest/finish transition |
| VoiceOver ON mid-cadence | TTS queue clears; music cap/pause; next existing AX phase/countdown remains |
| Rest skipped before prepare threshold | `Приготовились` dropped; next phase has no stale rest phrase |
| Interruption then ended | paused throughout; no audio until explicit resume |

## 14. Minimal implementation/file plan

Production-код в этой аналитической задаче не меняется. Следующие роли ограничивают implementation:

| File/symbol area | Minimum change |
|---|---|
| `DesignSystem.swift` / `DurationDialContract` | canonical `Array(5...15)`, one-minute labels/actions/snap geometry; visual design from child handoff |
| `Models.swift` or local content model | validated duration; explicit `ExerciseCoachingMode` mapping without title heuristic |
| `ContentView.swift` / Plan UI | audio settings UI and persistent preferences; preserve Setup flow |
| `WorkoutGenerator.swift` + tests | normalize 5…15 and prove ±30 s each minute/intensity |
| `WorkoutSessionStore.swift` | expose canonical events/active elapsed and pause on lifecycle without parallel timer |
| `ExercisePlayerView.swift` | coordinator lifecycle, mute control; preserve existing `UIAccessibility.post` triggers/text |
| New narrow audio files | preferences/coordinator/scheduler/speech/music protocols and implementations |
| `Resources/Localizable.xcstrings` | exact phrases, labels, plural/format strings |
| `Resources/Audio` | selected validated M4A + manifest; no unselected runtime variants |
| Unit/UI tests | AC matrix; fake clock/engines for scheduler and real integration/manual evidence |

No new third-party Swift dependency is required: AVFoundation, UIKit accessibility and SwiftUI are sufficient.

## 15. Decisions, rejected alternatives and risks

### 15.1 Decisions

- Сохранить исторические endpoints 5/15 и default 10, но разрешить каждую целую минуту.
- Music default OFF: optional audio не начинает играть без user choice.
- Voice coach default ON, но VoiceOver автоматически становится единственным speech channel.
- Explicit metadata делит dynamic/static; title/duration heuristic запрещена.
- First exercise получает bounded pre-roll; последующие intro/preparation помещаются в rest.
- App music owns playback; speech-only transiently ducks other apps.
- Interruption, headphone loss и background требуют explicit resume.

### 15.2 Rejected

- Диапазон больше 5…15: меняет продуктовый endpoint и генераторный объём без запроса.
- Шаг 5 минут: прямо противоречит текущей задаче.
- Speech audio files/AI voice/cloud TTS: app size, rights, privacy/offline и cost без необходимости.
- Cadence для plank/hollow: создаёт фиктивные repetitions.
- Cadence по BPM/music beat detection: недетерминированно и связывает domain timer с asset.
- Параллельный audio timer: неизбежный drift с session deadline.
- Одновременный VoiceOver + coaching TTS: конфликт речи и duplicate events.
- Background Audio: workout может продолжиться без видимого контроля и требует нового capability/release scope.
- Always-mix external music with app music: неконтролируемая смесь; speech-only mode уже поддерживает external audio через transient duck.

### 15.3 Risks and mitigation

| Risk | Impact | Mitigation / owner |
|---|---|---|
| 11 stops перегружают текущий dial | ухудшение точности/читаемости | designer показывает sparse labels и проверяет snap/AX; `designer` |
| Generator не держит ±30 s на каждой минуте/intensity/focus | target promise нарушен | exhaustive matrix и controlled nearest-plan decision до merge; `ios` |
| TTS duration зависит от installed voice | фразы могут наложиться на short rest | priorities, cancellation, first pre-roll watchdog, concise exact copy; `ios/QA` |
| System/external audio behavior различается по route/iOS | неожиданный mix/stop | real device matrix, no auto-resume; `ios/QA` |
| VoiceOver speech плохо слышно над music | accessibility regression | cap 35%; acceptance fallback pause music; `ios/QA` |
| Original music provenance нельзя доказать только manifest | release/legal risk | source/script/seed/hashes + human review; `designer/release owner` |
| User воспринимает cadence как measured repetitions | ложная метрика | copy не показывает rep count, no completion metric; `designer/ios` |
| `dead_bug` cadence может требовать другого темпа в будущем | content mismatch | explicit metadata допускает per-exercise mode/period extension после content review |
| System `ru-RU` voice unavailable offline | no coach speech | visual-only fallback, no download/network promise |
| Audio session reconfiguration click/latency | poor UX | one coordinator, gain ramps, activate lazily, device listening tests |

## 16. Handoff

### Result

Зафиксирован implementation-ready duration/audio/coaching contract: 5…15 минут с шагом 1, persistent local preferences, original bundled music, exact `ru-RU` phrase/event table, dynamic/static cadence, deterministic state/scheduler, AVAudioSession/mixing/lifecycle и accessibility arbitration без изменения production-кода.

### Artifact

`docs/audio-coach-product-contract.md`

### Contract

Следующие роли могут полагаться на:

- duration и UI semantics §§3–4;
- music rights/export/evidence §5;
- event/state interfaces §§6–8;
- priority/ducking/audio session §9–10;
- VoiceOver/Reduce Motion §11;
- deterministic rules/acceptance §12–13.

### Next designer

`designer`, задача `t_855239fc`: создать два original-in-house music variants, выбрать/измерить final, подготовить waveform/listenable evidence, cadence storyboard и high-fidelity audio controls/states. Completion: designer-owned части AC-02, AC-05–11, AC-17–18 имеют inspectable assets/annotations/report; production Swift не меняется.

### Next iOS

`ios`, задача `t_7304a9b5` после designer: реализовать minimal file plan §14, выполнить automated matrix AC-01…20, снять simulator/device evidence и передать независимой QA. Existing `ExercisePlayerView` announcements `phase + 10/5/3/2/1` — regression gate, не migration target.

### Residual gates

Реальное качество музыки, seam/loudness, installed system voice, audio routes, interruption и VoiceOver нельзя доказать аналитическим документом. Они остаются обязательными designer/iOS/QA gates; App Store/signing/upload не разрешены.

## 17. Standards applied

- `/home/hermes/.hermes/team-agent-os/standards/delivery/task-lifecycle.md`
- `/home/hermes/.hermes/team-agent-os/standards/delivery/handoff.md`
- `/home/hermes/.hermes/team-agent-os/standards/engineering/security.md`
