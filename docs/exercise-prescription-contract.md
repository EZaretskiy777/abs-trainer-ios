# ABS Exercises — контракт time-based и repetition-based назначений

Статус: implementation-ready addendum для analyst → designer → iOS → QA

Kanban: `t_46d97bf5`

Связанные задачи: designer `t_855239fc`, iOS `t_7304a9b5`, QA `t_5b6a6c07`

Платформа: iOS 16+, SwiftUI, полностью локально

## 0. Решение, приоритет и границы

Этот addendum вводит явное разделение упражнений на:

- `timeBased` — статическое удержание в течение заданных секунд;
- `repetitionBased` — динамический набор с заданным количеством повторов и локальным детерминированным темпом.

Документ дополняет `docs/audio-coach-product-contract.md`. При конфликте для prescription, счёта повторов, player state и оценки длительности приоритет имеет этот addendum. В частности, прежний `dynamicTwoBeat` с бесконечным «Раз/Два» заменяется конечным repetition-based счётом `Один…N`; static hold продолжает получать временные cues.

В scope:

- exact mapping всех 10 `ExerciseCatalog.starter`;
- точные defaults по intensity и target workout duration;
- counting semantics, cadence и estimated work duration;
- модель, Codable migration и generator contract;
- player UI, voice, pause/resume, background recovery и ручные действия;
- VoiceOver/Dynamic Type/Reduce Motion;
- deterministic unit/UI acceptance matrix и fixtures.

Не в scope:

- camera, microphone, Vision/Core ML, accelerometer или распознавание фактического движения;
- заявления, что приложение увидело, измерило или подтвердило выполненный пользователем повтор;
- оценка техники, калорий, пульса, боли, реабилитация или медицинская рекомендация;
- backend, аккаунт, analytics, HealthKit, cloud TTS или remote content;
- изменение production-кода, signing, archive или публикация в этой карточке.

## 1. Проверенный baseline и основание решений

| Наблюдение | Evidence |
|---|---|
| `Exercise` содержит только `defaultDurationSec`; `WorkoutItem` — только `durationSec`, rep-модели нет | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:88-106` |
| `WorkoutPlan.totalDurationSec` складывает work duration и все rests, кроме последнего | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:115-120` |
| Generator копирует `defaultDurationSec` в каждый item и ищет ближайшую длительность | `ios/AbsTrainer/Sources/AbsTrainer/WorkoutGenerator.swift:114-153` |
| Player и store исполняют любое упражнение через deadline/countdown | `ios/AbsTrainer/Sources/AbsTrainer/WorkoutSessionStore.swift:25-64`, `:94-129`; `ExercisePlayerView.swift:315-345` |
| Pause сейчас разрешена только в exercise; foreground вызывает deadline reconciliation | `WorkoutSessionStore.swift:67-82`; `ExercisePlayerView.swift:105-112` |
| Starter catalog содержит ровно 10 записей с authored work 35–45 секунд | `ios/AbsTrainer/Sources/AbsTrainer/ExerciseCatalog.swift:3-15` |
| Storyboards явно описывают движение/смену сторон для 8 dynamic и удержание для `plank`/`hollow_hold` | `docs/exercise-library-product-motion-contract.md:262-283` |
| Audio contract уже запрещает выдавать cadence за распознанные повторы и требует fake-clock scheduler | `docs/audio-coach-product-contract.md:22-29`, `:455-466` |

Evidence поддерживает классификацию static/dynamic и counting unit. Точные количества и cadence ниже — **продуктовые authored defaults**, откалиброванные так, чтобы estimated work оставался примерно в текущем диапазоне 35–48 секунд. Они не являются универсальной нормой, медицинской дозировкой или доказательством оптимальной нагрузки. Перед release content owner должен выполнить human movement/content review; приложение всегда предлагает остановиться при дискомфорте без обещания безопасности.

## 2. User stories

### US-1 — понятный тип назначения

Как пользователь, я хочу видеть либо секунды, либо конечное число повторов, чтобы понимать, что именно требуется в текущем упражнении.

Acceptance: Plan, Active, Rest-next и VoiceOver используют один resolved `WorkoutItem.prescription`; title или `durationSec` не используются как эвристика типа.

### US-2 — конечный русский счёт

Как пользователь repetition-based упражнения, я хочу слышать реальные последовательные номера `Один, два, три…N`, а не бесконечное «Раз/Два».

Acceptance: счёт начинается с 1, заканчивается exact target, не зацикливается, не догоняет пропущенные номера после pause/background и использует русскую локаль.

### US-3 — честная автоматизация

Как пользователь, я хочу понимать, что авто-счёт задаёт темп, но не распознаёт моё движение.

Acceptance: UI постоянно показывает `Счёт задаёт темп и не распознаёт движения`; нет copy `распознано`, `выполнено автоматически` или sensor permission. Завершение набора подтверждается пользователем либо явно маркируется как пропущенное/досрочное.

### US-4 — восстановление контроля

Как пользователь, я хочу поставить тренировку на паузу, перейти на ручной счёт, исправить число, завершить или пропустить набор.

Acceptance: действия детерминированы, имеют подтверждения для потери прогресса, не создают двойных transitions и доступны VoiceOver.

## 3. Каноническая классификация 10/10

### 3.1 Counting units

| Unit | Семантика | UI/voice rule |
|---|---|---|
| `fullCycle` | один номер после полного движения `start → effort → return` | target и current — обычные повторы |
| `perSideAlternating` | каждое завершённое движение одной стороны — следующий номер; стороны чередуются | target всегда чётный; UI дополнительно показывает `по N/2 на сторону` |
| `seconds` | статическое удержание; rep count отсутствует | основной progress — remaining seconds |

Для `perSideAlternating` первый side определяется визуальной демонстрацией/удобством пользователя и не влияет на баланс: нечётные номера — первая выбранная сторона, чётные — противоположная. Приложение не заявляет, какая сторона реально двигалась; `по N/2 на сторону` — prescription, а не sensor result.

### 3.2 Exact mapping

| id / title | Mode | Counting unit | Evidence в storyboard/content | Решение |
|---|---|---|---|---|
| `crunch` / Скручивания | repetition | `fullCycle` | shoulders rise → lower → neutral | один подъём и возврат = 1 |
| `reverse_crunch` / Обратные скручивания | repetition | `fullCycle` | pelvic curl → controlled return | один curl и возврат = 1 |
| `bicycle_twist` / Велосипед с поворотом | repetition | `perSideAlternating` | left pair → center → right pair | каждое завершение одной стороны = следующий номер |
| `plank` / Планка | time | `seconds` | hold throughout | countdown seconds; rep count запрещён |
| `mountain_climber` / Альпинист | repetition | `perSideAlternating` | knee A → center → knee B | каждое колено = следующий номер |
| `toe_touch` / Касания стоп | repetition | `fullCycle` | reach → lower → neutral | один reach и возврат = 1 |
| `leg_raise` / Подъём ног | repetition | `fullCycle` | lift → controlled lower | один подъём и опускание = 1 |
| `russian_twist` / Русские скручивания | repetition | `perSideAlternating` | rotate A → center → rotate B | один поворот в одну сторону и возврат в центр = следующий номер |
| `dead_bug` / Мёртвый жук | repetition | `perSideAlternating` | opposite pair A → center → pair B | одна противоположная пара и возврат = следующий номер |
| `hollow_hold` / Удержание лодочки | time | `seconds` | hold throughout | countdown seconds; rep count запрещён |

Set equality gate:

```text
timeBased = {plank, hollow_hold}
repetitionBased = {crunch, reverse_crunch, bicycle_twist, mountain_climber,
                   toe_touch, leg_raise, russian_twist, dead_bug}
union.count = 10; intersection.isEmpty = true
```

Unknown/missing classification fail-safe: legacy `timeBased(defaultDurationSec)`. Нельзя угадывать тип по title, zone, media или локализованной строке.

## 4. Exact prescription matrix

### 4.1 Target-duration bands

Все разрешённые target minutes отображаются однозначно:

| Band | Exact target workout minutes |
|---|---|
| `short` | `5, 6, 7` |
| `standard` | `8, 9, 10, 11` |
| `long` | `12, 13, 14, 15` |

Никакой интерполяции внутри band нет. Значит, например, target 8 и 11 минут получают один per-item default, а общая длительность достигается количеством/составом items.

Обозначения в таблицах: `L/B/H` = `light / balanced / high`; `count (estimated seconds)` — exact target count и округлённая вверх оценка work duration. Cadence задаётся в секундах на один **номер**.

### 4.2 Repetition-based: exact counts, cadence и estimates

| id | Unit | Cadence L/B/H, sec per count | Short 5–7: L/B/H count (est.) | Standard 8–11: L/B/H count (est.) | Long 12–15: L/B/H count (est.) |
|---|---|---|---|---|---|
| `crunch` | full cycle | `4.0 / 3.4 / 3.0` | `9 (36) / 11 (38) / 13 (39)` | `10 (40) / 12 (41) / 14 (42)` | `11 (44) / 13 (45) / 15 (45)` |
| `reverse_crunch` | full cycle | `4.5 / 3.8 / 3.2` | `8 (36) / 10 (38) / 12 (39)` | `9 (41) / 11 (42) / 13 (42)` | `10 (45) / 12 (46) / 14 (45)` |
| `bicycle_twist` | per side | `2.5 / 2.2 / 2.0` | `14=7/side (35) / 16=8/side (36) / 18=9/side (36)` | `16=8/side (40) / 18=9/side (40) / 20=10/side (40)` | `18=9/side (45) / 20=10/side (44) / 22=11/side (44)` |
| `mountain_climber` | per side | `2.5 / 2.2 / 2.0` | `14=7/side (35) / 16=8/side (36) / 18=9/side (36)` | `16=8/side (40) / 18=9/side (40) / 20=10/side (40)` | `18=9/side (45) / 20=10/side (44) / 22=11/side (44)` |
| `toe_touch` | full cycle | `4.0 / 3.4 / 3.0` | `9 (36) / 11 (38) / 13 (39)` | `10 (40) / 12 (41) / 14 (42)` | `11 (44) / 13 (45) / 15 (45)` |
| `leg_raise` | full cycle | `4.5 / 3.8 / 3.2` | `8 (36) / 10 (38) / 12 (39)` | `9 (41) / 11 (42) / 13 (42)` | `10 (45) / 12 (46) / 14 (45)` |
| `russian_twist` | per side | `2.5 / 2.2 / 2.0` | `14=7/side (35) / 16=8/side (36) / 18=9/side (36)` | `16=8/side (40) / 18=9/side (40) / 20=10/side (40)` | `18=9/side (45) / 20=10/side (44) / 22=11/side (44)` |
| `dead_bug` | per side | `3.0 / 2.6 / 2.3` | `12=6/side (36) / 14=7/side (37) / 16=8/side (37)` | `14=7/side (42) / 16=8/side (42) / 18=9/side (42)` | `16=8/side (48) / 18=9/side (47) / 20=10/side (46)` |

Формула без скрытого padding:

```text
estimatedWorkDurationSec = ceil(targetCount * cadenceSecPerCount)
```

Cadence — мягкий pacing target. Intensity меняет authored count/cadence profile, но не утверждает физиологическую нагрузку пользователя. UI не показывает reps/min как измеренную метрику.

### 4.3 Time-based: exact hold seconds

| id | Short 5–7 sec L/B/H | Standard 8–11 sec L/B/H | Long 12–15 sec L/B/H |
|---|---|---|---|
| `plank` | `30 / 35 / 40` | `35 / 40 / 45` | `40 / 45 / 50` |
| `hollow_hold` | `20 / 25 / 30` | `25 / 30 / 35` | `30 / 35 / 40` |

Для holds `estimatedWorkDurationSec == durationSec`. Existing `restAfterSec` (`plank: 15`, `hollow_hold: 15`) сохраняется; для dynamic также сохраняется authored rest из catalog. Final rest по-прежнему не исполняется.

### 4.4 Generator duration contract

1. Generator сначала resolves prescription для `(exercise.id, setup.intensity, durationBand)`.
2. Candidate executable cost:
   `resolved.estimatedWorkDurationSec + restAfterSec`, кроме final item без rest.
3. Assembly выбирает ближайший non-empty plan к exact `targetDurationMin * 60`; tie — не превышающий target.
4. Generator не меняет target count/duration отдельных items дробными multipliers ради подгонки.
5. Starter acceptance для каждого `targetDurationMin in 5...15`, каждой intensity и каждого focus: `abs(plan.totalEstimatedDurationSec - target * 60) <= 30` либо test выдаёт конкретный counterexample. Release запрещён, пока starter matrix не проходит.
6. `WorkoutPlan.totalEstimatedDurationSec` использует resolved estimate, а не legacy `durationSec` как второй источник истины.
7. Не ставить одинаковый exercise подряд, если eligible pool содержит хотя бы два id.
8. Repeat использует те же resolved items/counts; не пересчитывает matrix по изменившемуся Setup.

## 5. Domain и Codable contract

Логическая форма; точные Swift names может уточнить iOS без изменения семантики:

```text
ExercisePrescriptionProfile
  timeBased(short: IntensityValues<Int>,
            standard: IntensityValues<Int>,
            long: IntensityValues<Int>)
  repetitionBased(countingUnit: fullCycle | perSideAlternating,
                  cadence: IntensityValues<Milliseconds>,
                  targets: DurationBandValues<IntensityValues<Int>>)

WorkoutPrescription
  timeBased(durationSec: Int)
  repetitionBased(targetCount: Int,
                  countingUnit: fullCycle | perSideAlternating,
                  cadenceMillisPerCount: Int,
                  estimatedDurationSec: Int)

WorkoutItem
  id, exercise, prescription, restAfterSec, order
```

Инварианты:

- time duration `> 0`;
- repetition target `> 0`, cadence `>= 2000 ms`, estimate `ceil(target * cadence)`;
- `perSideAlternating.targetCount` чётный;
- resolved item не зависит от локализованного title;
- `durationSec` не остаётся mutable параллельным source of truth. Допустим compatibility computed property `estimatedDurationSec`;
- catalog validation требует profile для 10 known ids; release validator падает на duplicate/missing/invalid profile;
- runtime unknown profile работает как legacy time item, но пишет локальную non-PII diagnostic.

### 5.1 Versioned Codable migration

Canonical new payload:

```json
{
  "schemaVersion": 2,
  "prescription": {
    "kind": "repetitionBased",
    "targetCount": 18,
    "countingUnit": "perSideAlternating",
    "cadenceMillisPerCount": 2200,
    "estimatedDurationSec": 40
  },
  "durationSec": 40
}
```

Migration rules:

| Input | Decode result | Rationale |
|---|---|---|
| v2 valid `prescription` | use it; validate/clamp only through one decoder boundary | canonical path |
| legacy item with only `durationSec` | `.timeBased(durationSec)` | preserves exact old behavior; never reinterpret saved dynamic item silently |
| v2 repetition + compatibility `durationSec` mismatch | `prescription` wins; DEBUG assertion/local diagnostic | no dual source of truth |
| missing/zero/negative legacy duration | controlled decode/generation failure; no session precondition crash | corrupted data is not valid work |
| unknown `kind`/`countingUnit` | controlled decode failure or explicit legacy fallback only when valid `durationSec` exists | forward-safe behavior |
| old `Exercise` without profile | catalog resolver by stable id for newly generated plan; decoded old plan still follows item migration above | do not mutate historical plan semantics |

Encoder v2 writes canonical `prescription` plus compatibility `durationSec = estimatedDurationSec`, so an older reader degrades to the previous timed flow rather than crashing. Active session progress remains in-memory only; this contract does not introduce disk/cloud persistence.

## 6. Session state machine

```text
idle
  └─ start(valid non-empty plan) → preparingFirst
preparingFirst
  └─ intro complete/cancel/watchdog → active.timed | active.repetition.paced
active.timed(remaining/deadline)
  ├─ deadline → rest | finished
  ├─ pause/interruption/background/route loss → paused(snapshot)
  └─ skip/finish early confirmation → rest | finished
active.repetition.paced(currentScheduledCount, target, nextCountDeadline)
  ├─ cadence crossing → advance planned count, speak/display number
  ├─ switch manual → active.repetition.manual(currentConfirmedCount, target)
  ├─ target reached → awaitingSetConfirmation
  ├─ pause/interruption/background/route loss → paused(snapshot)
  └─ finish early / skip → confirmation → rest | finished
active.repetition.manual(currentConfirmedCount, target)
  ├─ user +1/-1 → bounded self-reported count
  ├─ target reached → awaitingSetConfirmation
  └─ pause/finish early/skip → corresponding state
awaitingSetConfirmation
  ├─ confirm → outcome completed → rest | finished
  ├─ continue manual → active.repetition.manual
  └─ skip → outcome skipped → rest | finished
rest
  ├─ deadline/skip rest → next active mode
  └─ interruption/background/route loss → paused(snapshot)
paused(snapshot)
  └─ explicit user resume → same state with rebased deadlines; no catch-up
finished
  └─ stop/deactivate → idle
```

### 6.1 Outcomes and summary

Каждый item получает ровно один outcome:

- `completed`: timed deadline reached или repetition target явно confirmed;
- `completedEarly`: пользователь подтвердил досрочное завершение; сохраняется displayed count/remaining, но UI не называет target достигнутым;
- `skipped`: пользователь подтвердил skip;
- `notStarted`: session завершена до item.

`completedExerciseCount` в Finish означает только `completed + completedEarly`; skipped показывается отдельно. Double tap/duplicate event не меняет outcome/index дважды. Для paced mode достижение scheduled target **не** означает автоматически выполненный набор: переход ждёт `Подтвердить набор`.

### 6.2 Deterministic count clock

- Source of truth paced mode: monotonic active elapsed time и fixed `cadenceMillisPerCount`, не render ticks и не speech completion.
- First count deadline: через один cadence interval после work start. В этот момент display становится `1`, voice произносит `Один`.
- Tick обрабатывает только текущее useful crossing. При late tick display может показать вычисленный planned number, но voice произносит только текущий номер; очередь прошлых `3, 4, 5` не догоняется.
- UI label всегда `Плановый счёт: X из N`, пока пользователь не включил manual mode.
- Manual mode label: `Подтверждено вручную: X из N`; `+1` — явный self-report, не sensor detection.
- Pause замораживает active elapsed и next count offset. Resume rebases deadline; crossed во время pause номера не появляются.
- Speech lag не сдвигает count clock. Если предыдущий numeral ещё говорит на следующем crossing, stale utterance отменяется на границе слова и произносится только current number.
- Phase/index/session sequence invalidates old count intents.

## 7. Player UI и exact copy

### 7.1 Plan и Rest-next

| Mode | Primary prescription display | Accessibility value |
|---|---|---|
| time | `40 сек` | `Удержание, 40 секунд` |
| repetition full cycle | `12 повторов` | `12 повторов, полный цикл движения считается одним повтором` |
| repetition per side | `18 повторов · по 9 на сторону` | `18 повторов, по 9 на каждую сторону; каждое движение одной стороны считается следующим повтором` |

Rest-next показывает prescription следующего item, а не compatibility duration.

### 7.2 Active timed

- title + `Удержание`;
- remaining `M:SS`;
- context `Осталось в удержании`;
- persistent neutral cue `Сохраняйте комфортное положение. Остановитесь при дискомфорте.`;
- actions: pause, `Завершить удержание` (early confirmation), `Пропустить упражнение`.

### 7.3 Active repetition paced

- title + `Повторы`;
- large current integer and context `Плановый счёт: {current} из {target}`;
- per-side secondary `По {target/2} на сторону` where applicable;
- persistent disclosure `Счёт задаёт темп и не распознаёт движения.`;
- actions: pause, `Считать вручную`, `Завершить набор`, overflow/destructive `Пропустить упражнение`.

At target:

- heading `Плановый счёт завершён`;
- body `Подтвердите набор или продолжите вручную. Приложение не распознаёт движения.`;
- primary `Подтвердить набор`;
- secondary `Продолжить вручную`;
- destructive `Пропустить упражнение`.

### 7.4 Manual mode

- `Подтверждено вручную: {current} из {target}`;
- decrement/increment controls `Уменьшить счёт повторов` / `Подтвердить ещё один повтор`;
- bounds `0...target`; decrement at 0 and increment at target disabled;
- user can return to paced mode only after confirmation `Продолжить автоматический темп?`; next paced deadline starts from current count and does not replay old numerals;
- `Завершить набор` before target opens exact confirmation:
  `Завершить набор на {current} из {target}? Результат будет отмечен как завершённый досрочно.`

Skip confirmation:

`Пропустить «{title}»? Упражнение будет отмечено как пропущенное.`

## 8. Voice contract ru-RU

### 8.1 Intro and transitions

| Event | Exact phrase |
|---|---|
| timed intro | `Удержание — {duration} секунд. Приготовились.` |
| repetition full-cycle intro | `Цель — {target} повторов. Каждый полный цикл — один повтор. Счёт задаёт темп.` |
| repetition per-side intro | `Цель — {target} повторов, по {perSide} на каждую сторону. Каждая смена стороны — следующий номер. Счёт задаёт темп.` |
| switch manual | `Ручной счёт.` |
| paced target reached | `Плановый счёт завершён. Подтвердите набор.` |
| confirmed | `Набор подтверждён.` |
| early completed | `Набор завершён досрочно.` |
| skipped | `Упражнение пропущено.` |

`{target}`, `{perSide}`, `{duration}` локализуются одной format/pluralization boundary; не собирать русские фразы фрагментами в View.

### 8.2 Real numeral sequence

Для каждого paced/manual increment произносится конкретный текущий номер, а не parity beat:

```text
1 Один; 2 Два; 3 Три; 4 Четыре; 5 Пять; 6 Шесть;
7 Семь; 8 Восемь; 9 Девять; 10 Десять; 11 Одиннадцать;
12 Двенадцать; 13 Тринадцать; 14 Четырнадцать; 15 Пятнадцать;
16 Шестнадцать; 17 Семнадцать; 18 Восемнадцать;
19 Девятнадцать; 20 Двадцать; 21 Двадцать один; 22 Двадцать два.
```

Matrix maximum is 22, поэтому fixture обязана покрыть `1...22`. Implementation может использовать locale-aware number spell-out, но snapshot должен совпасть с этим списком. TTS voice — system `ru-RU`; отсутствие voice даёт visual-only fallback без смены языка.

### 8.3 Timed holds

- elapsed 4 s: `Удерживаем положение.`, только если remaining > 12;
- first 50% crossing: `Половина.`, только если remaining > 12;
- remaining 10: `Осталось десять секунд.`;
- remaining 5/3/2/1: `Пять.`, `Три.`, `Два.`, `Один.`;
- hold никогда не произносит repetition sequence.

### 8.4 Arbitration

Priority: VoiceOver/system → interruption → transition/outcome → timed countdown → repetition numeral → music.

- При VoiceOver ON coaching TTS полностью выключен; существующие accessibility announcements остаются единственным speech source.
- VoiceOver включился mid-utterance: stop/clear coaching queue, no replay.
- Pause/skip/finish/phase change отменяют старые numerals.
- Late tick не создаёт backlog.
- App music ducking и audio-session policy следуют `docs/audio-coach-product-contract.md`; этот addendum меняет только prescription/count intents.

## 9. Pause, interruptions и background recovery

| Event | Domain | Audio/UI | Resume |
|---|---|---|---|
| user pause | freeze timed remaining или repetition count offset | cancel TTS; pause music; modal сохраняет mode/count | explicit resume, rebase only |
| scene inactive/background/lock | atomically pause current active/rest state | no background audio/count; paused UI on return | explicit user resume; no wall-clock catch-up |
| interruption began | pause domain before audio teardown | stop speech/music | ended event never auto-resumes |
| headphones `oldDeviceUnavailable` | pause before route switches to speaker | no surprise speech | explicit resume on current route |
| foreground while active due to missed scene event | reconcile to **pause timestamp**, not current wall time; clamp without advancing count/deadline | show recovery notice once | explicit resume |
| process termination | discard active session | next launch Setup; preferences only as separately contracted | no session restore |

Timed mode therefore no longer silently completes multiple phases in background for an audio-enabled session. Repetition mode never creates missed counts while inactive.

## 10. Accessibility и localization

- Mode, current/target, per-side semantics и auto-count disclaimer доступны текстом; audio не единственный канал.
- Count group — один adjustable element, не 22 отдельных focus targets.
- Paced group label: `Плановый счёт повторов`; value: `{current} из {target}`; hint: `Счёт задаёт темп и не распознаёт движения. Поставьте на паузу или включите ручной счёт, если нужно.`
- Timed group label: `Осталось в удержании`; value — plural-aware seconds/time.
- Manual `+1/-1`, confirm, continue, finish and skip имеют ≥44×44 pt targets, visible labels и deterministic focus restoration.
- После modal cancel focus возвращается к opener; после transition — к title нового phase.
- Dynamic Type AX3: title, count, disclaimer и all actions достижимы vertical scroll; bottom inset не перекрывает content.
- VoiceOver announcement не публикуется на каждом render. Только meaningful count change; duplicate current value дедуплицируется.
- Reduce Motion не меняет cadence/count/duration; visual count transition становится без scale/slide.
- Increased Contrast не скрывает mode/outcome; цвет не является единственным различием completed/skipped/early.
- Russian plurals (`1 повтор`, `2 повтора`, `5 повторов`; `1 секунда`, `2 секунды`, `5 секунд`) задаются localization resource, не ручной тернарной логикой в View.

## 11. Required deterministic fixtures

| Fixture | Input/actions | Exact expected highlights |
|---|---|---|
| F-01 legacy decode | item `{durationSec:40}` no prescription | `.timeBased(40)`; re-encode v2 with compatibility 40 |
| F-02 full-cycle standard balanced | `crunch`, 10 min, balanced | target 12, cadence 3400 ms, estimate 41; numbers 1…12; await confirmation |
| F-03 alternating short light | `bicycle_twist`, 5 min, light | target 14, 7/side, cadence 2500 ms, estimate 35; even invariant |
| F-04 alternating long high max | `bicycle_twist`, 15 min, high | target 22, 11/side, cadence 2000 ms, estimate 44; Russian snapshots 1…22 |
| F-05 slow alternating | `dead_bug`, 12 min, balanced | target 18, 9/side, cadence 2600 ms, estimate 47 |
| F-06 timed matrix | `plank`, 6 light / 10 balanced / 15 high | 30 / 40 / 50 seconds |
| F-07 hold no reps | `hollow_hold`, any tuple | no repetition numeral/counter; only hold/time cues |
| F-08 pause paced | target 12; pause after count 4 for 20 s | count stays 4; no speech; resume schedules 5 in future, no replay 1…4 |
| F-09 late tick | count 4; tick arrives at computed count 7 | display 7; voice only `Семь`; no queue 5/6 |
| F-10 manual switch/correction | paced 4 → manual +1 +1 -1 | manual current 5; speech `Пять`, `Шесть`, then no reverse numeral; outcome unset |
| F-11 target gate | paced reaches target | no rest; `awaitingSetConfirmation`; confirm exactly once → completed/rest |
| F-12 early finish | manual 7 of 12 → finish → confirm | `completedEarly(actualDisplayedCount:7)`; not target-completed copy |
| F-13 skip | active → skip → confirm | outcome skipped; next/rest once; completed count unchanged |
| F-14 background | count 5 → background 60 s → foreground | remains paused at 5; no counts/phrases; explicit resume |
| F-15 VoiceOver toggle | ON before/mid rep | no coaching TTS; accessible current changes preserved; no duplicate speech |
| F-16 invalid alternating | odd target or cadence <2000 | validator/decode controlled failure; session not created |
| F-17 generator grid | 11 minutes × 3 intensities × supported focus fixtures | every resolved item exact matrix; total estimate ±30 s; no final rest |
| F-18 duplicate actions | double confirm/skip/resume | one outcome/transition/event sequence only |

## 12. Unit/UI acceptance matrix

| ID | Acceptance | Automated evidence | Manual/device evidence | Pass rule |
|---|---|---|---|---|
| AC-01 | 10/10 classification | catalog/profile set validator | content review | exact §3 set, no missing/duplicate/heuristic |
| AC-02 | Exact matrix | table-driven 10 ids × 11 durations × 3 intensities | Plan spot-check all ids | values/estimates equal §4 |
| AC-03 | Generator target | grid per duration/intensity/focus | inspect 5/10/15 plans | total estimated duration within ±30 s; final rest absent |
| AC-04 | Counting semantics | even/per-side and full-cycle tests | alternating walkthrough | per-side target even and exact half label |
| AC-05 | Russian count | intent snapshot `1...22` | real ru-RU listen | sequential concrete numerals; no endless `Раз/Два` |
| AC-06 | Honest pacing | string/import/permission assertions | screen review | disclosure visible; no camera/sensor/recognition claim or permission |
| AC-07 | Confirmation outcomes | state machine fixtures F-11…F-13/F-18 | tap walkthrough | completed/early/skipped distinct; one transition |
| AC-08 | Manual mode | bounds, switch, +/−, resume tests | one full manual set | self-report only, corrections deterministic |
| AC-09 | Pause/resume | fake monotonic clock F-08 | pause 20 s | no count/time progress or replay |
| AC-10 | Background/interruption/route | injected events F-14 | Home/lock/call/headphone disconnect | pause atomically; never auto-resume/catch up |
| AC-11 | Timed holds | threshold tests for every matrix duration | plank/hollow listen | seconds/hold cues only, no rep sequence |
| AC-12 | Codable migration | legacy/v2/corrupt/unknown fixtures | upgrade launch | old item stays timed; controlled corrupt failure; no crash |
| AC-13 | VoiceOver | toggle/preemption tests | real VoiceOver complete flow | coaching suppressed; one accessible source; actions/readout usable |
| AC-14 | Dynamic Type/layout | UI identifiers + AX3 snapshot suite | 320×568, 393×852, landscape AX3 | count/disclaimer/actions reachable, no overlap |
| AC-15 | Localization | plural/numeral snapshot | Russian device | exact plural/copy; no View concatenation errors |
| AC-16 | Reduce Motion/contrast | environment UI tests | settings ON | behavior unchanged; no color/motion-only meaning |
| AC-17 | Regression | existing generator/store/UI suites | Setup→Finish | time legacy and current navigation remain operable |
| AC-18 | Scope/security | git/import/entitlement review | Airplane Mode | no network, sensor permission, analytics, secret, background entitlement |

## 13. Minimal downstream changes

### Designer `t_855239fc`

- Annotate Plan, Active timed, Active paced, Active manual, awaiting confirmation, early/skip confirmation, Rest-next and Finish outcome variants.
- Use exact copy/labels §§7–10 and show persistent no-recognition disclosure.
- Provide default + AX3/compact/landscape + VoiceOver focus order; destructive hierarchy must not compete with primary confirm.
- Audio assets do not pronounce fixed `Раз/Два`; designer verifies system ru-RU numeral intelligibility 1…22 and hold cues.

Designer completion gate: inspectable annotations for all states/actions, no sensor implication, all mode/count semantics represented without audio/color only.

### iOS `t_7304a9b5`

Expected narrow file areas (exact decomposition may vary after code review):

- `Models.swift`: versioned prescription/profile/counting/outcome types and migration;
- `ExerciseCatalog.swift`: explicit 10 profiles matching §3/§4;
- `WorkoutGenerator.swift`: resolve matrix and assemble by estimated work;
- `WorkoutSessionStore.swift`: typed active substates, monotonic paced/manual count, outcome/confirmation/background pause;
- `WorkoutPlanView.swift`, `ExercisePlayerView.swift`, `FinishView.swift`: mode-specific UI/copy/actions/accessibility;
- `Localizable.xcstrings`: pluralized copy and numeral/format snapshots;
- unit/UI tests: fixtures §11 and acceptance §12.

Do not add camera/mic/motion permissions, recognition frameworks, backend, analytics or disk session restore. Existing `durationSec` decoder must remain compatible.

### QA `t_5b6a6c07`

- Execute AC-01…AC-18 independently after iOS handoff.
- Mandatory real-device/simulator passes: ru-RU voice, VoiceOver, background/lock, interruption, route loss, Reduce Motion, Increased Contrast, AX3, 320×568 and landscape.
- Report observed UI current number separately from human movement; QA must not mark sensor accuracy because no sensor exists.
- Release verdict is fail on any silent auto-completion of rep set, odd per-side target, catch-up speech, duplicate outcome, or missing no-recognition disclosure.

## 14. Risks, rejected alternatives и follow-up gates

### Risks

1. **Paced count may differ from the user's movement.** Mitigation: permanent disclosure, pause/manual mode, explicit set confirmation; no recognition claim.
2. **TTS duration varies by installed Russian voice.** Mitigation: cadence minimum 2.0 s, current-only preemption, visual count source; manual listen gate 1…22.
3. **Generator tolerance may fail after exact per-item estimates.** Mitigation: exhaustive 11×3×focus grid before release; adjust assembly/order, not authored matrix silently.
4. **State expansion can regress late-tick/background behavior.** Mitigation: typed substates, monotonic fake clock, no wall-clock catch-up, injected lifecycle fixtures.
5. **Legacy payloads cannot reveal intended rep mode.** Mitigation: preserve them as timed; only newly generated v2 plans use rep prescriptions.
6. **`completedExerciseCount` currently increments on skip.** New outcome contract requires migration of summary semantics and regression review.
7. **Exact defaults are content choices, not medical evidence.** Human content review is required; copy avoids guarantees and universal suitability.

### Rejected alternatives

- Infer static/dynamic from Russian title or duration: localization-fragile and unsafe.
- Treat each left+right pair as one number for alternating exercises: harder to follow and conflicts with per-side balancing disclosure.
- Infinite `Раз/Два`: no target/progress and directly conflicts with requested real count.
- Auto-mark target completed when virtual cadence ends: falsely implies observed execution.
- Camera/motion/speech recognition: outside scope, permissions/privacy burden, no validated accuracy contract.
- Convert old timed payloads to reps by exercise id: silently changes historical plan behavior.
- Let TTS completion drive the timer: nondeterministic across devices/voices.
- Catch up all missed counts after background/late tick: noisy, misleading and unsafe for state consistency.

## 15. Handoff

**Result:** defined an implementation-ready split for all 10 starter exercises: two time-based holds and eight repetition-based sets with exact target/cadence/estimate tables for every intensity and target duration.

**Artifact:** `docs/exercise-prescription-contract.md`.

**Decisions:** per-side alternating counts each side as the next numbered rep; paced count is explicitly not movement recognition; a rep set requires user confirmation; legacy duration-only Codable payload stays timed; generator budgets resolved estimated duration.

**Contract:** downstream roles may rely on §§3–10 for data/state/UI/voice behavior, §11 for fixtures and §12 for acceptance gates.

**Analyst verification:** independent arithmetic check confirmed every repetition estimate, even per-side targets, cadence `>= 2.0 s` and maximum target 22. A repository-baseline simulation of the current deterministic ranking/assembly over 264 cases (`11 durations × 3 intensities × 8 canonical focus sets`) placed all plans within ±30 seconds; maximum observed deviation was 28 seconds. `git diff --no-index --check /dev/null docs/exercise-prescription-contract.md` produced no whitespace diagnostics (exit 1 only because the artifact is a new untracked file); `git status --short -- ios` was empty, confirming no production-tree changes from this task.

**Verification required:** iOS still must run the implementation-level deterministic unit/UI suites and generator grid; designer supplies all annotated states; independent QA performs real ru-RU/VoiceOver/lifecycle/device passes. The analyst simulation validates contract feasibility, not production implementation.

**Risks:** no sensor truth, installed TTS variability, generator assembly regression, expanded outcome/state migration; mitigations are specified in §14.

**Next roles:** designer `t_855239fc` → iOS `t_7304a9b5` → independent QA `t_5b6a6c07` with completion gates in §13.

Applicable standards: `/home/hermes/.hermes/team-agent-os/standards/delivery/task-lifecycle.md`, `delivery/handoff.md`, `engineering/security.md`. Project-specific `agent-os/` is absent; repository evidence is listed in §1.
