# ABS Trainer v2 — продуктовый и state contract focus / intensity

Статус: implementation-ready product contract

Kanban: `t_dbd803e2`

Следующая задача: `t_1d470ae0` (`ios`)

Платформа: iOS-only SwiftUI MVP, полностью локально

## 0. Решение и приоритет источников

Этот документ закрывает разрыв между утверждённым направлением Setup и текущей моделью. Он является источником истины для реализации `focus`, `intensity`, `duration` и снимка параметров в плане.

Приоритет при конфликте:

1. Прямое продуктовое решение в задаче `t_dbd803e2`: focus и intensity входят в v2.
2. Этот domain contract.
3. Утверждённые визуальные артефакты `design/user-review-v2/` для композиции и стиля.
4. Текущий production-код как описание существующего поведения, но не как разрешение неявного product scope.

Поэтому строка `design/user-review-v2/README.md:11` о том, что intensity не показана из-за отсутствия поля, считается устранённым доменным blocker, а не решением удалить intensity из v2. PNG остаётся эталоном стиля и порядка существующих элементов, но iOS должен добавить компактный выбор intensity в Setup без AI-функций, backend или медицинских обещаний.

Коротко:

- **Focus** — одна или несколько зон пресса; `full` взаимоисключающая альтернатива.
- **Intensity** — предпочтительная сложность упражнений, а не скорость таймера, пульс, калории или медицинская нагрузка.
- **Duration** — только 5 / 10 / 15 минут, default 10.
- Все параметры живут локально в памяти и копируются в неизменяемый `WorkoutPlan` при генерации.
- Генератор использует focus для фильтрации, intensity для состава/порядка difficulty, duration для целевого времени.

## 1. Evidence и наблюдаемое текущее состояние

| Вывод | Evidence |
|---|---|
| MVP локальный, без backend/регистрации; длительность 5/10/15; зоны upper/lower/obliques/full | `docs/product-spec.md:3-21` |
| `AbsZone` уже имеет стабильные Codable raw values и четыре значения | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:3-28` |
| `Difficulty` уже имеет beginner/intermediate/advanced | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:30-34` |
| `WorkoutPlan` сейчас хранит target duration, zones и items, но не intensity | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:61-73` |
| Setup default: 10 минут, `[.full]`; состояние — `@State` без disk persistence | `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift:10-19` |
| UI уже передаёт duration и zones в локальный generator | `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift:187-198` |
| `full` сейчас exclusive; пустой multi-select автоматически возвращается к `full` | `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift:166-184` |
| Duration dial уже использует единый `[5,10,15]` contract | `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift:112-121`, `ios/AbsTrainer/Sources/AbsTrainer/DesignSystem.swift:330-346` |
| Generator локальный: фильтрует по zones, добирает full и строит items без сети | `ios/AbsTrainer/Sources/AbsTrainer/WorkoutGenerator.swift:3-66` |
| Каталог содержит beginner/intermediate; advanced сейчас отсутствует | `ios/AbsTrainer/Sources/AbsTrainer/ExerciseCatalog.swift:3-16` |
| Сессия имеет exercise/rest/finished, deadline-based tick, pause и skip | `ios/AbsTrainer/Sources/AbsTrainer/WorkoutSessionStore.swift:4-129` |
| Approved Setup показывает duration dial, четыре zone choices и CTA; intensity визуально ещё отсутствует | `design/user-review-v2/01-setup.png`, `design/user-review-v2/README.md:19-30` |
| Design требует local flow и не допускает вымышленные метрики | `docs/design-active-rest-finish-audit.md:30-37` |

## 2. Domain entities

### 2.1 `AbsZone` — muscle focus

Существующий enum сохраняется без изменения raw values:

| Raw value | UI title | Семантика |
|---|---|---|
| `upper` | `Верхний пресс` | упражнения, где `Exercise.zones` содержит `.upper` |
| `lower` | `Нижний пресс` | упражнения, где `Exercise.zones` содержит `.lower` |
| `obliques` | `Косые мышцы` | упражнения, где `Exercise.zones` содержит `.obliques` |
| `full` | `Весь пресс` | универсальный режим; разрешает весь каталог |

Тип выбора: `Set<AbsZone>` в Setup, канонический `[AbsZone]` в plan/generator.

Инварианты:

1. Выбор непустой.
2. `.full` не сосуществует с другими значениями.
3. Нажатие `.full` заменяет выбор на `{.full}`.
4. Нажатие specific zone удаляет `.full`, затем toggle-ит эту zone.
5. Снятие последней specific zone нормализует выбор в `{.full}` и даёт одно доступное announcement.
6. Перед генерацией значения дедуплицируются и сортируются по `AbsZone.allCases`; сериализация/тесты не должны зависеть от порядка `Set`.
7. Любой внешний invalid/empty input нормализуется в `[.full]`; `[.full, ...]` нормализуется в `[.full]`.

### 2.2 `WorkoutIntensity` — новый entity

Добавить Codable/CaseIterable/Identifiable enum со стабильными raw values:

| Raw value | UI title | Default | Product meaning |
|---|---|---:|---|
| `light` | `Мягкая` | нет | преимущественно beginner exercises |
| `balanced` | `Обычная` | **да** | beginner + intermediate, сбалансированный порядок |
| `high` | `Высокая` | нет | преимущественно intermediate/advanced, с безопасным fallback |

Термин в UI: **«Интенсивность упражнений»**, не просто «Сложность» и не «Уровень подготовки».

Intensity не означает:

- частоту сердечных сокращений, калории, персональную физиологическую оценку;
- изменение скорости countdown;
- сокращение авторского отдыха или увеличение `defaultDurationSec`;
- медицинскую рекомендацию;
- AI-персонализацию.

Такое узкое определение позволяет использовать уже имеющийся `Exercise.difficulty` (`Models.swift:30-50`) без новых датчиков, профиля и небезопасных вычислений.

### 2.3 `WorkoutSetup` — mutable Setup state

Рекомендуемый value type для единой границы валидации:

| Field | Type | Allowed | Default |
|---|---|---|---|
| `targetDurationMin` | `Int` | `5, 10, 15` | `10` |
| `selectedZones` | `Set<AbsZone>` | по инвариантам §2.1 | `{.full}` |
| `intensity` | `WorkoutIntensity` | `light/balanced/high` | `.balanced` |

Если отдельный `WorkoutSetup` не вводится, те же три поля и единая normalization function обязательны в `ContentView`/generator boundary. UI не является единственной защитой.

### 2.4 `WorkoutPlan` — immutable snapshot

Добавить в `WorkoutPlan`:

- `let intensity: WorkoutIntensity`

План фиксирует нормализованные `targetDurationMin`, `selectedZones`, `intensity` и generated `items`. После перехода в Plan/Active изменение Setup state не меняет существующий план.

`WorkoutItem` и `Exercise` в v2 не получают отдельное intensity поле: фактическая сложность остаётся в `WorkoutItem.exercise.difficulty`.

## 3. Defaults, validation и persistence

### 3.1 Duration

- Allowed: `[5, 10, 15]` minutes.
- Default/cold launch: `10`.
- Nearest normalization для invalid integer: ближайшее allowed; tie идёт к меньшему значению (совпадает с `DurationDialContract.nearestIndex`, `DesignSystem.swift:330-345`).
- CTA и generator принимают только normalized value.
- Product promise: фактическое активное время плана как можно ближе к target и в нормальном starter catalog находится в допуске ±30 секунд.

### 3.2 Setup lifetime

| Событие | Поведение |
|---|---|
| Cold launch / новый `ContentView` | `10`, `{full}`, `balanced` |
| Setup → Plan | создать immutable plan snapshot |
| Назад Plan → Setup | сохранить текущий in-memory Setup selection |
| Finish → `Повторить тренировку` | использовать тот же plan/items; не регенерировать и не читать изменившийся Setup |
| Finish → `Настроить новую` | удалить active plan/path, но сохранить три Setup selections в памяти |
| Process termination / reinstall | сбросить к defaults |
| Background/foreground в живом process | сохранить SwiftUI state; active deadline reconciles существующим store |

### 3.3 Что не сохраняется

В v2 запрещено добавлять ради этих параметров `AppStorage`, `UserDefaults`, SwiftData/Core Data, iCloud/CloudKit, account sync, analytics или backend. Session progress также не восстанавливается после process termination. Codable conformance — форма данных и задел, а не разрешение на disk persistence.

## 4. UI → model mapping

### 4.1 Setup control order

Сохранить существующую approved композицию и добавить одну compact section:

1. Header.
2. Duration dial (`Сколько времени?`).
3. Focus (`Куда нагрузка?`).
4. Intensity (`Интенсивность упражнений`).
5. Pinned CTA `Собрать тренировку`.

Если compact/AX3 требует прокрутки, intensity уходит ниже fold, но остаётся перед CTA в reading order. CTA в `safeAreaInset` не должен перекрывать последнюю option.

### 4.2 Mapping table

| UI | Model write | Rules |
|---|---|---|
| Dial / `−` / `+` | `setup.targetDurationMin` | только 5/10/15; disabled during generation |
| Zone cell | `setup.selectedZones` | multi-select specific zones; `full` exclusive; минимум одна zone |
| Intensity choice | `setup.intensity` | single-select; default balanced; нельзя deselect до nil |
| `Собрать тренировку` | `generator.generate(setup:)` либо три explicit args | normalize once, block duplicate taps, create plan snapshot |
| Plan summary | read `plan.targetDurationMin/selectedZones/intensity` | не читать mutable Setup state |
| Repeat | reuse current `WorkoutPlan` | тот же состав и параметры |
| New workout | clear plan, show retained Setup state | без disk write |

Intensity visual implementation использует существующий плоский Tempo choice language; это single-selection control. Не добавлять анатомическую illustration, slider без дискретных значений, AI badge или второй primary CTA.

## 5. Generator contract

### 5.1 Input and output

Логическая сигнатура:

`generate(targetDurationMin: Int, selectedZones: [AbsZone], intensity: WorkoutIntensity) -> WorkoutPlan`

Preconditions после normalization:

- duration ∈ `{5,10,15}`;
- zones — non-empty canonical array по §2.1;
- intensity — один enum value;
- catalog может быть пустым: generator не зависает и возвращает controlled failure/empty result, а UI не стартует session с empty plan.

Output:

- unique plan/item ids;
- normalized parameters copied to plan;
- non-empty items for non-empty compatible starter catalog;
- sequential `order` from 1;
- no unused final rest in `WorkoutPlan.totalDurationSec` (существующая формула: `Models.swift:67-72`).

### 5.2 Focus filtering

1. `[.full]` разрешает весь catalog.
2. Specific zones: primary candidates имеют непустое пересечение `exercise.zones ∩ selectedZones`.
3. Если после intensity ranking меньше четырёх unique primary candidates, добавить compatible `.full` exercises.
4. Fallback расширяет выбор только настолько, насколько нужен non-empty/repeatable plan; plan продолжает показывать пользовательский selected focus, а строки честно показывают фактические exercise zones.
5. Не ставить одинаковое упражнение два раза подряд, если pool содержит хотя бы два разных упражнения.

Это сохраняет продуктовые правила `docs/product-spec.md:155-180` и текущую фильтрацию `WorkoutGenerator.swift:50-64`.

### 5.3 Intensity ranking and eligibility

Intensity меняет **состав и порядок difficulty**, но не авторские work/rest durations.

| Intensity | Preferred tier | Allowed fallback order |
|---|---|---|
| `light` | beginner | beginner in selected focus → beginner full → compatible intermediate только если иначе нельзя построить non-empty plan |
| `balanced` | beginner + intermediate, чередовать где возможно | selected focus → full; advanced не включать |
| `high` | intermediate, затем advanced | preferred selected focus → preferred full → beginner selected focus → beginner full |

Дополнительное ограничение из `docs/product-spec.md:166-176`: для target 5 минут advanced не используется даже при `.high`.

В starter catalog advanced отсутствует (`ExerciseCatalog.swift:3-16`). Поэтому `.high` в текущем MVP наблюдаемо ставит intermediate раньше beginner, но не обещает «экстремальную» программу. Добавление advanced catalog items в будущем автоматически начинает влиять только на high 10/15; это требует отдельного контентного QA, но не изменения enum contract.

### 5.4 Duration assembly

- Использовать `Exercise.defaultDurationSec` и `restAfterSec` без intensity multipliers.
- Финальный `restAfterSec` не исполняется и не входит в `totalDurationSec`.
- При добавлении следующего item сравнивать исполняемую total duration, а не сумму с неиспользуемым final rest.
- Выбрать ближайший non-empty вариант к target; при равном отклонении выбрать не превышающий target.
- Для starter catalog acceptance: `abs(plan.totalDurationSec - targetDurationMin * 60) <= 30`.
- Если custom/empty catalog не позволяет ±30, вернуть ближайший возможный non-empty plan и не подменять target label фактической длительностью; диагностировать локально без PII. Empty catalog должен дать controlled generation error, не `WorkoutSessionStore` precondition crash.

### 5.5 Determinism

Текущий generator фактически детерминирован относительно catalog order, кроме UUID (`WorkoutGenerator.swift:20-47`). V2 не требует random/AI shuffle. Для unit tests generator должен позволять фиксированный catalog и проверять difficulty order независимо от UUID.

## 6. Application and session state machine

### 6.1 App route states

Фактический критический путь:

`Setup → Plan → Active.exercise ↔ Rest → Finish`

В формулировке acceptance `Setup → Active → Rest → Finish` экран Plan является подтверждением созданного immutable plan и не меняет параметры.

| State | Entry | Allowed actions | Exit |
|---|---|---|---|
| Setup | launch/new workout/back from Plan | edit duration/focus/intensity; generate | valid generation → Plan |
| Generating (Setup substate) | CTA | inputs/CTA disabled; retain visible values | success → Plan; failure → Setup + inline error |
| Plan | plan snapshot exists | back, start | back → Setup; start → Active.exercise |
| Active.exercise | non-empty plan, index valid | tick, pause, next/finish, request exit | deadline/next → Rest or Finish |
| Active.paused | pause action | resume; request exit | resume → same exercise/deadline rebased |
| Rest | completed non-final exercise with rest > 0 | tick, skip rest, request exit | deadline/skip → next Active.exercise |
| Finish | final exercise completes/finishes early after confirmation | repeat, new workout | repeat → same Plan; new → Setup |

### 6.2 Session invariants

Основаны на `WorkoutSessionStore.swift:25-129`:

- Active starts at item 0 with its `durationSec`.
- Deadline, not timer tick count, is source of truth.
- Late tick can reconcile exercise → rest → next exercise in one call.
- Pause allowed only in exercise; it freezes remaining interval.
- `next`/`skipExercise` completes current exercise early and increments `completedExerciseCount` once.
- Non-final exercise with `restAfterSec > 0` enters Rest.
- Zero rest starts next exercise immediately.
- Last exercise enters Finish directly; no final Rest.
- Skip Rest never increments completed count and starts exactly the next item.
- Repeated transition taps must be blocked so index/count do not advance twice.
- `WorkoutSessionStore` must not be created for empty plan.

### 6.3 Confirmation overlays

Exit and early-last-finish confirmations are presentation substates, not new workout phases. Opening a modal freezes/blocks underlying actions; cancel returns to the same phase/control; destructive action performs exactly one route transition. Contract/copy/accessibility follow `docs/design-active-rest-finish-audit.md:111-152`.

## 7. Edge cases and normalization

| Case | Expected result |
|---|---|
| Empty zones | normalize to `[.full]` and announce once if caused by user deselection |
| `.full` plus specific zones | normalize to `[.full]` |
| Unordered/duplicated zones | deduplicate and order by `AbsZone.allCases` |
| Invalid duration binding | nearest 5/10/15; tie lower; DEBUG assertion + safe release normalization |
| Missing intensity from old decoded fixture | migration/default `.balanced`; no crash |
| Empty catalog | generation failure in Setup; no navigation to Plan/session |
| Focus + light has very small pool | full/balanced fallback per §5.2/5.3; repetition allowed, never adjacent if avoidable |
| High with no advanced | prioritize intermediate; no fabricated advanced label/content |
| 5-minute high with advanced future catalog | advanced excluded |
| Generate double tap | one generation and one Plan push |
| Parameter change while generating | controls disabled; plan snapshot matches displayed committed values |
| Last item rest > 0 | ignore final rest in execution/summary |
| App killed in session | no resume; next launch uses Setup defaults |
| Dynamic Type/compact | all inputs reachable by vertical scroll; pinned CTA does not cover intensity |

## 8. Accessibility and localization contract

Все строки должны быть в `Resources/Localizable.xcstrings`; Russian source copy нельзя собирать конкатенацией там, где нужна pluralization.

### Duration

- Adjustable label: `Длительность тренировки`.
- Value: plural-aware `5 минут` / `10 минут` / `15 минут`.
- `−`: `Уменьшить длительность на 5 минут`.
- `+`: `Увеличить длительность на 5 минут`.
- Reading order and behavior: `docs/design-duration-dial.md:268-299`.

### Focus

- Group/heading: `Куда нагрузка?` / accessibility label `Зона нагрузки`.
- Group hint: `Можно выбрать несколько зон. Весь пресс отменяет выбор отдельных зон.`
- Cells use full titles from §2.1 and `.isSelected`; не добавлять отдельное слово «выбрано» как второй focusable child.
- Когда последняя specific zone снята: announcement `Выбран весь пресс, потому что должна остаться хотя бы одна зона` (существующее поведение `ContentView.swift:178-183`).

### Intensity

- Heading/accessibility label: `Интенсивность упражнений`.
- Group hint: `Выберите один вариант. Интенсивность меняет сложность упражнений.`
- Options: `Мягкая`, `Обычная`, `Высокая`; каждая single-select button с `.isSelected`.
- Не озвучивать неподтверждённые обещания вроде «сжигает больше калорий» или «подходит вашему здоровью».

### CTA and plan

- CTA: `Собрать тренировку`; loading label должен сообщать `Собираем тренировку` и блокировать повторную activation.
- Plan accessibility summary: duration + canonical focus + intensity, например `10 минут, весь пресс, обычная интенсивность`.
- Intensity должна быть видима/озвучиваема на Plan, чтобы пользователь мог проверить snapshot до Start.

Общий Setup VoiceOver order: heading → duration dial → decrement → increment → focus heading/options → intensity heading/options → CTA.

## 9. Минимальный iOS file plan

Production-код в этой аналитической задаче не меняется. Следующая `ios`-задача должна ограничиться:

| Файл / symbol | Минимальное изменение |
|---|---|
| `Sources/AbsTrainer/Models.swift` | добавить `WorkoutIntensity`; добавить `WorkoutPlan.intensity`; при необходимости `WorkoutSetup`/normalizer |
| `Sources/AbsTrainer/ContentView.swift` | `@State intensity = .balanced`; intensity single-select section; canonical zones; передать intensity в generator; сохранить in-memory behavior |
| `Sources/AbsTrainer/WorkoutGenerator.swift` | принять/нормализовать intensity; tiered filter/order; validation/empty-catalog result; executable-duration assembly |
| `Sources/AbsTrainer/WorkoutPlanView.swift` | показать/озвучить intensity и canonical focus из plan snapshot |
| `Sources/AbsTrainer/PreviewFixtures.swift` | обновить fixture generation call |
| `Sources/AbsTrainer/DesignSystem.swift` | duration dial contract не менять; использовать существующий choice language либо добавить только узкий single-select variant |
| `Resources/Localizable.xcstrings` | intensity/group/hint/error/plan summary strings и plural-aware duration |
| `Tests/AbsTrainerTests/WorkoutGeneratorTests.swift` | normalization, focus×intensity matrix, duration tolerance, no adjacent duplicate, empty catalog |
| `Tests/AbsTrainerTests/WorkoutSessionStoreTests.swift` | сохранить transitions; добавить zero-rest/final-rest/double-action guard при затронутой логике |
| `Tests/AbsTrainerUITests/AbsTrainerUITests.swift` | defaults, focus exclusivity, intensity single-select, disabled generating, plan snapshot, compact/AX3 reading/reachability |

`ExercisePlayerView.swift` и `FinishView.swift` не требуют domain-изменений для intensity: player исполняет уже созданные `WorkoutItem`, repeat использует тот же plan.

## 10. Acceptance matrix

| ID | Acceptance | Automated evidence | Manual evidence | Pass rule |
|---|---|---|---|---|
| AC-01 | Defaults | unit/UI test cold Setup | standard screenshot | 10 + full + balanced |
| AC-02 | Focus invariant | unit tests all toggle/normalization paths | VoiceOver selection pass | non-empty; full exclusive; canonical order |
| AC-03 | Intensity invariant | enum/selection tests | visible three-option section | exactly one; balanced default |
| AC-04 | Duration invariant | existing `DurationDialContractTests` + generator boundary tests | dial/step interaction | generator sees only 5/10/15 |
| AC-05 | Plan snapshot | unit/UI route test | back/repeat/new walkthrough | plan retains all 3 params; repeat does not regenerate |
| AC-06 | Focus generation | fixed-catalog tests per zone/full | inspect generated plan | primary items intersect focus; documented full fallback only |
| AC-07 | Intensity generation | fixed mixed-difficulty catalog tests | Plan order/content review | light/balanced/high follow §5.3; high 5 excludes advanced |
| AC-08 | Time generation | tests for 5/10/15 × 3 intensities | Plan totals | starter catalog executable total within ±30 s; final rest excluded |
| AC-09 | Empty/custom catalog | unit tests | inline error screenshot | no infinite loop/precondition crash/navigation to session |
| AC-10 | Session states | `WorkoutSessionStoreTests` | full flow | Setup/Plan/Exercise/Rest/Finish and pause/skip rules match §6 |
| AC-11 | Persistence scope | code search + lifecycle UI test | relaunch walkthrough | in-memory retained; cold launch defaults; no disk/cloud/backend |
| AC-12 | Accessibility | identifiers/order/traits UI tests | real VoiceOver + AX3 | exact labels/selected semantics; all controls reachable |
| AC-13 | Compact/layout | responsive UI tests/screenshots | 320×700, AX3 portrait/landscape | intensity and CTA reachable, no overlap/horizontal scroll |
| AC-14 | Scope/security | dependency/import and git diff review | reviewer check | no AI/network/analytics/account/persistence/credential changes |

## 11. Risks and rejected alternatives

### Risks

1. **Approved PNG has no intensity.** Mitigation: этот contract является последующим product approval; iOS добавляет только компактную Tempo single-select section, после чего нужен screenshot parity review.
2. **Intensity может восприниматься как медицинская нагрузка.** Mitigation: narrow difficulty semantics, нейтральные labels, никаких калорий/пульса/персональных рекомендаций.
3. **Starter catalog не содержит advanced.** High всё равно наблюдаемо меняет порядок к intermediate; нельзя обещать advanced до появления проверенного контента.
4. **Малый pool при specific focus/light.** Явный full/fallback contract и запрет adjacent duplicate при наличии альтернативы.
5. **Текущий duration loop считает добавленный final rest при остановке, тогда как plan total его исключает.** iOS должен использовать executable-duration rule §5.4 и покрыть матрицей 5/10/15.
6. **`Set` даёт нестабильный порядок зон.** Канонизировать перед generator/plan/UI summary.

### Rejected

- Continuous intensity slider: обещает точность, которой нет в трех difficulty tiers.
- Intensity через сокращение rest/увеличение work: меняет авторские интервалы и безопасность без контентного решения.
- AI-generated/personalized plan: вне scope и не имеет backend/model contract.
- Disk/cloud persistence: вне локального MVP v2.
- Single muscle zone only: отклонено; текущий approved UI и product spec поддерживают multi-select.
- Считать intensity чисто декоративным UI: отклонено; каждый выбор обязан наблюдаемо менять generator ranking.

## 12. Handoff

**Result:** определён однозначный продуктовый/domain/state contract focus + intensity + duration для локального ABS Trainer v2.

**Artifact:** `docs/abs-trainer-v2-domain-contract.md`.

**Decisions:** focus остаётся multi-select с exclusive full; intensity — discrete difficulty preference `light/balanced/high`, default balanced; duration остаётся 5/10/15, default 10; persistence только in-memory; plan — immutable snapshot.

**Contract:** iOS может полагаться на §§2-8; generator mapping обязателен и не меняет authored work/rest timings.

**Verification required from iOS:** acceptance matrix §10, unit/UI tests, real simulator screenshots 393×852 + 320×700 + AX3/landscape, manual VoiceOver, independent QA.

**Risks:** approved Setup PNG требует узкого visual update для intensity; advanced content отсутствует; Xcode evidence не выполняется аналитической карточкой и остаётся gate iOS/QA.

**Next:** `ios`, задача `t_1d470ae0`: реализовать минимальный file plan §9 и передать независимой QA.

Applicable standards: `/home/hermes/.hermes/team-agent-os/standards/delivery/task-lifecycle.md`, `delivery/handoff.md`, `engineering/security.md`; project sources перечислены в §1.
