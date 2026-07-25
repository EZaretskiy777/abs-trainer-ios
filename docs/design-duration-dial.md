# ABS Trainer «Темп / Срез» — круговой выбор длительности

Статус: implementation-ready design handoff  
Задача: `t_00afd5b0`  
Платформа: iOS / SwiftUI  
Экран: Setup / «Соберите свой темп»  
Эталон: `design/tempo-cut/previews/tempo-cut-home.png`  
Preview: `design/tempo-cut/previews/duration-dial-spec.png`

Preview generator: `design/tempo-cut/duration-dial-preview.py`. Checked PNGs use locally staged Google Fonts Noto Sans variable files: `NotoSans.ttf` SHA-256 `bfb7bb691513f12e734dc346c03a03f784912432d7e3fa8e56efcf906fe86b3d`, `NotoSansMono.ttf` SHA-256 `2cb2adb378a8f574213e23df697050b83c54c27df465a2015552740b2769a081`. These fonts are generation inputs, not app assets; production uses the iOS system font.

## 1. Решение в одном абзаце

Три прямоугольные кнопки `05 / 10 / 15` заменяются одним круговым `DurationDial` с большой центральной величиной, 270-градусной дугой, тремя честными остановками, видимым handle и отдельными кнопками `−` / `+`. Допустимые значения остаются **5, 10 и 15 минут**: диапазон `5...15`, шаг `5`, стартовое значение `10`. Drag и tap по дуге ускоряют выбор, но не являются единственным путём: `−` / `+`, VoiceOver adjustable actions и аппаратная клавиатура дают эквивалентный доступ. Компонент использует Chalk/Carbon/Vermilion, системный SF Pro и плоскую графику без карточки, тени, градиента или декоративной метрики.

## 2. Продуктовая рамка

- Пользователь: человек, который хочет быстро собрать короткую локальную тренировку пресса без регистрации.
- Контекст: выбор параметров перед тренировкой, часто одной рукой, возможно после физической нагрузки.
- Primary job: выбрать понятную длительность и перейти к плану без вычислений и точного наведения.
- Primary action экрана: `Собрать тренировку`; dial остаётся вторичным input-контролом.
- Бизнес-результат: сохранить быстрый MVP-путь Setup → Plan и не обещать точность, которой генератор не гарантирует.
- Success: новое значение выбирается любым поддержанным путём максимум за два шага; план получает только поддержанный `targetDurationMin`.

### 2.1 Источники и evidence level

| Источник | Полезный паттерн | Что не копировать | Evidence |
|---|---|---|---|
| `docs/product-spec.md:12, 155–176` | Домен 5/10/15, план максимально близок к цели с допуском ±30 с | Не расширять минутную точность без продуктового решения | observed |
| `ContentView.swift:10, 18, 95–123, 190–200` | Default 10, single selection, значение напрямую идёт в generator | Не сохранять старые три cards рядом с dial | observed |
| `WorkoutGenerator.swift:10–47` | `targetDurationMin` переводится в секунды; алгоритм не валидирует диапазон | Не считать техническую способность принять `Int` продуктовым разрешением | observed |
| Approved `tempo-cut-home.png` | Chalk canvas, Carbon type, плоская композиция, 20 pt inset, один bottom CTA | Не вводить elevation, glass, gradient или второй primary CTA | observed |
| iOS familiar adjustable-control model | Drag/tap дополняются Stepper-like `−/+`; VoiceOver меняет значение increment/decrement | Не делать custom gesture единственным способом | inferred; web browsing/Figma unavailable in this run |
| Apple accessibility target convention | Интерактивная область не менее 44×44 pt, Dynamic Type и VoiceOver semantics | Не использовать маленький handle как фактический hit target | inferred; подтверждается team standard `design/ui-ux.md` |

## 3. Value contract — решение, а не скрытое изменение логики

| Поле | Контракт |
|---|---|
| `allowedValues` | `[5, 10, 15]` минут, строго по возрастанию |
| `minimumValue` | `5` минут |
| `maximumValue` | `15` минут |
| `step` | `5` минут |
| `initialValue` | `10` минут на холодном запуске |
| In-session last value | Последний подтверждённый выбор сохраняется текущим `@State` при Setup → Plan → Setup и `Настроить новую`; disk persistence не добавляется |
| Cold launch | Снова `10`; `AppStorage`/профиль пользователя вне scope |
| Generator input | Только одно из `[5, 10, 15]` |
| Plan promise | Цель в минутах; фактический план остаётся максимально близким с допуском ±30 с |

### Почему не шаг 1 минута

1. Product spec и существующие UI tests называют только 5/10/15.
2. Генератор принимает произвольный `Int`, но не валидирует новый диапазон и собирает интервалы по 35–45 с плюс отдых 10–15 с.
3. Шкала по минутам визуально обещала бы более высокую точность, чем текущий допуск ±30 с.
4. Добавление 6–14 минут изменило бы продуктовый scope, тестовую матрицу, локализованный plan copy и ожидания пользователя.

Если в будущем продукт утвердит шаг 1, менять нужно единый value contract, generator validation и тесты; геометрия dial уже поддерживает произвольный массив stops, но этот handoff их **не разрешает**.

## 4. Рассмотренные направления

### A — Полный «приборный» круг 360°

- Thesis: максимально буквальный циферблат с цифрами по окружности.
- Signature: полный Vermilion progress ring.
- Плюс: сильный новый визуальный акцент.
- Риск: seam между min/max неоднозначен, три значения выглядят искусственно, графика конкурирует с H1.
- Решение: отклонено.

### B — Открытый 270° dial + `−/+` (выбран)

- Thesis: открытый снизу круг читается как конечная шкала, а не бесконечное время.
- Signature: короткая Vermilion дуга и Carbon handle на одном плоском поле.
- Плюс: однозначные min/mid/max, крупное значение, место для accessible alternatives.
- Риск: выше старого segmented control; Setup должен оставаться scrollable.
- Решение: выбран.

### C — Нативный compact picker/stepper без дуги

- Thesis: системная узнаваемость и минимальная моторная нагрузка.
- Signature: крупное число между `−/+`.
- Плюс: самый простой accessibility path.
- Риск: не выполняет запрос на круговой циферблат и теряет distinctive Tempo/Cut gesture.
- Решение: использовать только как fallback при невозможности custom rendering, не как primary design.

## 5. Component contract

### 5.1 Идентификаторы

- Product name: `DurationDial`.
- Figma component/variant target: `Inputs / Duration Dial / {Default, Pressed, Disabled} / {Standard, Compact, AX}`.
- SwiftUI suggested symbol: `TempoDurationDial`.
- Accessibility identifier: `setup.durationDial`.
- Child identifiers: `setup.durationDial.decrement`, `setup.durationDial.increment`.
- Figma blocker: approved Figma workspace/destination и credentials в задаче отсутствуют. Repository doc + PNG являются inspectable source for this handoff; перенести component в Figma до production design lock.

### 5.2 Когда использовать / не использовать

Использовать для небольшого упорядоченного набора длительностей, когда текущее число важнее списка вариантов. Не использовать как scrubber секунд, таймер обратного отсчёта, выбор времени суток или для десятков точных значений. Dial не управляет активной тренировкой.

### 5.3 Anatomy

1. `A` Section header: `Сколько времени?`; справа/в stacked mode — `10 минут`.
2. `B` Dial canvas: прозрачный, без отдельной card surface.
3. `C` Base track: незаполненная дуга.
4. `D` Progress arc: от minimum до текущего stop.
5. `E` Major ticks: ровно три, соответствуют 5/10/15.
6. `F` Handle: видимый 24 pt диск; фактическая gesture area — вся 44 pt зона вокруг него и вся дуга.
7. `G` Center value: `10`, tabular/monospaced digits.
8. `H` Unit: `минут`, отдельной строкой.
9. `I` Range context: `5 · 10 · 15` визуально скрывать — ticks и central value достаточно; доступная label содержит диапазон.
10. `J` Decrement / increment buttons: отдельные круги `−` и `+`.

### 5.4 Arc geometry

- Sweep: `270°`; нижний gap: `90°`.
- Clock-face definition: minimum в **7:30**, midpoint в **12:00**, maximum в **4:30**; движение min → max идёт по часовой стрелке через верх.
- Normalized position: `(index / (allowedValues.count - 1))`, то есть `0`, `0.5`, `1`.
- Track/progress line cap: round.
- Drag за пределами sweep clamp-ится к ближайшему endpoint; переход через нижний gap не перескакивает с 5 на 15.
- Только major ticks. Minor ticks запрещены: они намекали бы на несуществующие промежуточные минуты.

## 6. Visual tokens

### 6.1 Цвета

| Semantic token | HEX | sRGB | Использование | Контраст на Chalk |
|---|---|---|---|---:|
| `surface.canvas` | `#F5F1E8` | `245, 241, 232` | Setup canvas | — |
| `surface.subtle` | `#ECE5D8` | `236, 229, 216` | Base track / disabled fill | — |
| `text.primary` | `#171714` | `23, 23, 20` | Value, labels, handle | `15.94:1` |
| `text.secondary` | `#55534D` | `85, 83, 77` | Unit / helper | `6.82:1` |
| `action.progress` | `#D13A25` | `209, 58, 37` | Active progress arc / selected tick | `4.29:1` |
| `border.hairline` | Carbon at `16%` | — | Control outlines | декоративный; Increase Contrast uses 32% |
| `focus.ring` | `#171714` | `23, 23, 20` | Switch Control / keyboard focus outline | `15.94:1` |

Vermilion используется только для выбранной дуги/tick, не для текста или второго CTA. Значение не кодируется только цветом: central value, handle position, tick weight, accessibility value и enabled states дублируют состояние.

### 6.2 Typography

| Role | SwiftUI intent | Standard | AX3 behavior |
|---|---|---:|---|
| Section title | `.title3.weight(.semibold)` | 20/24 | перенос, не truncate |
| Header value | `.caption.weight(.semibold)` | 13/16 | stack под title |
| Center value | relative `.largeTitle`, bold, monospaced digits | 56/56 | scaled cap ≈72 pt; `minimumScaleFactor(0.82)` only inside bounded dial |
| Unit | `.callout.weight(.semibold)` | 16/20 | до 2 строк, center |
| `−/+` symbols | `.title2.weight(.semibold)` | 22 | symbol size may scale, hit target fixed minimum |

Русская единица для текущего MVP: `5 минут`, `10 минут`, `15 минут`. Не собирать локализацию конкатенацией; использовать plural-aware localized format.

### 6.3 Dimensions and spacing

| Token | Standard portrait | Compact portrait 320 | AX3 / landscape |
|---|---:|---:|---:|
| Component outer width | container, max 353 | 280 | max 353 per column |
| Dial diameter | 216 pt | 184 pt | 184 pt in AX; 168 pt landscape |
| Arc radius | 92 pt | 77 pt | diameter/2 − 16 |
| Track width | 10 pt | 9 pt | 9 pt |
| Progress width | 10 pt | 9 pt | 9 pt |
| Tick length / width | 12×2 pt | 10×2 pt | 10×3 with Increase Contrast |
| Handle visible | 24 pt | 22 pt | 24 pt |
| Handle ring | 3 pt Chalk + 1 pt Carbon | same | 4 pt in Increase Contrast |
| Handle gesture target | min 44×44 pt | min 44×44 | min 44×44 |
| `−/+` visual button | 52×52 pt | 48×48 pt | 52×52; AX may stack below |
| Gap between step buttons | 72 pt | 56 pt | 24 pt minimum |
| Dial → step controls | 8 pt | 4 pt | 8 pt |
| Header → dial | 8 pt | 4 pt | 8 pt |
| Component bottom spacing | 24 pt to next section | 20 pt | 20 pt |

No shadow, blur, gradient, bezel, inner card, glow or skeuomorphic texture.

## 7. Interaction contract

### 7.1 Drag

1. `touchDown` anywhere on the 44 pt expanded arc corridor starts tracking; touching center does not change value.
2. Convert touch to clock angle, clamp to 270° sweep, map to normalized position.
3. Preview snaps visually to nearest valid stop; no continuous intermediate number is shown.
4. Crossing a snap midpoint commits the new value immediately and emits one selection haptic.
5. Remaining within the same stop emits no repeated haptic.
6. `touchUp` keeps the last valid stop. Cancel/interruption returns to the last committed valid stop; no phantom value.

### 7.2 Tap

- Tap in the expanded arc corridor selects the nearest stop.
- Tap on a major tick selects that stop.
- Tap near the lower 90° gap does nothing; the gap is not an endpoint shortcut.
- Tap center value does nothing and is not a separate button.

### 7.3 `−/+` alternative

- `−`: previous value; disabled at 5.
- `+`: next value; disabled at 15.
- At 10 both enabled.
- One activation = one 5-minute step + one selection haptic.
- Disabled endpoint remains visible, uses disabled semantics, and is not focusable as an enabled action.

### 7.4 Keyboard / Switch Control

- Focusable dial is one adjustable element.
- Arrow Up/Right increments; Arrow Down/Left decrements.
- `−/+` remain separately discoverable buttons for Switch Control / Full Keyboard Access.
- Tab order: dial → decrement → increment → zone group. Visual order can group `−/+`, but accessibility sort priority keeps the adjustable dial first.

### 7.5 Haptics

- Generator: `UISelectionFeedbackGenerator` or SwiftUI sensory feedback equivalent.
- Emit only when committed value changes.
- Prepare on drag start; never emit at every pointer move.
- No haptic on disabled activation, cancel without change, appearance or re-render.

### 7.6 Motion

- Default: progress and handle animate to new stop in `120 ms easeOut`.
- Drag follows finger without spring/overshoot; final snap may use the same 120 ms ease-out.
- Reduce Motion: no animated angular travel; update atomically or crossfade ≤120 ms. No scale pulse.
- Pressed `−/+`: 0.97 scale for ≤120 ms only when Reduce Motion is off; otherwise opacity feedback.

## 8. State table

| State | Track / progress | Handle | Center | `−/+` | Behavior |
|---|---|---|---|---|---|
| Default @10 | Subtle full track; Vermilion to midpoint | Carbon at 12:00 | `10` / `минут` | both enabled | all input paths active |
| Min @5 | progress length 0; selected start tick remains Vermilion | 7:30 | `5` | `−` disabled | decrement unavailable |
| Max @15 | full Vermilion sweep | 4:30 | `15` | `+` disabled | increment unavailable |
| Dragging | nearest stop preview only | follows snapped stop; 0.94 scale | snapped valid value | remains visible, ignores concurrent input | one input transaction |
| Pressed step | unchanged until activation | unchanged | unchanged | pressed fill Carbon 8%, optional 0.97 scale | commit on activation |
| Disabled | subtle track at 55%; progress Carbon 24% | Muted | Muted | both disabled | one accessible disabled element |
| Generating | same as disabled | same | last value | disabled | prevents setup/plan mismatch |
| Invalid external binding | normalize once to nearest stop; ties down | normalized stop | normalized value | based on normalized value | DEBUG assertion + one VO announcement |
| Increase Contrast | base 32% Carbon, progress Carbon, 3 pt ticks | 4 pt ring | unchanged | 2 pt outline | do not rely on Vermilion alone |

The whole component is disabled only while plan generation is in flight or when product state explicitly disallows edits. Endpoint-disabled applies only to one step button.

## 9. Responsive rules

### 9.1 393×852 portrait

- Keep existing 20 pt outer inset and section header contract.
- Dial 216 pt centered in available width.
- Section occupies approximately 300 pt including header and step buttons.
- Zone section follows after 24 pt; whole Setup remains inside existing vertical `ScrollView`.
- Bottom CTA remains `safeAreaInset`; content bottom reserve must prevent overlap.

### 9.2 320×700 compact portrait

- Dial reduces to 184 pt; button visuals 48 pt but hit areas remain ≥44.
- H1 may use existing compact 38 pt override; section gap may reduce from 32 to 24.
- Do not reduce body below semantic size or hide `−/+`.
- Zone section can move below fold; scrolling is expected and acceptable.
- CTA remains fixed above safe area and never covers increment/decrement.

### 9.3 Landscape

- Use two-column Setup when effective width ≥600 pt: left column header/intro, right column controls; or keep existing single `ScrollView` if implementation already does so.
- Within duration section: 168 pt dial and `−/+` in a vertical rail to its right when height <430 pt.
- Minimum content inset 20 pt plus safe areas.
- No control may be clipped by the home indicator/notch. Horizontal scrolling prohibited.

### 9.4 Dynamic Type through AX3

- Header value stacks beneath section title using existing `ViewThatFits` behavior.
- Dial diameter caps at 184 pt so larger text gets the center, not a larger circle.
- Central number may scale to ≈72 pt but must fit inside a 104 pt inner square; use `minimumScaleFactor(0.82)` and one line.
- Unit may wrap to two centered lines; never disappear.
- `−/+` move below the dial if center text or labels would collide.
- Visual order, reading order and available actions remain unchanged.

## 10. Accessibility semantics

### 10.1 Adjustable element

Expose dial as one adjustable accessibility element:

- Label: `Длительность тренировки`.
- Value: plural-aware `10 минут`.
- Hint: `Смахните вверх или вниз, чтобы изменить на 5 минут. Также доступны кнопки уменьшения и увеличения.`
- Trait/role: adjustable; do not expose track, ticks, arc or handle individually.
- Increment action: next allowed value.
- Decrement action: previous allowed value.
- Boundary behavior: keep value and optionally announce `Минимум — 5 минут` / `Максимум — 15 минут`; no error haptic.

### 10.2 Separate buttons

- `−` label: `Уменьшить длительность на 5 минут`.
- `+` label: `Увеличить длительность на 5 минут`.
- Value is not repeated in every button label; after activation the dial value change is announced.
- SF Symbols/minus/plus are decorative inside labelled buttons.
- Buttons preserve 44×44 minimum and disabled semantics at endpoints.

### 10.3 Reading and focus order

1. `Сколько времени?` heading.
2. Adjustable dial with current value.
3. Decrement.
4. Increment.
5. `Куда нагрузка?` heading and zone choices.
6. Bottom primary CTA at its visual position in the route order.

Do not create 3 accessibility elements for ticks. During drag with VoiceOver active, native adjustable actions take priority; direct-drag support is optional and must not replace them.

## 11. Validation and error rules

1. Public component precondition: `allowedValues` non-empty, sorted, unique; current value belongs to it.
2. DEBUG: assert on invalid configuration/value.
3. Release fail-safe: normalize an invalid bound value once to nearest allowed stop (tie goes lower), log non-sensitive diagnostic, and announce `Длительность скорректирована до N минут` if screen is active.
4. CTA can generate only when value is valid and `isGenerating == false`.
5. Plan-generation failure is not shown inside dial. Keep existing setup value, move focus to inline error below parameters, offer `Повторить`.
6. A drag outside bounds clamps visually; it is not an error state.
7. Empty/permission/offline states do not apply: component is local and allowed values are static.

## 12. SwiftUI handoff

### 12.1 Suggested API shape

```text
TempoDurationDial(
  value: Binding<Int>,
  allowedValues: [Int] = [5, 10, 15],
  isEnabled: Bool = true,
  onCommit: ((Int) -> Void)? = nil
)
```

This is an interface contract, not production code. Keep value ownership in `ContentView`; do not add persistence or change `WorkoutGenerator` as part of the visual migration.

### 12.2 Suggested composition

- `GeometryReader` only inside a bounded square; avoid taking unconstrained ScrollView height.
- Draw base and progress with `Circle().trim(...)`, rotated so endpoints match 7:30/4:30.
- Compute handle from the same normalized value as progress; one source of truth.
- Use `contentShape`/gesture corridor around the arc; keep center non-interactive.
- Use semantic Tempo tokens. Add component tokens only for dial diameter, arc width and handle size; do not scatter raw values in `ContentView`.
- Use `@Environment(\.accessibilityReduceMotion)`, `@Environment(\.accessibilityContrast)` and `@Environment(\.dynamicTypeSize)`.
- Use `accessibilityAdjustableAction` on the grouped dial.
- Disable component during `isGenerating` so the generated plan cannot diverge from the displayed selection.
- Keep all localized strings in `Localizable.xcstrings`.

### 12.3 Mapping from current code

- Replace only `ContentView.durationPicker` cells (`ContentView.swift:95–123`).
- Preserve `@State selectedDuration = 10` and `generatePlan(targetDurationMin:)` wiring.
- Remove the obsolete `durations` loop only after the component receives the same `[5,10,15]` contract.
- Update UI tests that currently find buttons `5 минут`, `10 минут`, `15 минут`; assert dial + `−/+`, adjustable behavior, endpoint states and generated plan value.
- Production code outside Setup/value validation is out of this design task.

## 13. Test contract for iOS

### Unit/component

1. Default value is 10; progress fraction is 0.5; handle is midpoint.
2. Increment/decrement sequence is 5 ↔ 10 ↔ 15 and cannot escape bounds.
3. Tap/drag maps to nearest stop; exact mid-ties use deterministic lower stop until crossing.
4. Lower-gap angles clamp without wrapping min ↔ max.
5. Haptic event count equals committed value-change count.
6. Invalid external value normalizes as specified; generator never receives it.
7. Reduce Motion chooses no-travel animation path.

### UI/accessibility

1. Dial exists as one adjustable element with label/value/hint.
2. Adjustable increment/decrement changes value and visible center copy.
3. `−/+` are hittable ≥44×44; endpoint button disabled correctly.
4. Tap and drag each reach all three values.
5. `Собрать тренировку` after choosing 5/15 creates plan with matching target label.
6. While generating, dial and steps cannot mutate value.
7. Reading order is heading → dial → minus → plus → zone section.
8. 393×852, 320×700, AX3 portrait and landscape have no clipping/overlap and can scroll to all controls.
9. Increase Contrast and Reduce Motion paths remain legible and operable.
10. Manual VoiceOver pass verifies spoken boundary and value announcements; XCTest hierarchy is not proof of real cursor behavior.

## 14. QA checklist and design score

### Visual / interaction gate

- [ ] Standard portrait screenshot matches preview hierarchy and Tempo/Cut tokens.
- [ ] Compact portrait keeps dial and `−/+` usable; CTA does not cover them.
- [ ] AX3 central value/unit do not clip; zone section remains reachable by scroll.
- [ ] Landscape keeps all controls reachable without horizontal overflow.
- [ ] Handle, tick and progress share one geometry at 5, 10 and 15.
- [ ] No implied minor values, card, shadow, gradient or second primary CTA.
- [ ] Tap target and gesture corridor verified with Accessibility Inspector.
- [ ] Real VoiceOver adjustable and separate buttons verified manually.
- [ ] Reduce Motion and Increase Contrast verified on device/simulator.

### Design audit score (spec + static preview)

| Dimension | Score |
|---|---:|
| Task clarity / IA | 20/20 |
| Hierarchy / composition | 14/15 |
| Typography / content | 10/10 |
| Design-system consistency | 15/15 |
| Interaction states / feedback | 10/10 |
| Native adaptation | 9/10 |
| Accessibility | 15/15 |
| Distinctiveness | 5/5 |
| **Total** | **98/100** |

Remaining weaknesses: real SwiftUI pixels, actual VoiceOver cursor/announcements and landscape behavior cannot be proven by a static repository artifact. They are explicit implementation/QA gates, not assumed PASS.

## 15. Acceptance matrix

| Requirement | Resolution | Evidence |
|---|---|---|
| Range / step / default / last value | Defined; 5…15 step 5, default 10, in-memory only | §3 |
| Snap / haptics / drag / tap | Exact contract | §§5.4, 7 |
| Center value / unit / arc / handle / ticks | Exact anatomy and tokens | §§5–6 |
| Disabled / pressed | State table | §8 |
| VoiceOver adjustable | Labels, values, actions, order | §10 |
| Non-precision fallback | `−/+`, keyboard, Switch Control | §§7.3–7.4 |
| Reduce Motion / Increase Contrast | Defined | §§7.6, 8 |
| Dynamic Type AX3 | Defined | §9.4 |
| Compact portrait / landscape | Defined | §9 |
| Validation / errors | Defined | §11 |
| SwiftUI handoff / tests | Defined without production edits | §§12–13 |
| Visual compatibility | Tempo tokens + hi-fi PNG | §6 and preview artifact |

## 16. Risks and next role

- Risk: circular control with only three stops is visually larger than segmented controls. Mitigation: open arc, no card, compact 184/168 variants and required ScrollView.
- Risk: custom gesture math can wrap through the bottom gap. Mitigation: explicit clock endpoints, clamp rule and component tests.
- Risk: UI tests currently depend on three duration buttons. Mitigation: replace with dial/step assertions; do not keep invisible legacy buttons.
- Risk: Figma source is absent. Mitigation: repository preview is inspectable; teamlead must provide approved Figma destination before design lock.
- Next role: `ios` implements `TempoDurationDial`, preserves the value contract, updates tests, captures real 393×852 / 320×700 / AX3 / landscape evidence, then hands off to independent QA.

Applicable standards: `/home/hermes/.hermes/team-agent-os/standards/design/ui-ux.md`, `delivery/task-lifecycle.md`, `delivery/handoff.md`, `engineering/security.md`.
