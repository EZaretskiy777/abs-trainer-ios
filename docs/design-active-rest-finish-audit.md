# ABS Trainer «Темп / Срез» — аудит Active, Rest и Finish

Статус: implementation-ready corrective handoff

Kanban: `t_358ed425`

Платформа: iOS / SwiftUI

Проверяемая реализация: ветка `feature/tempo-cut-swiftui`

Эталон: iPhone portrait `393×852 pt`; обязательная адаптация `320×700 pt`, compact height и Dynamic Type до AX3

## 0. Решение

Текущую концепцию **«Темп / Срез» сохранить**. Переосмысление палитры, полноэкранных режимов и структуры потока не требуется. Нужен корректирующий проход по четырём наблюдаемым проблемам:

1. В Active таймер и его контекст должны образовывать одну выровненную композицию, а не две независимо стоящие подписи.
2. В Rest и круглой pause-кнопке inverse-content должен задаваться явно; нельзя наследовать системный `tint`/foreground и получать Carbon на Ultramarine/Carbon.
3. Confirmation завершения должен использовать продуктовый modal contract вместо визуально чужого системного alert, сохраняя нативную семантику cancel/destructive и VoiceOver focus scope.
4. Finish actions должны иметь одну центральную ось и предсказуемую icon policy: primary остаётся label + trailing repeat icon, но label центрируется независимо от иконки; secondary центрируется по той же оси.

**Итоговый gate:** дизайн после применения этой спецификации — `92/100`, без P0. Текущая сборка — `68/100`; остаются P1 по читаемости Rest и destructive confirmation, P2 по Active alignment и Finish action consistency. Реализация не считается принятой до screenshot parity и ручной VoiceOver-проверки.

Новый high-fidelity preview не создаётся: неоднозначность снимают существующие approved PNG и точные правила ниже. Pixel references:

- `design/tempo-cut/previews/tempo-cut-active.png`
- `design/tempo-cut/previews/tempo-cut-rest.png`
- `design/tempo-cut/previews/tempo-cut-finish.png`

## 1. Рамка продукта и проверенный путь

- **Пользователь:** человек, который выполняет короткую тренировку пресса дома и смотрит на экран эпизодически, часто в движении и с увеличенной дистанции.
- **Главная задача:** без лишнего чтения понять текущее упражнение/отдых, оставшееся время и безопасно перейти дальше или завершить сессию.
- **Primary action:** Active — перейти дальше; Rest — дождаться таймера либо пропустить отдых; Finish — повторить тот же план.
- **Критический путь:** `Setup → Plan → Active ↔ Rest → Finish`; выход из незавершённой сессии и досрочное окончание последнего упражнения требуют подтверждения.
- **Ограничения:** SwiftUI, локальная работа, русский source language, системная SF Pro, Dynamic Type, VoiceOver, safe areas, без backend и вымышленных метрик.
- **Визуальное направление:** режимный «срез» — Carbon для работы, Ultramarine для перехода/отдыха, Chalk для итога; Vermilion отмечает темп и действие.

### Источники и степень доказательности

| Источник | Что фиксирует | Evidence |
|---|---|---|
| Четыре пользовательских screenshot из карточки | Реальные дефекты текущей сборки | observed |
| `design/tempo-cut/previews/tempo-cut-{active,rest,finish}.png` | Утверждённая композиция | observed / approved |
| `docs/tempo-cut-five-state-visual-spec.md` | Общий design contract пяти состояний | approved |
| `ios/AbsTrainer/Sources/AbsTrainer/ExercisePlayerView.swift` | Текущая структура Active/Rest/alerts/pause | observed |
| `ios/AbsTrainer/Sources/AbsTrainer/FinishView.swift` | Текущая структура Finish | observed |
| `ios/AbsTrainer/Sources/AbsTrainer/DesignSystem.swift` | Текущие tokens/components | observed |
| Apple-native conventions | Safe area, 44 pt targets, Dynamic Type, VoiceOver, destructive semantics | platform constraint |

Не использовать как baseline отклонённый `design/assets/mockups/abs-trainer-polished-v01.png` и не возвращаться к dark-card направлению из `docs/design-redesign-brief.md`: оно superseded утверждённым «Темп / Срез».

## 2. Issue-by-issue verdict

### ARF-01 — Active: timer/context не воспринимаются одной строкой

- **Severity:** P2.
- **Evidence:** `img_35ae4247afaf.jpg`; текущий `ExercisePlayerView.swift:141–152` использует `HStack(alignment: .firstTextBaseline)`.
- **Наблюдение:** крупный `0:28` и трёхстрочный контекст справа визуально стоят на разных вертикальных уровнях. Baseline двух резко разных кеглей не создаёт оптического равновесия. Контекст выглядит оторванной аннотацией.
- **Impact:** во время нагрузки пользователь медленнее связывает число с его смыслом; композиция выглядит случайной.
- **Verdict:** FAIL по alignment/rhythm, PASS по контенту и контрасту.

**Before → after**

- Было: `.firstTextBaseline`; label ограничен шириной, но его блок не привязан к центру timer box.
- Стало: горизонтальный layout `timer / flexible spacer / context` с `alignment: .center`; `timer.midY == context.midY ±4 pt`.
- Timer имеет intrinsic width, не сжимается, `monospacedDigit()`, одна строка.
- Context: ширина `108…116 pt`, 12/15 semibold, максимум 3 строки, leading alignment, `White 72%` минимум.
- Между bounding boxes — не менее 16 pt.
- На ширине, где пара не помещается, `ViewThatFits` переключает её в vertical layout: timer, затем context через 0…8 pt; никаких `minimumScaleFactor` у context.
- У vertical варианта `0 ≤ context.minY − timer.maxY ≤ 12 pt`.

**Дополнительный дефект в этом evidence**

Круглая pause-кнопка имеет слабую/тёмную пиктограмму. На Carbon фон и символ должны быть explicit White; outline — White 50% минимум, см. ARF-03.

### ARF-02 — Rest: критичный inverse-content наследует неверный цвет

- **Severity:** P1.
- **Evidence:** `img_1c937e7f154e.jpg`. Eyebrow `ДАЛЬШЕ`, название, duration и `Пропустить отдых` визуально уходят в Carbon/тёмный цвет на Ultramarine. В коде часть цветов задаётся на родителе (`ExercisePlayerView.swift:230`), а Button и вложенные controls могут применять собственный `tint`.
- **Impact:** next-up и skip плохо читаются; пользователь может не понять, что произойдёт после паузы, или не найти skip. Carbon/Ultramarine имеет только `2.38:1`.
- **Verdict:** FAIL по semantic color, contrast, control hierarchy и consistency.

**Before → after**

- Было: reliance на `.foregroundStyle(.white)` у контейнера и системное оформление Button.
- Стало: каждый semantic role получает explicit foreground/tint:
  - Rest H1/countdown/next title/duration/skip label: `text.inverse = #FFFFFF`.
  - Eyebrow и next eyebrow: `text.inverseSecondary = White 72%`.
  - Decorative breath track/hairlines: White 30%; они не несут самостоятельной информации.
  - Skip outline как граница интерактивного control: **White 50%**, не 45%; это даёт ≥3:1 для non-text/UI contrast.
  - На root Rest: `.tint(.white)`; у Button label дополнительно explicit `.foregroundStyle(.white)`.
- Нельзя применять Carbon, Vermilion или Signal как текст/иконку непосредственно на Ultramarine: Carbon/blue `2.38:1`, Signal/blue `1.42:1`.

### ARF-03 — Active pause: символ не соответствует inverse control

- **Severity:** P1 для обнаружимости control, P2 отдельно от ARF-02.
- **Evidence:** `img_35ae4247afaf.jpg` и пользовательское замечание о pause; текущий Button не задаёт explicit foreground (`ExercisePlayerView.swift:162–171`).
- **Impact:** control существует, но символ визуально растворяется в тёмном поле; status одного из двух нижних действий неочевиден.
- **Verdict:** FAIL по non-text contrast/control state.

**Before → after**

- Circle hit/visual frame: `58×58 pt`; hit target не меньше 58×58.
- Symbol: SF Symbol `pause.fill`, 17 pt semibold, **White 100%**.
- Outline: White 50%, 1 pt; при Increase Contrast — White 100%, 2 pt.
- Default background transparent; pressed — White 10% fill + opacity 0.88, 120 ms ease-out; при Reduce Motion без scale.
- Disabled во время сессии не допускается. Когда открыт modal, underlying pause скрыт из accessibility и не принимает taps.
- Label: `Поставить тренировку на паузу`; после resume focus возвращается сюда.

### ARF-04 — Finish confirmation: системный alert выпадает из продуктовой темы

- **Severity:** P1.
- **Evidence:** `img_601ff58ef098.jpg`; текущие `.alert` в `ExercisePlayerView.swift:106–117`.
- **Наблюдение:** translucent system card и серые action rows поверх Carbon не используют rhythm/radius/contrast «Темп / Срез». Деструктивная и безопасная ветви почти равны визуально; body выглядит как system copy, не как часть player.
- **Impact:** в необратимом моменте пользователь должен моментально отличить продолжение от завершения. Визуальный разрыв снижает уверенность.
- **Verdict:** FAIL по product consistency и destructive hierarchy; PASS по наличию cancel/destructive roles в текущей логике.

**Решение:** custom `SessionConfirmationModal` на общей поверхности с pause-modal; не `sheet` и не системный `confirmationDialog`. Центрированная card сохраняет контекст упражнения и согласуется с уже существующим pause overlay. На compact height/AX3 card допускает внутренний scroll, но не меняет порядок.

**Anatomy**

1. Scrim `#000000` 64% поверх всей window/safe-area; tap outside **ничего не делает**.
2. Chalk card `#F5F1E8`, width `min(containerWidth − 40, 353)`, radius 28, padding 24; один shadow level `black 18% / radius 24 / y 16`.
3. Optional semantic icon 56×56: `xmark`/`stop.fill` в Signal на Chalk; hidden from VoiceOver. Иконку можно опустить на compact height.
4. Title 24/28 bold Carbon, до 3 строк.
5. Body 17/22 regular Muted, полный перенос.
6. Actions vertical, gap 8; safe default сверху, destructive снизу.

**Copy/semantics variants**

| Variant | Title | Body | Safe default | Destructive |
|---|---|---|---|---|
| Exit session | `Завершить тренировку?` | `Прогресс этой сессии не сохранится.` | `Продолжить тренировку` | `Завершить тренировку` |
| Last exercise early | `Завершить последнее упражнение?` | `До конца упражнения ещё осталось время.` | `Продолжить упражнение` | `Завершить сейчас` |

**Action styles**

- Safe default: Carbon fill / White, full width, min-height 56, radius 20.
- Destructive: transparent Chalk / Signal text + Signal 1 pt outline, full width, min-height 52, radius 20. Signal/Chalk = `4.71:1`.
- Не делать destructive залитой primary-кнопкой: default должен предотвращать случайный выход.
- Pressed: opacity 0.88, 120 ms; disabled 38% opacity; во время transition обе actions disabled, layout не меняется.
- Escape gesture/VoiceOver escape эквивалентны safe default. Hardware keyboard Escape, если доступен, также cancel.

**Accessibility contract**

- При появлении фон: `.accessibilityHidden(true)` и `.allowsHitTesting(false)`.
- Card: modal containment / `.isModal`; first focus на title.
- VoiceOver order: title → body → safe default → destructive.
- После cancel focus возвращается на control, открывший confirmation: close либо Finish CTA.
- После destructive выполняется один transition; повторные activations блокируются.
- Не полагаться только на красный: destructive label содержит явный глагол.

### ARF-05 — Finish: action pair имеет разные оси

- **Severity:** P2.
- **Evidence:** `img_f420685a5124.jpg`; `TempoPrimaryButton` выравнивает label leading и ставит symbol trailing (`DesignSystem.swift:53–70`), тогда как secondary центрируется (`FinishView.swift:63–69`).
- **Impact:** пара выглядит собранной из разных компонентов; primary text не совпадает с центральной осью secondary.
- **Verdict:** FAIL по component consistency/grid, PASS по правильной primary/secondary иерархии.

**Before → after**

- Сохранить approved trailing repeat symbol, но использовать balanced three-column label grid: `44 pt transparent balance / flexible centered label / 44 pt trailing symbol`.
- Primary label оптически и геометрически по центру container: `abs(label.midX − button.midX) ≤ 2 pt`.
- Repeat symbol `arrow.counterclockwise`: 18 pt semibold, centered в 44×44 slot, accessibility hidden; текст остаётся полным accessible label.
- Secondary: full-width 48 pt min-height, centered label на той же `button.midX`; без иконки.
- Обе actions имеют одинаковые horizontal edges и width; gap 8 pt.
- Primary: 58 pt minimum, Carbon/White, radius 20.
- Secondary: 48 pt minimum, transparent/Carbon; pressed ChalkSubtle fill допустим.
- На AX3 labels переносятся; height intrinsic, padding vertical не менее 14; symbol остаётся trailing и topologically после label, но не сжимает его ниже readable width.

## 3. Утверждённая композиция экранов

### 3.1 Active

Порядок сверху вниз:

1. Safe area и inverse status chrome.
2. Top bar: close 48, centered `NN / NN`, 48 pt balancing spacer.
3. Progress rail: completed Vermilion, current White, upcoming White 24%.
4. Exercise header: title leading, zone trailing; при нехватке ширины zone переносится следующей строкой.
5. Chalk media aperture.
6. Timer row по правилу ARF-01.
7. Flexible breathing space.
8. Safe-area action bar: pause 58 + primary Next/Finish 58.

Измеримые constraints:

- Horizontal inset 20; top bar inset 12.
- Rail top/bottom separation: 16/24 pt до exercise content.
- Exercise title 30/30 bold, максимум 2 строки на default; essential title не клипуется на AX3.
- Media height: 286 reference; 230 compact. Radius 28.
- Timer 68 pt relative/scaled, compact 58, minScale 0.75 только для timer.
- Bottom controls gap 12; action bar vertical padding 12 и safe-area inset.
- Action bar не перекрывает timer/context; ScrollView получает bottom reserve автоматически через `safeAreaInset`.

### 3.2 Rest

Порядок сверху вниз:

1. Safe area и inverse status chrome.
2. Eyebrow.
3. H1 `Вдох. / Медленный / выдох.`.
4. Countdown.
5. Breath line.
6. Flexible blue field.
7. Safe-area next-up block между hairlines.
8. Outline skip CTA.

Измеримые constraints:

- Ultramarine full-field `#2946C6`, inset 20.
- Eyebrow 12/16 semibold uppercase, tracking 1.2, White 72%.
- H1 default 48/46 bold; countdown default 116/96 semibold monospace.
- Breath line 2 pt; progress fill White, track White 30%; entire line accessibility hidden.
- Next eyebrow 12/16 White 72%; title 20/24 semibold White; duration 17/22 semibold monospace White.
- Next title and duration share first baseline at default sizes. Если не помещаются — duration переходит под title, leading aligned.
- Next-up vertical padding 16; hairlines 1 pt White 30%.
- Skip 58 min-height, full width, radius 20, border White 50%, label White.
- Нижняя blue surface непрерывна: card, shadow, gradient и отдельная toolbar-плашка запрещены.

### 3.3 Finish

Порядок сверху вниз:

1. Safe area и dark status chrome.
2. Eyebrow Vermilion.
3. Completion ring 154×154; decorative.
4. H1 `Темп / выдержан.`.
5. Body.
6. Results strip.
7. Flexible Chalk field.
8. Safe-area action stack по ARF-05.

Измеримые constraints:

- Chalk `#F5F1E8`, inset 20.
- H1 42/42 bold Carbon; body 17/22 Muted.
- Ring 154, stroke 18 Vermilion; check Carbon; скрыт от VoiceOver.
- Results: две equal-width columns на default; strip top/bottom hairline; vertical divider. Values 30/34 semibold monospace, labels 12/16.
- На compact width/AX3 results становятся вертикальным stack; labels не clip.
- Action stack edges совпадают с content edges; bottom safe-area inset; primary/secondary не перекрывают content.

## 4. Design tokens

### 4.1 Color primitives → semantics → components

| Primitive / HEX sRGB | Semantic | Component use | Проверенный contrast |
|---|---|---|---:|
| Chalk `#F5F1E8` | `surface.canvasLight` | Finish/modal | — |
| Chalk Subtle `#ECE5D8` | `surface.controlPressedLight` | secondary pressed/icon plate | — |
| Carbon `#171714` | `surface.active`, `text.primary`, `action.primary` | Active canvas; Finish primary | Carbon/Chalk `15.94:1`; White/Carbon `17.96:1` |
| Muted `#55534D` | `text.secondaryLight` | Finish/modal body | Muted/Chalk `6.82:1` |
| Vermilion `#D13A25` | `action.player`, `accent.completion` | Active CTA/progress; finish ring | White/Vermilion `4.84:1` |
| Ultramarine `#2946C6` | `surface.rest` | Rest full field | White/Ultramarine `7.54:1` |
| Signal `#B74731` | `action.destructive` | modal destructive on Chalk | Signal/Chalk `4.71:1` |
| White `#FFFFFF` | `text.inverse` | Primary inverse text | см. пары выше |
| White 72% over Ultramarine | `text.inverseSecondary` | Rest eyebrows/secondary normal text | `4.71:1` |
| White 50% over Ultramarine | `border.inverseInteractive` | Rest skip/pause outline | `≥3.0:1` |
| White 30% over Ultramarine | `border.inverseDecorative` | Hairlines/track only | decorative only |

Контраст рассчитан WCAG relative luminance из указанных sRGB HEX. White 68% over Ultramarine даёт примерно `4.39:1` и **не допускается для normal text**; минимум для normal secondary copy — 70%, выбран product token 72%. White 45% outline даёт примерно `2.76:1`; для границы control использовать 50%.

High Contrast assets не должны просто повторять default. Обязательные overrides:

- inverse secondary → White 100%;
- interactive outline → White 100% / 2 pt;
- light hairline Carbon 32%;
- destructive outline Signal 2 pt.

### 4.2 Typography

| Role | Default | Scale/line behavior |
|---|---|---|
| Active H1 | 30/30 bold | relative to `.largeTitle`, wrap; no truncation |
| Active timer | 68/.95 semibold monospaced | one line, minScale 0.75 |
| Rest H1 | 48/.95 bold | relative/scaled; wrap preserved |
| Rest timer | 116/.8 semibold monospaced | one line, minScale 0.75 |
| Finish H1 | 42/42 bold | relative/scaled; wrap |
| Modal title | 24/28 bold | up to 3 lines |
| Body | 17/22 regular | unlimited essential copy |
| Section/next title | 20/24 semibold | wrap |
| Control label | 17/22 semibold | wrap at AX3 |
| Eyebrow | 12/16 semibold uppercase | tracking 1.2; no manual letter spacing if clipping |
| Utility/count | 15/18 semibold monospaced | fixed-size horizontal where safe |

Не использовать fixed-size font без `@ScaledMetric`/semantic relative style. `lineLimit(1)` разрешён для tabular timer/duration, но не для Russian action labels и context.

### 4.3 Spacing, size, radius, stroke, motion

- Spacing: `4, 8, 12, 16, 20, 24, 32, 40, 56 pt`.
- Page inset: 20 pt; compact не уменьшать ниже 16 pt.
- Min tap: 44×44; top icon 48; primary 58; pause 58; Finish secondary 48.
- Radius: choice 12; action 20; media/modal 28; circle только icon/timer control.
- Stroke: decorative hairline 1; default interactive 1; Increase Contrast interactive 2.
- Press: 120 ms ease-out, opacity 0.88; optional scale 0.985 только без Reduce Motion.
- Route: 240 ms; Active↔Rest 360 ms. Reduce Motion: opacity ≤120 ms, без scale/translation/breath animation.
- Disabled: opacity 0.38, interaction blocked, semantic disabled trait; размер не меняется.
- Loading: сохраняет frame, spinner + label, повторные taps blocked.

## 5. Component contracts для iOS

### `ActiveCountdownContext`

- Purpose: единая читаемая пара «время + смысл».
- Anatomy: timer, spacer, context.
- Default: horizontal center alignment.
- Compact/AX3: vertical via `ViewThatFits`.
- Accessibility: объединить в один элемент `Осталось 28 секунд в этом упражнении`; визуальные дочерние элементы не дублируют announce.
- Test IDs: `session.active.timer`, `session.active.timerContext`, optional group `session.active.countdownGroup`.

### `InverseIconButton`

- Purpose: close/pause на Carbon/Ultramarine.
- Sizes: 48 close; 58 pause.
- Explicit `foregroundStyle(.white)` и `.tint(.white)`; interactive border ≥3:1.
- States: default, pressed, focused, modal-disabled.
- VoiceOver: action-oriented label; glyph hidden.

### `RestNextUp`

- Purpose: показать следующий шаг без конкуренции с countdown.
- Anatomy: eyebrow, title, duration, top/bottom hairlines.
- Default: title + duration on one baseline.
- Compact/AX3: vertical stack.
- Explicit semantic foreground на каждом text role; никакого inherited Button tint.
- Accessibility group: `Дальше, упражнение 4 из 8, Планка, 45 секунд`.

### `SessionConfirmationModal`

- Purpose: предотвратить accidental irreversible exit/early finish.
- Variants: `.exitSession`, `.finishLastExerciseEarly`.
- Surface/action/interaction/accessibility contract — ARF-04.
- Не использовать для обычной паузы; pause остаётся отдельным `SessionPauseModal` с одной primary action.
- Figma-equivalent naming: `Modal/SessionConfirmation/{Exit,FinishEarly}`; Figma destination в проекте отсутствует, поэтому repository spec + approved PNG остаются source of truth.

### `FinishActionStack`

- Purpose: repeat same plan (primary) или начать setup (secondary).
- Primary balanced layout `[44 / flexible / 44]`; secondary full-width centered.
- States: default, pressed, disabled/loading; loading применим только если route preparation станет async.
- Accessibility: `Повторить тренировку`, `Настроить новую`; repeat symbol hidden.
- Navigation: repeat → тот же Plan; new → Setup.

## 6. Responsive и accessibility states

### iPhone 17 Pro Max portrait / reference 393×852

- Следовать approved PNG hierarchy и 20 pt grid.
- Active timer/context — horizontal centered pair.
- Rest next-up anchored через `safeAreaInset`, а не absolute y-position.
- Finish action stack нижний, но content scrollable; сохраняется flexible gap.

### Compact viewport 320×700

- Active: media 230 high; title/zone и timer/context переходят в vertical layouts при необходимости. Bottom controls остаются видимыми.
- Rest: H1/timer сохраняют приоритет; main content scrollable. Next-up title/duration допускают stack. Skip не ниже 56 и не перекрыт home indicator.
- Finish: ring может уменьшиться до 120 pt только по height class, stroke пропорционально 14; results допускают vertical stack; content scrollable над actions.
- Нельзя уменьшать tap targets, скрывать context/next-up или обрезать русские строки ради pixel parity.

### AX3 portrait

- Использовать intrinsic heights и vertical fallback для всех горизонтальных text pairs.
- Modal card: max height `availableSafeHeight − 40`; content scrolls; actions остаются внутри card после body.
- Active/Rest/Finish root content scrollable, bottom controls через `safeAreaInset`.
- CTA labels могут занимать 2 строки; min-height становится intrinsic, horizontal padding 16.
- Decorative ring/media могут уменьшаться по высоте, но essential copy и controls не уменьшаются.

### AX3 landscape / compact height

- Не обещается pixel parity; обязательны task completion, no clipping и reachable controls.
- Active: media и content scroll; bottom controls remain safe-area pinned.
- Rest: main copy scrolls отдельно от bottom block; H1 не фиксируется absolute.
- Finish: content scrolls, action stack pinned; ring может быть hidden **только** как decorative при крайне малой высоте, H1/results/actions остаются.
- Modal использует почти full-width card с 16 pt outer inset и scrollable body.

### VoiceOver

Порядок:

- Active: exit → progress → exercise/zone → media status/cue → countdown group → pause → next/finish.
- Rest: state/title → countdown → next-up group → skip.
- Confirmation: title → body → safe default → destructive; modal trap; cancel возвращает focus на opener.
- Finish: H1 → body → results summary → repeat → new. Ring hidden.

Countdown announcements только `10, 5, 3, 2, 1` и state transition; ежесекундный announce запрещён. Любая информация о selected/destructive/current выражается label/trait, не только цветом.

### Other settings

- **Reduce Motion:** opacity-only ≤120 ms; breath line static.
- **Increase Contrast:** overrides из token table; не полагаться на текущие identical high-contrast asset values.
- **Reduce Transparency:** modal scrim остаётся opaque-enough; card не использует material/blur.
- **Bold Text:** layout reflows, timer digits не clip.
- **Differentiate Without Color:** rail имеет accessible progress value; destructive action имеет явный текст.

## 7. Затрагиваемые SwiftUI-компоненты — без production implementation в этой задаче

| Файл / symbol | Требуемое изменение следующей ролью |
|---|---|
| `Sources/AbsTrainer/DesignSystem.swift` / `TempoTokens` | Добавить inverse semantic tokens, high-contrast variants, component stroke/pressed tokens |
| `DesignSystem.swift` / `TempoPrimaryButton` | Не менять глобальную approved leading+trailing политику без review; добавить layout variant для balanced Finish primary |
| `DesignSystem.swift` / new `InverseIconButton` | Явный inverse symbol/tint, pressed/high-contrast states |
| `ExercisePlayerView.swift` / active timer row | Выравнивание center + vertical fallback + combined accessibility group |
| `ExercisePlayerView.swift` / pause Button | Перевести на inverse icon contract |
| `ExercisePlayerView.swift` / Rest screen + `restBottomBlock` | Explicit inverse roles/tint; outline 50%; adaptive next-up |
| `ExercisePlayerView.swift` / `.alert` modifiers | Заменить state-driven custom `SessionConfirmationModal`; сохранить transition logic |
| `ExercisePlayerView.swift` / modal focus state | Добавить opener-aware focus return и modal containment для двух confirmation variants |
| `FinishView.swift` / action stack | Balanced primary symbol grid; shared center axis; AX3 wrapping |
| `FinishView.swift` / results | Проверить vertical fallback и summary semantics |
| `Resources/Assets.xcassets` | Реальные Increase Contrast overrides вместо дублирования default для relevant colors/borders |
| `Resources/Localizable.xcstrings` | Добавить/обновить полные modal action strings; не собирать предложения конкатенацией |
| `Tests/AbsTrainerUITests.swift` | Геометрия center alignment, explicit states, modal order/focus/blocked background, Finish action center axes |

## 8. Implementation checklist

### Active

- [ ] Timer/context share horizontal midY within 4 pt at 393×852.
- [ ] Compact/AX3 fallback has 0…12 pt vertical gap and no overlap.
- [ ] Countdown accessibility is one meaningful group.
- [ ] Pause icon is White with explicit tint; outline ≥3:1.
- [ ] Pause target is ≥58×58 and remains reachable.
- [ ] Bottom controls use safe-area inset and do not cover timer/context.

### Rest

- [ ] H1, countdown, next title, duration and skip label are explicit White.
- [ ] Normal secondary text is White 72% or stronger.
- [ ] Interactive outline is White 50% or stronger; decorative hairline separately tokenized.
- [ ] Root and buttons set `.tint(.white)` where needed.
- [ ] Next-up title/duration use baseline default and vertical compact fallback.
- [ ] Skip target is ≥56 pt, full width, above home indicator.
- [ ] Reduce Motion disables breath motion; line hidden from VoiceOver.

### Confirmation

- [ ] Both existing alert paths use `SessionConfirmationModal` variants.
- [ ] Safe default appears before destructive in visual and VoiceOver order.
- [ ] Outside tap cannot accidentally resolve modal.
- [ ] Background is inaccessible/noninteractive while modal is open.
- [ ] Initial focus goes to title; cancel returns to opener.
- [ ] VoiceOver escape/hardware Escape cancel safely.
- [ ] AX3/compact card scrolls without clipping actions.
- [ ] Repeated taps during transition are blocked.

### Finish

- [ ] Primary and secondary have identical horizontal edges.
- [ ] Both labels share center axis; primary label midX error ≤2 pt.
- [ ] Repeat icon occupies trailing 44×44 slot and is accessibility hidden.
- [ ] Primary ≥58 pt; secondary ≥48 pt; gap 8.
- [ ] AX3 action labels wrap without clipping; safe-area preserved.
- [ ] Results show only factual duration/count and adapt to vertical stack.

### Localization/security/scope

- [ ] All new Russian strings are in String Catalog and tested with long alternatives.
- [ ] No analytics, network, credential, persistence or backend work introduced.
- [ ] No gradients, glass/material, new cards, decorative metrics or second primary CTA.
- [ ] No change to workout state/data contract beyond presentation state needed for modal focus.

## 9. QA acceptance matrix

| ID | Acceptance | Automated evidence | Manual evidence | Pass rule |
|---|---|---|---|---|
| QA-ARF-01 | Active alignment | Geometry test at 393×852 + 320×700 + AX3 | Screenshot comparison | midY ±4 or defined vertical fallback; no overlap |
| QA-ARF-02 | Rest contrast | Token contrast unit/snapshot assertions where feasible | Accessibility Inspector + screenshot | text ≥4.5:1; interactive outline ≥3:1 |
| QA-ARF-03 | Pause discoverability | target/frame/hittability test | visual + Increase Contrast | White symbol, ≥58 target, visible states |
| QA-ARF-04 | Confirmation safety | UI test both variants, safe/destructive routing, background blocked | VoiceOver focus/escape recording | no accidental dismissal; correct focus return |
| QA-ARF-05 | Finish action grid | compare action/label frames | screenshot comparison | equal edges, common center, no clipping |
| QA-ARF-06 | Reference viewport | existing five-state capture | independent pixel/human review | hierarchy/palette/rhythm match approved PNG |
| QA-ARF-07 | Compact | flow at 320×700 | screenshots all affected states | controls reachable; no overlap/overflow |
| QA-ARF-08 | AX3 portrait | geometry/full-flow test | screenshots + VoiceOver | all essential content and actions reachable |
| QA-ARF-09 | AX3 landscape | geometry/full-flow test | screenshots | no clipping; task completion possible |
| QA-ARF-10 | Accessibility settings | Reduce Motion flags and semantics tests | VoiceOver, Increase Contrast, Reduce Transparency | behavior matches section 6 |
| QA-ARF-11 | Long Russian strings | launch with test localization/overrides | visual review | no truncation of title/body/actions/context |

Использовать общий процесс evidence из `docs/tempo-cut-qa-evidence-checklist.md`. XCTest не является доказательством реального VoiceOver cursor/announcement queue. Финальный visual verdict требует выгруженных PNG, `scripts/compare_tempo_cut_screenshots.py` и независимого human review.

## 10. Quality gate

| Dimension | Current | После spec | Verdict |
|---|---:|---:|---|
| First-screen/state clarity | 8/10 | 9/10 | Active/Rest modes ясны |
| Information hierarchy | 7/10 | 9/10 | next-up и timer context восстановлены |
| Layout rhythm/alignment | 6/10 | 9/10 | center/baseline/action grids измеримы |
| CTA clarity | 6/10 | 9/10 | Rest/pause contrast и Finish axes исправлены |
| Navigation/recovery | 8/10 | 9/10 | safe default и focus return определены |
| Component states | 5/10 | 9/10 | pressed/disabled/modal/high contrast заданы |
| Responsiveness | 7/10 | 9/10 | compact/AX3 fallbacks определены |
| Accessibility | 5/10 | 9/10 | контраст/focus/VoiceOver contracts заданы |
| Content quality | 8/10 | 9/10 | modal copy становится однозначнее |
| Visual originality/consistency | 8/10 | 9/10 | «Темп / Срез» сохранён без system-style разрыва |
| Implementation handoff | 8/10 | 10/10 | symbols/tokens/tests перечислены |
| **Total** | **68/100** | **92/100** | implementation-ready, QA pending |

## 11. Decisions, rejected alternatives, risks и next role

### Decisions

- Сохранить Carbon/Ultramarine/Chalk mode system и approved screen hierarchy.
- Active timer/context выравнивать по center, не first baseline.
- Rest inverse content задавать явно; normal secondary — White 72%; interactive outline — White 50%.
- Использовать custom themed modal card, потому что продукт уже имеет custom pause modal и карточка требует визуальной согласованности.
- Finish repeat icon сохранить, но сбалансировать 44/flexible/44 grid, чтобы label был действительно centered.

### Rejected alternatives

- **Не** менять Rest на card/sheet: full-field blue — важный transition signal.
- **Не** делать destructive action основным залитым CTA: это увеличивает accidental exit risk.
- **Не** убирать repeat icon без необходимости: он присутствует в approved reference; balanced grid устраняет проблему без изменения концепции.
- **Не** использовать blur/material/glass для modal: это возвращает наблюдаемый system-style mismatch и ухудшает Reduce Transparency.
- **Не** уменьшать шрифты/tap targets для compact parity: reflow/scroll приоритетнее.

### Residual risks

1. Реальный VoiceOver focus trap/return нельзя доказать code review или XCTest; нужен manual pass на iPhone/simulator.
2. Increase Contrast assets сейчас визуально совпадают с default для нескольких цветов; implementation должен добавить реальные overrides и проверить их.
3. Approved pixel PNG не содержит confirmation state; modal специфицирован по product tokens и pause-modal anatomy, поэтому потребуется design screenshot review после реализации.
4. iPhone 17 Pro Max screenshot показывает runtime/device, но точный logical viewport evidence должен быть записан QA, а не выведен из имени simulator.
5. Figma destination не настроен; repository docs + approved PNG остаются inspectable source of truth. Это не блокирует corrective implementation, но ограничивает component-library handoff.

### Next role

`ios`:

1. Реализовать перечисленные component/token/state changes без изменения workout data flow.
2. Обновить geometry/UI tests для ARF-01…05.
3. Собрать и прогнать tests; захватить 393×852, 320×700, AX3 portrait/landscape.
4. Передать в независимый `qa` с screenshot diff, Accessibility Inspector и manual VoiceOver evidence.

Completion criteria следующей роли: все пункты implementation checklist выполнены; automated tests проходят с реальными exit codes; four user findings закрыты screenshots; residual manual gates явно переданы QA.

## 12. Standards

- `/home/hermes/.hermes/team-agent-os/standards/design/ui-ux.md`
- `/home/hermes/.hermes/team-agent-os/standards/delivery/task-lifecycle.md`
- `/home/hermes/.hermes/team-agent-os/standards/delivery/handoff.md`
- `/home/hermes/.hermes/team-agent-os/standards/engineering/security.md`
- `docs/tempo-cut-five-state-visual-spec.md`
- `docs/tempo-cut-qa-evidence-checklist.md`
