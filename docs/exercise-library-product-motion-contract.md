# ABS Exercises — продуктовый, контентный и motion-контракт каталога

Статус: implementation-ready contract для design → iOS

Kanban: `t_20da9545`

Следующая задача: `t_f1d72cf8` (`designer`)

Платформа: iOS 16+, SwiftUI, полностью локально, без backend

## 0. Назначение и границы

Документ задаёт проверяемый контракт отдельного раздела **«Упражнения»** для текущих 10 элементов `ExerciseCatalog.starter`, включая IA, каталог, поиск/фильтры, detail, безопасный контент, оригинальные loop-анимации, offline/performance/accessibility и asset manifest.

Приоритет источников при конфликте:

1. Этот контракт для нового раздела Exercises и новых motion assets.
2. Актуальный код ветки `feature/tempo-cut-swiftui` как factual baseline существующих типов и flow.
3. `docs/abs-trainer-v2-domain-contract.md` для значений focus/intensity и общего Setup → Plan → Active → Rest → Finish.
4. Существующий Tempo visual language и design artifacts — для стиля, но не для изменения scope этого документа.
5. `docs/asset-plan.md` — исторический placeholder plan; конкретные имена и ограничения этого контракта его уточняют.

В scope:

- read-only библиотека 10 упражнений;
- локальные поиск и фильтры;
- detail каждого упражнения;
- 10 оригинальных демонстрационных loop-анимаций и poster frames;
- безопасные нейтральные подсказки техники;
- состояния loading/fallback/empty/no-results;
- accessibility, Reduce Motion, offline, app-size/performance;
- inspectable manifest с provenance и checksum.

Не в scope:

- изменение состава тренировки из detail, избранное, история, пользовательские коллекции;
- персональные/медицинские рекомендации, диагнозы, реабилитация, калории, пульс, оценка боли;
- backend, аккаунт, аналитика, remote media/CDN;
- premium lock/paywall или покупки (весь starter catalog остаётся `.free`);
- копирование чужого брендинга, персонажей, роликов или motion assets;
- App Store/TestFlight, signing, archive или upload.

## 1. Проверенный baseline репозитория

| Наблюдение | Evidence |
|---|---|
| `Exercise` уже хранит `id`, `title`, `zones`, `difficulty`, work/rest duration, `mediaName`, placeholder flag и access level | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:88-98` (`Exercise`) |
| Стабильные зоны: `upper/lower/obliques/full` | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:3-28` (`AbsZone`) |
| Сложность: `beginner/intermediate/advanced`; starter использует только первые две | `ios/AbsTrainer/Sources/AbsTrainer/Models.swift:30-34`, `ios/AbsTrainer/Sources/AbsTrainer/ExerciseCatalog.swift:5-14` |
| `ExerciseCatalog.starter` содержит ровно 10 локальных `.free` элементов с `isPlaceholderMedia: true` | `ios/AbsTrainer/Sources/AbsTrainer/ExerciseCatalog.swift:3-16` (`ExerciseCatalog.starter`) |
| Текущий root — typed `NavigationStack`; routes существуют только для plan/session | `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift:4-15`, `:23-68` (`ContentView.Route`, `path`) |
| Setup содержит duration, zones, intensity и primary CTA `Собрать тренировку` | `ios/AbsTrainer/Sources/AbsTrainer/ContentView.swift:10-16`, `:74-181` |
| Active вызывает `ExerciseMediaAperture(exercise:)` | `ios/AbsTrainer/Sources/AbsTrainer/ExercisePlayerView.swift:123-157` |
| Aperture сейчас всегда показывает один SF Symbol и общую строку; `mediaName` не читает | `ios/AbsTrainer/Sources/AbsTrainer/DesignSystem.swift:772-804` (`ExerciseMediaAperture`) |
| Bundle resources сейчас включают только `Assets.xcassets` и `Localizable.xcstrings`; exercise video файлов нет | `ios/AbsTrainer/AbsTrainer.xcodeproj/project.pbxproj:20-21`, `:63-65`, `:82-84` |
| Deployment target — iOS 16 | `ios/AbsTrainer/AbsTrainer.xcodeproj/project.pbxproj:98-105`; `ios/AbsTrainer/README.md:1-4` |

Следствия:

- раздел Exercises и реальные media — **новый scope**, а не уже существующее поведение;
- `Exercise.id` остаётся стабильным join key для каталога, detail, manifest и assets;
- `Exercise.mediaName` должен стать базовым именем final video, а `isPlaceholderMedia` — `false` только после успешного bundle/manifest validation;
- дополнительные тексты detail отсутствуют в текущем `Exercise`; iOS должен читать их из локального content manifest/типизированного content catalog либо расширить модель отдельной согласованной задачей;
- историческая строка `placeholder_mountain` в `docs/asset-plan.md:16` не совпадает с фактическим `placeholder_mountain_climber`; источником истины служит фактический id `mountain_climber` и naming ниже.

## 2. Пользовательская ценность и stories

### US-1 — открыть библиотеку без потери Setup

Как пользователь, я хочу открыть список упражнений с Setup и вернуться с сохранёнными текущими duration/focus/intensity, чтобы посмотреть технику до тренировки.

Acceptance:

- на Setup доступно одно secondary действие `Упражнения`;
- открытие не генерирует и не меняет `WorkoutPlan`;
- Back возвращает на тот же Setup с теми же in-memory selections;
- primary CTA `Собрать тренировку` остаётся единственным primary действием.

### US-2 — найти упражнение

Как пользователь, я хочу искать по названию и фильтровать по зоне/сложности, чтобы быстро открыть подходящую демонстрацию.

Acceptance:

- поиск и фильтрация выполняются локально и мгновенно для 10 записей;
- результат является пересечением search × zone × difficulty;
- сброс очищает query и возвращает `Все зоны` / `Любая сложность`;
- no-results не выглядит как ошибка и предлагает `Сбросить фильтры`.

### US-3 — изучить технику

Как пользователь, я хочу увидеть понятную цикличную демонстрацию и короткие нейтральные подсказки, чтобы воспроизвести основные фазы движения.

Acceptance:

- detail доступен для 10/10 ids;
- visual, title, metadata и текст не противоречат друг другу;
- при Reduce Motion или media failure смысл сохраняют poster + текстовые фазы;
- copy не обещает безопасность, лечение или гарантированный результат.

## 3. IA и навигационный контракт

Логические routes:

```text
Setup
 ├─ Generate → Plan → Active ↔ Rest → Finish
 └─ Exercises → Exercise Library → Exercise Detail(id)
                                  └─ Back → Library → Back → Setup
```

### 3.1 Entry из Setup

- Разместить `Упражнения` как secondary text/icon action (`list.bullet.rectangle`) в header/top trailing area, minimum hit target 44×44 pt.
- Accessibility label: `Открыть каталог упражнений`.
- Действие доступно в обычном Setup. Пока идёт generation (`isGenerating == true`) оно disabled, чтобы исключить конкурирующие pushes.
- Оно не сбрасывает `selectedDuration`, `selectedZones`, `selectedIntensity`, `plan` и не вызывает generator.
- Back использует системную navigation semantics; custom back допустим только при сохранении edge-swipe, label `Назад` и focus restoration.
- Deep link и отдельная tab bar для MVP не требуются.

### 3.2 Library hierarchy

Порядок чтения:

1. navigation title `Упражнения`;
2. search field `Найти упражнение`;
3. горизонтально scrollable zone chips;
4. difficulty control;
5. строка результата (`10 упражнений`, plural-aware);
6. vertical list/grid cards.

Default sort — порядок `ExerciseCatalog.starter`, а не алфавитный: он детерминирован и совпадает с source catalog. Поиск не меняет относительный порядок совпадений.

### 3.3 Detail hierarchy

1. Back + title в navigation context.
2. Motion aperture 1:1.
3. Название.
4. Zone chips, difficulty, `Работа · N сек`, `Отдых · N сек`.
5. `Как выполнять` — 3 короткие пронумерованные фазы.
6. `Обратите внимание` — 2 нейтральные form cues.
7. Всегда видимый общий дисклеймер:
   `Демонстрация носит ознакомительный характер. Выбирайте комфортную амплитуду и остановитесь, если движение вызывает дискомфорт.`

В detail нет Start/Add/Buy CTA: это справочный read-only раздел. Возврат сохраняет query, filters и приблизительную scroll position в рамках живого navigation stack.

## 4. Каталог, поиск, фильтры и состояния

### 4.1 Card contract

Каждая card показывает:

- poster 1:1, декоративный при наличии доступного текстового label card;
- `title`;
- до двух zone chips в порядке `Exercise.zones`;
- localized difficulty: `Начальный` / `Средний` / `Продвинутый`;
- `N сек` из `defaultDurationSec`;
- chevron как декоративный navigation affordance.

Вся card — один accessibility element и один tap target. Label example: `Скручивания, верхний пресс, начальный уровень, 40 секунд`. Hint: `Открывает описание и демонстрацию`.

### 4.2 Search normalization

- trim leading/trailing whitespace;
- case-insensitive и diacritic-insensitive matching;
- match по русскому `title`; ids и английские внутренние названия пользователю не показываются и в MVP не ищутся;
- debounce не нужен для 10 local items; обновление на каждый ввод;
- empty query означает все записи;
- search text не сохраняется после завершения process и не логируется.

### 4.3 Filters

Zone — single-select chips:

- `Все зоны` (default, filter отсутствует);
- `Верхний` → `.upper`;
- `Нижний` → `.lower`;
- `Косые` → `.obliques`;
- `Весь пресс` → `.full`.

Совпадение zone строгое: выбранная zone должна присутствовать в `Exercise.zones`. В отличие от workout generator, `.full` в библиотечном фильтре **не означает весь каталог**; для отсутствия фильтра есть отдельный chip `Все зоны`.

Difficulty — single-select:

- `Любая сложность` (default);
- `Начальный` → `.beginner`;
- `Средний` → `.intermediate`;
- `Продвинутый` → `.advanced`.

`Продвинутый` допустимо показывать disabled с count 0 либо скрыть в MVP; выбранным он быть не может, пока catalog не содержит advanced. Designer должен выбрать один вариант и явно аннотировать его; предпочтение — скрыть нулевую опцию, чтобы не создавать ложное ожидание.

### 4.4 UI states

| State | Trigger | UI/behavior |
|---|---|---|
| Ready | local catalog valid | controls + cards; no spinner |
| Loading | только короткая подготовка bundled manifest/posters | skeleton без layout jump; search/filter disabled; не дольше фактической операции |
| Empty catalog | manifest/catalog validation даёт 0 valid items | `Каталог пока недоступен`; secondary `Назад к настройке`; не crash |
| No results | valid catalog, filter result 0 | `Ничего не найдено`; `Попробуйте изменить поиск или фильтры`; button `Сбросить фильтры` |
| Video loading | detail video ещё готовится | poster остаётся видимым; compact progress indicator имеет label `Загрузка демонстрации` |
| Video failed/missing | file/decode/manifest mismatch | poster + phases; caption `Анимация недоступна`; без бесконечного retry/spinner |
| App inactive/background | scene не active | playback pause; на active resume с начала loop или остаётся poster |

Поскольку данные bundled, normal Ready не должен симулировать network loading.

## 5. Контентный контракт 10 упражнений

Правила copy:

- повелительные, короткие, наблюдаемые действия; без «идеально», «безопасно», «лечит», «сжигает жир», «убирает боль»;
- `Обратите внимание` описывает положение/темп, а не диагноз или риск;
- амплитуда обозначается как комфортная; никакого универсального обещания правильности для любого пользователя;
- breathing cues нейтральны и не требуют задержки дыхания;
- текст и motion storyboard должны проходить совместный review designer + domain-aware human; этот документ не заменяет медицинскую экспертизу.

| id / title | Metadata (source catalog) | `Как выполнять` — 3 фазы | `Обратите внимание` — 2 cues |
|---|---|---|---|
| `crunch` / Скручивания | upper · beginner · 40/12 сек | 1. Лягте, согните колени, поставьте стопы. 2. На выдохе приподнимите плечи, направляя рёбра к тазу. 3. Плавно опустите плечи. | Сохраняйте шею продолжением спины. Поясница остаётся в комфортном контакте с опорой. |
| `reverse_crunch` / Обратные скручивания | lower · beginner · 40/12 сек | 1. Лягте, поднимите согнутые ноги. 2. Подведите колени к корпусу и слегка приподнимите таз. 3. Контролируемо верните таз и ноги. | Не разгоняйте ноги. Сохраняйте движение небольшим и плавным. |
| `bicycle_twist` / Велосипед с поворотом | obliques, full · intermediate · 40/12 сек | 1. Лягте, поднимите согнутые ноги и плечи. 2. Поверните корпус к противоположному колену, вытягивая другую ногу. 3. Через центр смените сторону. | Поворачивайте корпус, не тяните голову рукой. Двигайтесь в ровном темпе без рывка. |
| `plank` / Планка | full · beginner · 45/15 сек | 1. Поставьте предплечья под плечами. 2. Вытяните ноги и соберите корпус в одну линию. 3. Удерживайте положение до конца интервала. | Направляйте макушку вперёд, пятки назад. Выберите положение колен как упрощение, если так комфортнее. |
| `mountain_climber` / Альпинист | lower, full · intermediate · 40/15 сек | 1. Примите упор на ладонях. 2. Подведите одно колено к корпусу. 3. Верните ногу и смените сторону. | Ладони остаются под плечами. Сохраняйте темп, при котором корпус не раскачивается резко. |
| `toe_touch` / Касания стоп | upper · beginner · 40/12 сек | 1. Лягте и поднимите ноги вверх с комфортным сгибом. 2. Потянитесь руками в сторону стоп, приподнимая плечи. 3. Плавно верните плечи на опору. | Не прижимайте подбородок к груди. Достаточна небольшая амплитуда подъёма. |
| `leg_raise` / Подъём ног | lower · intermediate · 40/15 сек | 1. Лягте, вытяните ноги или слегка согните колени. 2. Поднимите ноги до комфортного угла. 3. Медленно опустите, не бросая их на опору. | Уменьшите амплитуду, если поясница теряет комфортное положение. Не используйте инерцию. |
| `russian_twist` / Русские скручивания | obliques · intermediate · 40/12 сек | 1. Сядьте с согнутыми коленями и слегка отклоните корпус. 2. Поверните грудную клетку в одну сторону. 3. Через центр повернитесь в другую. | Стопы могут оставаться на полу. Поворот идёт всем корпусом без резкого движения рук. |
| `dead_bug` / Мёртвый жук | full · beginner · 45/12 сек | 1. Лягте, поднимите руки и согнутые ноги. 2. Вытяните противоположные руку и ногу. 3. Вернитесь в центр и смените сторону. | Двигайтесь медленно и сохраняйте корпус устойчивым. Укоротите траекторию конечностей при необходимости. |
| `hollow_hold` / Удержание лодочки | full · intermediate · 35/15 сек | 1. Лягте и приподнимите плечи. 2. Поднимите согнутые или вытянутые ноги до комфортной высоты. 3. Удерживайте компактное положение. | Согнутые колени — допустимое упрощение. Не увеличивайте амплитуду ценой контролируемого положения корпуса. |

`40/12 сек` означает `defaultDurationSec/restAfterSec`; final detail должен подписывать эти значения отдельно, а не показывать slash notation.

## 6. Visual и motion direction

### 6.1 Общий visual contract

- Оригинальная нейтральная спортивная фигура без сходства с известным персонажем или реальным человеком, без логотипов, текста на одежде и брендовых элементов.
- Один согласованный персонаж/материал/свет/камера во всех 10 assets; различия только в позе и нужном framing.
- Высокий силуэтный контраст на Tempo `chalkSubtle`/`carbon`; не использовать цвет как единственный способ различить движущиеся части.
- Камера статична; без zoom, shake, cuts, flashes, быстро движущегося фона и декоративных частиц.
- Полностью видны опорные точки и траектория: голова/таз/локти/колени/стопы не обрезаются в ключевых фазах.
- Нельзя изображать болезненную гиперамплитуду, резкий удар об опору или «до/после» результат.

### 6.2 Единый export profile

| Property | Contract |
|---|---|
| Container | `.mp4` |
| Video codec | H.264, `yuv420p`, без alpha, без audio track |
| Dimensions | 720×720 px, square, square pixels, rotation metadata 0 |
| Frame rate | constant 30 fps |
| Duration | 4.0 s ± 0.1 s; ровно 120 frames предпочтительно |
| Loop | seamless; last→first без видимого jump, flash или duplicate pause |
| Color | SDR, sRGB/Rec.709-consistent; без HDR |
| Poster | `.jpg`, 720×720, sRGB, quality достаточная без ringing; отдельный meaningful key pose |
| File names | `exercise_<id>_v1.mp4`, `exercise_<id>_poster_v1.jpg` |
| Playback | muted, inline, aspect fit; loop only while detail visible and app active |
| Per-video budget | target ≤ 900 KB; hard max 1.2 MB |
| Poster budget | target ≤ 90 KB; hard max 140 KB |
| Total exercise media | hard max 13.4 MB для 10 videos + 10 posters; target ≤ 10 MB |

Designer передаёт master/source отдельно от app exports. Source может иметь большее разрешение, но app bundle получает только profile выше. GIF не является runtime format; он допустим только как preview/contact-sheet artifact.

### 6.3 Loop grammar

- Начальная и конечная поза идентичны по root transform и освещению.
- Для динамических движений: `start → controlled effort → return → start`, без искусственной неподвижной паузы длиннее 0.35 s.
- Для alternating упражнений один loop показывает обе стороны и возвращается в центр.
- Для holds: subtle breathing/weight shift с амплитудой, не меняющей форму упражнения; loop не должен выглядеть frozen из-за decode failure.
- Скорость демонстрации иллюстративна и не синхронизируется с workout countdown; UI не обещает cadence.

## 7. Motion storyboard 10/10

| id | Camera/framing | 4-second phases and loop seam | Poster key pose | Text/visual consistency gate |
|---|---|---|---|---|
| `crunch` | 3/4 side, full mat + head/knees | 0.0 neutral; 0.5–1.6 shoulders rise; 1.6–2.0 top; 2.0–3.4 lower; 3.4–4.0 neutral | mid-rise | Таз/стопы стабильны; движение — shoulders/ribs, не sit-up. |
| `reverse_crunch` | side 3/4, pelvis and knees visible | 0.0 tabletop; 0.5–1.6 knees approach + small pelvic curl; 1.6–2.0 peak; 2.0–3.5 return; seam tabletop | small pelvic curl | Нет leg swing или переноса ног за голову. |
| `bicycle_twist` | elevated front 3/4, both elbows/feet in frame | 0.0 center; 0.3–1.2 left twist/right leg extend; 1.2–2.0 center; 2.0–2.9 right twist/left leg extend; 2.9–4.0 center | one diagonal pair | Показаны обе стороны; локоть не давит на голову. |
| `plank` | side, head-to-heels/optional knees in frame | hold throughout; subtle 2-cycle breathing/weight shift; exact root reset at seam | neutral straight-line hold | Нет push-up или hip dip; optional knee variant только в отдельной annotation, не morph. |
| `mountain_climber` | high side/front 3/4, hands and feet visible | 0.0 plank; 0.3–1.1 knee A in/out; 1.1–2.0 center; 2.0–2.8 knee B in/out; 2.8–4.0 center | one knee forward | Обе стороны; плечи остаются над ладонями, без sprint blur. |
| `toe_touch` | side/front 3/4, hands and feet visible | 0.0 shoulders down/hands up; 0.5–1.5 reach; 1.5–2.0 peak; 2.0–3.4 lower; seam neutral | reach toward feet | Ноги не качаются; это короткий shoulder lift. |
| `leg_raise` | side, full legs + pelvis visible | 0.0 legs low at comfortable angle; 0.4–1.5 lift; 1.5–2.0 high; 2.0–3.6 controlled lower; seam low | ~45° legs | Не показывать касание пола/рывок; допустим мягкий сгиб коленей. |
| `russian_twist` | front 3/4, seated base and knees visible | 0.0 center; 0.3–1.1 rotate A; 1.1–2.0 center; 2.0–2.8 rotate B; 2.8–4.0 center | rotation to one side | Стопы на полу в основной версии; не имитировать бросок веса. |
| `dead_bug` | overhead 3/4, all limbs visible | 0.0 tabletop; 0.3–1.2 opposite pair A extend/return; 1.2–2.0 center; 2.0–2.9 pair B; 2.9–4.0 center | one opposite pair extended | Противоположные конечности однозначны; корпус не перекатывается. |
| `hollow_hold` | side, full body visible | hold compact variant; subtle breathing at 0–2 and 2–4; exact pose at seam | compact bent-knee hold | Основная визуализация — доступный bent-knee variant; без качания/rock. |

Анатомическая понятность здесь означает читаемую последовательность поз, а не медицинскую сертификацию. До final export обязательна human review всех 10 storyboards по текстовым фазам §5.

## 8. Playback, fallback и Reduce Motion

### 8.1 Runtime priority

1. Valid bundled MP4 + poster + matching manifest → show poster immediately, затем muted loop.
2. MP4 missing/decode failure/checksum mismatch → poster + phases + `Анимация недоступна`.
3. Poster missing → deterministic SwiftUI fallback (`figure.core.training`, title, first technique cue) + phases.
4. Catalog content missing/invalid for конкретного id → не показывать broken card; validation report обязан назвать id.

Никакой network загрузки или замены remote URL не допускается.

### 8.2 Reduce Motion

При `accessibilityReduceMotion == true`:

- video не autoplay и не loop;
- показывается static poster с badge/label `Статичная демонстрация`;
- текстовые фазы полностью доступны;
- нет parallax, pulsing, scale/slide transitions; navigation может использовать системный reduced transition/короткий opacity;
- пользователь не обязан нажимать Play, чтобы получить весь смысл. Optional explicit `Воспроизвести анимацию` допустима только если designer/iOS добавят её как secondary control и она не autoplay после каждого возврата.

При Low Power Mode допустим тот же poster-first режим; это performance policy, не ошибка.

### 8.3 Playback lifecycle/performance

- В Library cards показывать только posters; одновременно проигрывающихся videos в list = 0.
- В Detail одновременно активен максимум один player item.
- Preload только текущего local asset; не создавать 10 `AVPlayer` заранее.
- Pause при disappearance, background, screen lock и interruption; освобождать player при уходе из detail.
- Loop не должен перезапускать audio session: audio track отсутствует, app audio не прерывается.
- Первый meaningful frame — poster без blank/black flash; target poster paint ≤100 ms после появления detail на поддерживаемом устройстве, video start target ≤500 ms для local file.
- Memory warning не влияет на доступность текста/poster; cached player освобождается.

## 9. Accessibility и responsive contract

### 9.1 Semantics

- Search field имеет visible/AX label `Найти упражнение` и стандартное clear действие.
- Filter chips сообщают selected state; группа zone label `Фильтр по зоне`, difficulty — `Фильтр по сложности`.
- Result count обновляется доступным status announcement только после явного изменения query/filter; не объявлять каждую введённую букву сверх системного search feedback.
- Motion aperture — один element: `Демонстрация упражнения «<title>»`. Не озвучивать каждый кадр.
- Poster alt не повторяет весь card; декоративные изображения hidden, если card уже имеет составной label.
- Phases — ordered list с естественным reading order.
- Не полагаться на цвет/анимацию для zones, difficulty, selected или failure state.
- Touch targets ≥44×44 pt; focus возвращается к opener/back target после dismiss/pop.

### 9.2 Dynamic Type / compact / landscape

- Поддержать Dynamic Type до Accessibility 3 без скрытого content; title/metadata wrap, не truncate критичные названия.
- Library — одна колонка при compact width и accessibility sizes; две колонки допустимы только regular width после visual QA.
- Zone chips горизонтально scrollable и имеют дополнительное `Сбросить` действие, доступное без добирания до конца ряда.
- Detail — один vertical `ScrollView`; motion aperture сохраняет 1:1, но может уменьшаться до доступной ширины; текст не overlay на video.
- Landscape compact: content остаётся vertical scroll; допустим двухколоночный detail (media слева, text справа), только если reading order media → title/metadata → phases → cues сохраняется.
- Pinned controls не перекрывают последнюю card/phase; учитывать safe areas и keyboard search.
- Проверочные viewports: 320×568/SE-class, 393×852, landscape compact, iPad regular; text sizes default и AX3.

## 10. Offline, app-size, integrity, rights и provenance

### 10.1 Offline/integrity

- Все content, posters, videos и manifest включены в app target resources и доступны в Airplane Mode после clean install.
- Manifest validation проверяет уникальные ids/file names, соответствие 10 starter ids, существование файлов, допустимые dimensions/fps/duration/size и SHA-256.
- MP4/JPG считаются untrusted build inputs: decode probe выполняется до handoff; приложение не выполняет shell/script из assets и не читает embedded external links.
- В release UI checksum пользователю не показывается и никакие PII не логируются.

### 10.2 Rights

Для каждого asset разрешён только один provenance class: `original_in_house` (обязательный для этой задачи). Это означает:

- source/master создан командой для ABS Trainer с нуля;
- не trace/copy существующей чужой анимации, персонажа, логотипа или платного template;
- reference может использоваться для понимания структуры движения, но не поставляется в repo и не переносит охраняемые visual элементы;
- procedural models/fonts/materials также должны быть собственными либо системными с правом распространения; все inputs перечислены в source notes;
- license declaration для export: `owned_original_work`; автор/создатель и дата фиксируются без персональных контактов/PII;
- third-party/unknown/copyleft stock asset не проходит acceptance без отдельного human legal approval — такого approval эта задача не предполагает.

## 11. Asset layout и naming

Рекомендуемый developer handoff layout (создаёт designer; iOS может адаптировать Xcode group, не меняя имён):

```text
design/exercise-library/
  source/                         # inspectable editable masters
  previews/contact-sheet.png
  previews/all-exercises-preview.mp4
  manifest/exercise-assets.json
  exports/
    exercise_crunch_v1.mp4
    exercise_crunch_poster_v1.jpg
    ... 10 pairs total ...
```

Runtime bundle target:

```text
ios/AbsTrainer/Resources/ExerciseMedia/
  exercise_<id>_v1.mp4
  exercise_<id>_poster_v1.jpg
  exercise-assets.json
```

`mediaName` final mapping: `exercise_<id>_v1` без extension. Все 10 `Exercise.isPlaceholderMedia` переключаются в `false` только в iOS implementation после добавления/валидации ресурсов. Этот документ production code не меняет.

## 12. Asset manifest schema

Canonical encoding: UTF-8 JSON, sorted by `exercise_id`, paths repository-relative, integer byte sizes, lowercase hex SHA-256. Manifest не содержит credentials, user PII или external tracking URLs.

```json
{
  "schema_version": 1,
  "catalog": "ExerciseCatalog.starter",
  "export_profile": "abs-exercise-square-h264-v1",
  "generated_at": "ISO-8601 UTC",
  "assets": [
    {
      "exercise_id": "crunch",
      "catalog_media_name": "exercise_crunch_v1",
      "video": {
        "path": "design/exercise-library/exports/exercise_crunch_v1.mp4",
        "container": "mp4",
        "codec": "h264",
        "pixel_format": "yuv420p",
        "width_px": 720,
        "height_px": 720,
        "fps": 30,
        "duration_ms": 4000,
        "frame_count": 120,
        "has_audio": false,
        "loop": "seamless",
        "size_bytes": 0,
        "sha256": "64 lowercase hex chars"
      },
      "poster": {
        "path": "design/exercise-library/exports/exercise_crunch_poster_v1.jpg",
        "width_px": 720,
        "height_px": 720,
        "color_space": "sRGB",
        "size_bytes": 0,
        "sha256": "64 lowercase hex chars"
      },
      "source": {
        "master_path": "design/exercise-library/source/<inspectable-source>",
        "creator_role": "designer",
        "provenance": "original_in_house",
        "license": "owned_original_work",
        "third_party_inputs": [],
        "source_notes": "Original neutral figure, camera and movement storyboard reference."
      },
      "qa": {
        "opens": true,
        "visual_review": "pass",
        "seam_review": "pass",
        "storyboard_review": "pass",
        "reduce_motion_poster_review": "pass"
      }
    }
  ]
}
```

Schema invariants:

- `assets.count == 10` и ids равны множеству ids `ExerciseCatalog.starter`;
- одна запись на id; никаких extra/duplicate ids;
- `catalog_media_name == "exercise_" + exercise_id + "_v1"`;
- все paths существуют, открываются и остаются внутри repo;
- measured technical values, sizes и checksums заполняются командами, не вручную «на глаз»;
- `third_party_inputs` пуст для 10 final assets; иначе acceptance fail до отдельного approval;
- `qa.*` нельзя ставить `pass/true` без соответствующей проверки.

## 13. Acceptance matrix

| ID | Критерий | Evidence / проверка | Gate |
|---|---|---|---|
| AC-01 | Отдельный flow Setup → Library → Detail определён; Back сохраняет Setup | Design annotations + prototype walkthrough против §3 | Design |
| AC-02 | Library имеет search, zone/difficulty filters, count, reset | Screens default/filtered/no-results + interaction spec | Design |
| AC-03 | Empty/loading/video fallback не симулируют network и не crash | State screens + iOS tests later | Design/iOS |
| AC-04 | Detail содержит metadata, 3 phases, 2 cues, disclaimer для 10/10 | Content matrix §5 + 10 detail variants | Design |
| AC-05 | 10/10 original videos и posters существуют и открываются | Manifest set equality; `ffprobe`; image decode | Designer |
| AC-06 | Каждый video соответствует 720²/H.264/yuv420p/30fps/4s/no audio | measured manifest + automated validator | Designer |
| AC-07 | Каждый loop визуально seamless и соответствует своему storyboard | per-id seam/storyboard review + all-preview MP4 | Designer/human |
| AC-08 | Reduce Motion сохраняет весь смысл без autoplay | AX annotation + 10 posters + text phases | Design/iOS |
| AC-09 | Assets только original in-house, без чужих marks/characters | source files + provenance/license/inputs manifest | Designer/human |
| AC-10 | Total/per-file size в budget | measured `size_bytes`, summed validator output | Designer |
| AC-11 | Offline: no URLs/backend; все runtime resources bundled | Xcode resource inspection + Airplane Mode manual test | iOS/QA |
| AC-12 | VoiceOver, Dynamic Type AX3, compact/landscape rules определены | annotated screens and later device matrix | Design/iOS/QA |
| AC-13 | Существующие ids/zones/durations/rest/access остаются source truth | manifest/catalog validator + model tests | iOS |
| AC-14 | Production code не изменён этой аналитической задачей | `git diff -- docs/exercise-library-product-motion-contract.md` и `git status` | Analyst |

### 13.1 Suggested designer verification commands

Команды являются acceptance expectation, а не утверждением, что assets уже созданы:

```text
ffprobe -v error -show_entries stream=codec_name,pix_fmt,width,height,r_frame_rate,nb_frames:format=duration,size -of json <video>
sha256sum <video> <poster>
```

Дополнительно validator должен:

- сравнить ids manifest с ids catalog;
- проверить 10 videos + 10 posters;
- декодировать хотя бы первый и последний кадр каждого video и каждый poster;
- вычислить total bytes;
- проверить отсутствие audio stream;
- вывести per-id PASS/FAIL и ненулевой exit code при нарушении.

## 14. Решения и отклонённые альтернативы

Принято:

- secondary entry из Setup вместо новой tab bar — минимальный IA change и сохранение текущего critical flow;
- read-only detail без Start/Add — не вводит неописанную генераторную семантику;
- square 720×720 H.264 MP4 + JPG poster — простой iOS 16 offline playback и предсказуемый app-size;
- posters в Library, один video только в Detail — контролируемые memory/CPU;
- `.full` filter означает exact `.full`, а `Все зоны` снимает filter;
- original in-house assets only;
- Reduce Motion = poster-first/no autoplay;
- тексты техники нейтральны и остаются полезны без motion.

Отклонено:

- 10 autoplay videos в list — performance/accessibility cost;
- GIF как runtime media — хуже размер/контроль playback/accessibility;
- HEVC-only — менее прозрачная tooling/compatibility граница для MVP;
- remote/CDN media — нарушает offline/no-backend scope;
- medical/safety claims — не подтверждены и не входят в продукт;
- premium locks — starter catalog фактически `.free`;
- копирование пользовательского/чужого референса — допустима только структурная идея, не assets/branding;
- изменение `Exercise` в этой задаче — production code запрещён; data implementation передаётся iOS.

## 15. Risks и mitigation

| Риск | Влияние | Mitigation / owner |
|---|---|---|
| Техника движения визуально двусмысленна | пользователь повторяет не ту фазу | storyboard gate + contact sheet/all-preview + human domain review; designer |
| Нейтральный copy воспринимается как персональная инструкция | ложное ожидание безопасности | общий disclaimer, comfortable-range language, no guarantees; analyst/designer |
| MP4 loop имеет seam/black flash | низкое качество | exact start/end pose, poster-first, seam review; designer |
| 10 media раздувают app | install/build overhead | hard per-file/total budgets, measured manifest; designer/iOS |
| iOS resources не соответствуют manifest | fallback или broken detail | build-time validator, set equality, SHA-256; iOS |
| Reduce Motion реализован только визуально | autoplay остаётся | environment-driven behavior + QA device setting; iOS/QA |
| Existing model не хранит phases/cues/poster | implementation ambiguity | локальный typed content manifest или отдельная model extension; решение за iOS в рамках этого schema |
| Нет advanced items | пустой filter/ложное ожидание | скрыть/disable zero-count option; designer |
| Provenance недостаточно доказуема | legal/release blocker | inspectable source, empty third-party inputs, owned declaration; designer/human approval |
| Контент не проходил медицинскую экспертизу | нельзя обещать therapeutic safety | явно не позиционировать как medical guidance; release owner решает, нужна ли экспертная проверка |

## 16. Handoff следующему designer

### Result

Зафиксирован implementation-ready продуктовый/content/motion contract отдельного Exercises flow для фактических 10 `ExerciseCatalog.starter` без изменения production code.

### Artifact

`docs/exercise-library-product-motion-contract.md`

### Decisions

Следовать §14: secondary Setup entry, read-only detail, local search/filters, 720² H.264 loops, JPG posters, original in-house provenance, poster-only Library и Reduce Motion без autoplay.

### Contract

Designer может полагаться на:

- ids/metadata §5 как immutable source mapping;
- IA/states §§3–4;
- exact detail content §5;
- visual/export/loop profile §§6–8;
- responsive/accessibility §9;
- paths/manifest schema §§11–12;
- acceptance gates §13.

### Verification expected from designer

- polished source + exports;
- default/filtered/no-results/empty/fallback/detail and compact/AX3/landscape annotations;
- 10 MP4 + 10 JPG, contact sheet/all-preview;
- measured manifest and validator output;
- per-id storyboard/seam/provenance review.

### Risks

Human anatomical/content and provenance review remain explicit gates; this analyst contract does not claim medical certification or final release approval.

### Next role

`designer`, task `t_f1d72cf8`: deliver inspectable high-fidelity screens and 10/10 original validated motion assets. Completion requires every AC-01…AC-12 design/designer gate to have inspectable evidence before handoff to the existing downstream `ios` task.

## 17. Standards applied

- `/home/hermes/.hermes/team-agent-os/standards/delivery/task-lifecycle.md`
- `/home/hermes/.hermes/team-agent-os/standards/delivery/handoff.md`
- `/home/hermes/.hermes/team-agent-os/standards/engineering/security.md`
