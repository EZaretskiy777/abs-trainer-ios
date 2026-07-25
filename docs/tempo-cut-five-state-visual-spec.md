# ABS Trainer «Темп / Срез» — визуальная спецификация пяти состояний

Статус: **утверждённый A5 design, без переосмысления**
Назначение: implementation contract для iOS / SwiftUI
Эталонный viewport макетов: **393×852 pt**; compact reference: **320×700 pt**

## 1. Источники и приоритет

1. Карточка `t_7fe13aef`: пользователь утвердил направление «Темп / Срез» без правок.
2. Pixel truth: `/srv/hermes-workspace/abs-trainer-ios/.worktrees/t_7fe13aef/design/tempo-cut/previews/tempo-cut-{home,plan,active,rest,finish}.png`.
3. Интерактивное поведение и точные CSS-значения: `/srv/hermes-workspace/abs-trainer-ios/.worktrees/t_7fe13aef/design/tempo-cut/abs-trainer-tempo-cut.html`.
4. Токены, component contracts и SwiftUI handoff: `/srv/hermes-workspace/abs-trainer-ios/.worktrees/t_7fe13aef/docs/design-new-concept.md`.
5. Проверенные размеры, контраст и ограничения: `/srv/hermes-workspace/abs-trainer-ios/.worktrees/t_7fe13aef/docs/design-new-concept-qa.md`.
6. Responsive pixel references: `tempo-cut-small-home.png`, `tempo-cut-small-active.png`, `tempo-cut-large-active.png` из той же папки `previews/`.

Если источники расходятся, для композиции приоритет у PNG, для интеракций — у HTML, для нативной реализации и accessibility — у handoff. Отклонения перечислены в разделе 9.

## 2. Общие визуальные инварианты

### Палитра

| Token | Значение | Применение |
|---|---:|---|
| `surface.canvas` / Chalk 50 | `#F5F1E8` | Настройка, план, завершение; светлые media surfaces |
| `surface.subtle` / Chalk 100 | `#ECE5D8` | Неактивные сегменты/вторичные поверхности |
| `text.primary` / Carbon 950 | `#171714` | Основной текст; фон активного упражнения |
| `text.secondary` | handoff `#55534D`; HTML `#605E56` | Вторичный текст на Chalk |
| `action.primary` / Vermilion 700 | `#D13A25` | Активный прогресс, CTA плеера, completion symbol |
| `state.rest` / Ultramarine 700 | `#2946C6` | Выбранная зона и весь экран отдыха |
| `state.success` / Moss 700 | `#287A53` | Только success-state контролов, не декоративный акцент |
| `state.error` / Signal 600 | `#B74731` | Ошибка/деструктивное действие |
| `text.inverse` | `#FFFFFF` | Текст на Carbon, Vermilion и Ultramarine |
| `border.hairline` | Carbon 950 / 16% | Разделители и default outlines |

Подтверждённые контрастные пары: Carbon/Chalk 15.94:1; White/Carbon 17.96:1; White/Ultramarine 7.54:1; White/Vermilion 4.84:1; secondary/Chalk 5.76:1. Состояние нельзя кодировать только цветом.

### Типографика

- Семейство: системный SF Pro; для web-preview — `-apple-system`, `Helvetica Neue`, fallback sans-serif.
- Время, счётчики и номера: SF Mono/системный monospace, `.monospacedDigit()`, tabular figures.
- Основные роли handoff: display title 42/44 semibold-bold; screen title 30/34 bold; section 20/24 semibold; body 17/22 regular; label 13/16 semibold; utility number 15/18 semibold monospace.
- Состояния имеют утверждённые display-overrides: active timer 68 pt в HTML/PNG, rest countdown 116 pt, plan title 36 pt. В SwiftUI они должны быть relative/scalable и сохранять силуэт, а не фиксироваться без Dynamic Type.
- Название упражнения: максимум 2 строки на стандартных размерах; `minimumScaleFactor(0.75)` допустим только для display timer.

### Пространство, формы и chrome

- Базовая шкала: 4, 8, 12, 16, 20, 24, 32, 40, 56 pt; основной horizontal inset — 20 pt.
- Радиусы: 0 у линейного списка; 12 у choice cells; 20 у primary/secondary CTA; 28 у media aperture; круг только у timer/icon controls.
- Primary CTA: ширина контейнера, не менее 56 pt по высоте (макет 58 pt), нижний inset через safe area; на экране только один primary.
- Все интерактивные области не менее 44×44 pt; icon/close — 48 pt; pause — 56–58 pt.
- Elevation отсутствует; исключение — pause overlay/modal, один уровень тени/затемнения.
- Светлый system chrome на Carbon/Ultramarine, тёмный на Chalk; учитывать safe areas и home indicator.
- Лента темпа функциональна, не является scrubber: work-сегменты длинные, rest короткие; в плеере current дополнительно отличается от completed/upcoming.

### Motion и переходы

- Fast feedback: 120 ms ease-out; route/state: 240 ms cubic ease; exercise ↔ rest: 360 ms ease-in-out.
- `Reduce Motion`: только opacity ≤120 ms; без translate/scale и дыхательной анимации.
- Навигация: **Настройка → План → Упражнение ↔ Отдых → Завершение**.
- Back из плана возвращает настройку. Выход из активной сессии требует confirmation. Завершение: repeat → план; новая тренировка → настройка.
- Countdown хранится по reference timestamp; background/interruption восстанавливает остаток, а не продолжает слепо считать Timer ticks.

## 3. Матрица пяти состояний

### 01 — Настройка (`home`)

**Иерархия и состав сверху вниз**

1. Safe area/system status.
2. Eyebrow `ЛОКАЛЬНАЯ ТРЕНИРОВКА`.
3. H1 `Соберите свой темп` — главный визуальный акцент.
4. Body `Выберите длительность и нагрузку. План будет готов без регистрации.`
5. Секция `Сколько времени?` + справа текущее значение `10 минут`.
6. Горизонтальная ruler-линия и три duration cells: `05 МИНУТ`, `10 МИНУТ`, `15 МИНУТ`.
7. Секция `Куда нагрузка?` + `Можно несколько`.
8. Сетка 2×2: `Верхний пресс`, `Нижний пресс`, `Косые мышцы`, `Весь пресс`.
9. Закреплённый снизу CTA `Собрать тренировку` + стрелка.

**Визуальные параметры**

- Chalk canvas; Carbon title/controls; muted secondary copy.
- Content inset 20; верхняя content-позиция после 55 pt safe area; секции разделены примерно 32 pt.
- H1 42 pt/1.02, bold; section title 19–20 pt semibold; body 16–17 pt.
- Duration cells: 3 равные колонки, gap 8, min-height 72, radius 12, hairline border; selected `10` — Carbon fill + White.
- Zone cells: 2 колонки, gap 8, min-height 62 (compact 58), padding 12, radius 12; selected `Весь пресс` — Ultramarine fill + White + отдельная подпись `ВЫБРАНО`.
- Bottom CTA: inset 20, min-height 58, radius 20, Carbon/White; под ним safe-area inset.

**Состояния контролов и переходы**

- Duration — single select, `aria-pressed`/SwiftUI selected trait; выбор обновляет текст справа и plan duration.
- Zones — multi-select; `Весь пресс` взаимоисключающий. Нулевая выборка недопустима: автоматически выбрать `Весь пресс` и объявить это VoiceOver.
- Choice default: transparent + hairline; selected: fill + текстовая метка; pressed: scale 0.97–0.98 на 120 ms; disabled: muted.
- CTA default Carbon; pressed feedback; disabled 38–45% opacity; loading сохраняет 58 pt, текст `Собираем…`, spinner, повторные taps заблокированы; success может использовать Moss.
- Success generation → План. Ошибка остаётся inline: `Не удалось собрать план. Выберите «Весь пресс» или другое время.` + `Повторить`.

### 02 — План (`plan`)

**Иерархия и состав сверху вниз**

1. Safe area; top nav: back `‹`, centered `ВАШ ПЛАН`, симметричный spacer.
2. Eyebrow `СЕГОДНЯ · ВЕСЬ ПРЕСС`.
3. H1 `10 минут\nбез спешки`.
4. Meta chips: `8 упражнений`, `7 пауз`, `Начальный`.
5. Tempo rail с чередованием Carbon work и коротких Ultramarine rest segments.
6. Линейный прокручиваемый список: номер, название, зона + отдых, длительность.
7. Закреплённый CTA `Начать тренировку` + стрелка.

**Тексты строк эталона**

- `01 Скручивания` / `Верхний пресс · отдых 12 сек` / `0:40`.
- `02 Обратные скручивания` / `Нижний пресс · отдых 12 сек` / `0:40`.
- `03 Велосипед с поворотом` / `Косые мышцы · отдых 12 сек` / `0:40`.
- `04 Планка` / `Весь пресс · отдых 15 сек` / `0:45`.
- `05 Мёртвый жук` / `Весь пресс · отдых 12 сек` / `0:45`.
- UI обязан показывать фактический полный план из 8 упражнений; 5 строк в PNG/HTML — видимая часть scroll viewport, не лимит данных.

**Визуальные параметры**

- Chalk canvas; Carbon heading/text; Vermilion-dark utility numbers; Ultramarine только rest rail.
- Top icon control 48×48. Summary horizontal inset 20; H1 36 pt; meta chips min-height 30, pill radius, hairline border.
- Rail: margin-top 20, gap 4, height 7; rest segment ≈35% длины work.
- Workout row: min-height 79, grid `34 pt / flexible / intrinsic time`, gap 12, bottom hairline, без card/elevation.
- Number 13 pt monospace; title 16 pt bold, до 2 строк; metadata 12 pt muted; time 14 pt monospace, не сжимается.
- Bottom CTA совпадает с setup primary contract.

**Состояния контролов и переходы**

- Back → Настройка с сохранением выбранных параметров.
- Список scrollable; CTA остаётся над safe area, content имеет нижний резерв не менее 120 pt.
- Tempo rail имеет доступное суммарное описание, не принимает taps.
- `Начать тренировку` → первое Упражнение; loading/disabled сохраняют размер CTA, если подготовка session store асинхронна.

### 03 — Активное упражнение (`active`)

**Иерархия и состав сверху вниз**

1. Carbon full-field canvas + inverse system chrome.
2. Верхняя строка: close `×`, centered progress `03 / 08`, spacer.
3. Player rail: completed Vermilion, current White, upcoming White/18%.
4. Название `Велосипед\nс поворотом`; справа label `КОСЫЕ`.
5. Chalk media aperture: badge `ДЕМО ДВИЖЕНИЯ`, placeholder/3D, cue `Поясница прижата · локоть тянется к колену`.
6. Главный countdown `0:37`; справа `Осталось в этом упражнении`.
7. Нижние controls: круглая pause `Ⅱ`; Vermilion CTA `Далее · отдых 12 сек`.

**Визуальные параметры**

- Carbon background, White content, Vermilion progress/action; muted inverse text White/62–66%.
- Player horizontal inset 20 (top row 16); rail height 5, gap 4.
- Exercise title 30 pt/1.0 bold, максимум 2 строки. Zone label 11 pt uppercase.
- Media aperture: 286 pt high at reference; radius 28; Chalk/Carbon; flexible aspect 1:1…4:3. Compact 320×700: 230 pt high.
- Timer: 68 pt monospace/tabular (compact 58), line-height .95; label 12 pt.
- Controls: pause 58×58 circle with inverse border; next min-height 58, radius 20, Vermilion/White.

**Состояния контролов и переходы**

- Player rail semantics: `completed`, `current`, `upcoming`; accessible value `Шаг 3 из 8`.
- Pause останавливает reference countdown и открывает modal overlay: `Пауза`, `Таймер остановлен. Продолжите, когда будете готовы.`, primary `Продолжить тренировку`. Фокус/VoiceOver переходит в dialog; resume возвращает фокус на pause.
- Next или timer zero → Отдых; на последнем упражнении → Завершение. Досрочное завершение последнего шага требует confirmation.
- Close/Back → confirmation с default `Продолжить тренировку` и destructive `Завершить`; accidental exit недопустим.
- Placeholder имеет VoiceOver label `Демонстрация упражнения недоступна`/эквивалент с названием и не объявляется как реальное видео. CTA поверх media не размещать.
- Countdown VoiceOver объявляет только 10/5/3/2/1 и смену состояния, не каждую секунду.

### 04 — Отдых (`rest`)

**Иерархия и состав сверху вниз**

1. Ultramarine full-field canvas + inverse system chrome.
2. Eyebrow `ПАУЗА МЕЖДУ УПРАЖНЕНИЯМИ`.
3. H1 `Вдох.\nМедленный\nвыдох.`.
4. Главный countdown `12`.
5. Тонкая breath/progress line.
6. Прижатый к низу блок next-up: `ДАЛЬШЕ · 04 ИЗ 08`, `Планка`, `0:45`.
7. Outline CTA `Пропустить отдых` над safe area.

**Визуальные параметры**

- Canvas Ultramarine `#2946C6`; весь контент White, вторичный White/65–72%; разделители White/30%.
- Основной inset 20. Eyebrow 12 pt uppercase; H1 48 pt/.95 bold; countdown 116 pt/.8 monospace/tabular.
- Breath line 2 pt; next-up ограничен верхним/нижним hairline; next title 20 pt.
- Skip CTA min-height 58, radius 20, transparent + White/45% border, White label.
- Экран без карточек, иллюстрации и secondary chrome: синее поле является самостоятельным transition state.

**Состояния контролов и переходы**

- Countdown и line отражают один источник времени; animation декоративна и скрыта от accessibility.
- `Пропустить отдых` или timer zero → следующее Упражнение; кнопка остаётся доступна весь интервал.
- При `Reduce Motion` дыхательная line статична/opacity-only.
- VoiceOver при входе объявляет `Отдых, 12 секунд`, затем контрольные значения 10/5/3/2/1; next-up читается после countdown.

### 05 — Завершение (`finish`)

**Иерархия и состав сверху вниз**

1. Chalk canvas + dark system chrome.
2. Eyebrow `ТРЕНИРОВКА ЗАВЕРШЕНА`.
3. Completion symbol: Vermilion ring с Carbon check, декоративный.
4. H1 `Темп\nвыдержан.`.
5. Body `Все упражнения выполнены. Результат сохранён только на этом устройстве.`
6. Двухколоночный results strip: `10:04 / фактическое время`; `8 / 8 / упражнений`.
7. Primary `Повторить тренировку` + repeat symbol.
8. Secondary text button `Настроить новую`.

**Визуальные параметры**

- Chalk canvas; Carbon primary; muted secondary; Vermilion только completion ring.
- Main inset 20; completion symbol 154×154, ring 18; H1 42 pt/1.0 bold.
- Results: 2 равные колонки; top/bottom hairlines; vertical divider; values 30 pt monospace; labels 12 pt muted.
- Primary min-height 58, radius 20, Carbon/White. Secondary min-height 48, transparent Carbon.
- Показывать только фактические duration и completed count; не добавлять калории, streak или вымышленные метрики.

**Состояния контролов и переходы**

- `Повторить тренировку` → тот же План с исходными параметрами; символ не заменяет текстовую label.
- `Настроить новую` → Настройка; выбранные defaults определяет product state, не макет.
- Results container получает доступную группу/summary; декоративный check исключён из VoiceOver.

## 4. Компактные размеры и адаптация

- Обязательный pixel reference: 320×700; дополнительный: 430×932. Horizontal overflow запрещён.
- Setup на 320×700 остаётся вертикально scrollable; fixed CTA не перекрывает последнюю selected label. Для compact: H1 38 pt, меньшие section gaps 24, zone min-height 58.
- Plan list scrollable; header может занимать intrinsic height, CTA остаётся в `safeAreaInset`; строки не ужимать ниже читаемого контракта.
- Active на compact: aperture 230 pt, timer 58 pt, controls всегда достижимы; title/cue переносятся, но не клипуются.
- При недостаточной высоте вертикальный scroll/адаптивный layout предпочтительнее уменьшения tap target или скрытия ключевого контента.
- Landscape и высоты ниже 700 pt не зафиксированы pixel-макетами: реализация обязана сохранить safe areas, доступ к pause/next/skip и отсутствие clipping; это milestone QA, а не разрешение переосмыслить композицию.

## 5. Dynamic Type

- Использовать semantic text styles/`@ScaledMetric`, а не буквальные фиксированные размеры из HTML.
- Проверить диапазон до Accessibility 3. H1, exercise name и instructions допускают рост высоты и перенос; не обрезать essential copy.
- Timer может применять `minimumScaleFactor(0.75)` и `monospacedDigit()`; число и единица/контекст должны оставаться читаемыми.
- При больших размерах: stack вместо тесной горизонтали для section header, exercise copy, timer label, next-up и results; CTA label допускает перенос при сохранении min 56 pt и полной tap area.
- Fixed bottom controls реализовывать через `safeAreaInset`, чтобы scroll content получал реальный нижний резерв.

## 6. VoiceOver и семантика

- На route change переводить accessibility focus на H1 и объявлять состояние: настройка, план, `Упражнение N из M`, `Отдых N секунд`, завершение.
- Choice controls: label + selected/not selected; selected состояние выражено trait/текстом, не цветом. Группы duration/zones имеют group labels.
- Tempo rail и player rail — не интерактивные; сообщают sequence/progress единым accessibility value, не каждый декоративный segment.
- Порядок Active: exit → progress → exercise/zone → media status/cue → timer context → pause → next.
- Порядок Rest: state/title → countdown → next-up → skip.
- Pause overlay — modal focus scope; после закрытия focus возвращается на pause.
- Динамические объявления countdown только на 10/5/3/2/1 и state changes; избегать ежесекундного спама.
- Все строки локализовать через String Catalog; предложения не собирать конкатенацией.

## 7. Tap targets и control states

| Контрол | Min target | Default | Selected/active | Disabled/loading | Focus/VoiceOver |
|---|---:|---|---|---|---|
| Duration/zone choice | 52 pt contract; макет 58–72 | Hairline/transparent | Fill + inverse text + текстовая selected cue | Muted | 3 pt focus outline; selected trait |
| Primary CTA | 56 pt; макет 58 | Carbon/White | Pressed feedback; player CTA Vermilion | 38–45%; spinner + stable size | Label описывает результат |
| Icon/back/close | 44×44; макет 48×48 | Transparent | Press feedback | Muted | Явная label, не один glyph |
| Pause | 56×56; макет 58×58 | Inverse outline circle | Открывает `Пауза` | Не исчезает во время сессии | `Поставить тренировку на паузу` |
| Skip rest | 56 pt; макет 58 | White outline on blue | Press feedback | Только при невозможном переходе | `Пропустить отдых` |
| Finish secondary | 44 pt; макет 48 | Transparent Carbon | Press feedback | Muted | `Настроить новую` |

Никакая видимая кнопка или её SwiftUI `contentShape` не может быть меньше 44×44 pt.

## 8. Acceptance criteria

| ID | Критерий | Проверка | Статус источника |
|---|---|---|---|
| AC-01 | Реализованы ровно пять ключевых состояний и переходы Setup → Plan → Active ↔ Rest → Finish | UI test + visual capture | Утверждено |
| AC-02 | 393×852 визуально совпадает по surface, hierarchy, copy, palette, spacing rhythm, form и control placement с 5 core PNG | Screenshot parity review | Утверждено |
| AC-03 | На 320×700 нет overlap/clipping/horizontal overflow; CTA/controls достижимы | Small-device screenshots + interaction test | Утверждено HTML/PNG |
| AC-04 | На Plan отображается полный фактический план; строки линейные, scrollable, duration не сжимается | UI/unit test | Утверждено; данные динамические |
| AC-05 | Active countdown переживает pause/background по timestamp; exit подтверждается | Session-store tests + UI test | Handoff contract |
| AC-06 | Rest автоматически ведёт к следующему упражнению; skip доступен; Reduce Motion отключает breathing motion | UI test + accessibility setting | Handoff contract |
| AC-07 | Finish показывает только factual duration/completed count; repeat и new routes корректны | State/UI test | Утверждено |
| AC-08 | Все tap areas ≥44×44 pt, primary ≥56 pt; safe-area controls не перекрывают content | Accessibility Inspector + geometry tests | Утверждено |
| AC-09 | Dynamic Type до Accessibility 3 без потери essential content | Real iPhone/simulator matrix | Обязательный milestone |
| AC-10 | VoiceOver labels, traits, focus order, modal focus и sparse countdown announcements корректны | VoiceOver manual pass | Обязательный milestone |
| AC-11 | Reduce Motion, Increase Contrast и landscape не создают clipping и не скрывают controls | Manual matrix | Обязательный milestone |
| AC-12 | Контраст не ниже утверждённых пар; system chrome инвертируется на Active/Rest | Accessibility Inspector + screenshots | Утверждено для HTML; повторить в SwiftUI |
| AC-13 | Placeholder честно обозначен и заменяется 3D media без изменения `ExerciseMediaAperture` layout contract | VoiceOver + visual test | A7 milestone |
| AC-14 | Нет новых cards, gradients/glow, decorative metrics или второго primary CTA | Design review | Утверждённый invariant |

## 9. Противоречия, отсутствующие данные и milestones

1. **Secondary color:** handoff указывает Carbon 700 `#55534D`, HTML использует `#605E56`; PNG соответствует HTML. Для pixel parity использовать HTML/PNG, затем зафиксировать единый named asset перед production lock.
2. **Display sizes:** handoff задаёт общий timer role 80/80 pt, HTML/PNG — active 68 pt и rest 116 pt. Это state-specific overrides, которые должны масштабироваться относительно Dynamic Type; нельзя механически назначить 80 pt обоим состояниям.
3. **Pressed primary:** component contract описывает pressed Vermilion; HTML применяет Vermilion на hover и scale на active. У iOS нет hover как основного состояния: сохранить визуальный default и краткий pressed feedback, а Vermilion оставить семантическим CTA активного плеера; финальное pressed значение сверить screenshot-тестом.
4. **Фактический SwiftUI QA отсутствует:** Dynamic Type, VoiceOver rotor/focus, Increase Contrast, Reduce Transparency, landscape и system interruptions ещё не проверены на iPhone. Это обязательный implementation milestone, не закрытый HTML QA.
5. **Высоты <700 pt и landscape:** отдельных утверждённых pixel layouts нет. Требуется адаптивная проверка без переизобретения иерархии.
6. **3D media:** текущая фигура — placeholder. Финальный asset/loop, loading/failure poster и техника его воспроизведения относятся к A7; контракт aperture и честная accessibility label уже фиксированы.
7. **Figma destination отсутствует:** источник истины на текущем этапе — перечисленные HTML/PNG/docs; SwiftUI parity должен проверяться по ним.

Любое изменение палитры, композиционной модели, линейного плана, полноэкранного rest-state или режимной инверсии Active требует отдельного design approve; адаптация под accessibility и compact sizes таким изменением не считается.
