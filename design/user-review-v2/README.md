# ABS Trainer — user review v2

Статус: **high-fidelity design-only approval checkpoint**. Production SwiftUI не изменялся.

## 1. Цель и выбранное направление

Пользователь — человек, который выполняет короткую домашнюю тренировку и смотрит на экран с расстояния или в движении. Главная задача — быстро настроить поддерживаемую тренировку, затем безошибочно различать упражнение, отдых, завершение и безопасный выход.

Поверхность Setup — **Configure**, Active/Rest — **Monitor**, Finish — **Decide/Recover**. Сохранено утверждённое направление «Темп / Срез»: Chalk/Carbon, Vermilion для темпа/действия, Ultramarine для отдыха, плоские поверхности, одна primary CTA, линейная ритмика и большие display-таймеры.

Референс setup использован только как общий IA-паттерн `параметры → длительность → CTA`. Не скопированы AI-branding, bottom navigation, цвета, анатомическая иллюстрация и чужие visual motifs. В доменной модели есть зоны пресса, но нет intensity; поэтому экран показывает реальные `5/10/15 минут` и zone choices, а intensity не выдумана.

## 2. Рассмотренные направления

1. **Conservative — approved Tempo/Cut + прежние segmented cells.** Низкий риск, но не использует утверждённый duration dial.
2. **Strong-fit — Configure flow + 270° dial + zone grid.** Выбрано: сохраняет продуктовый словарь, честную модель и структуру референса без копирования.
3. **Divergent — центральная анатомическая focus-map.** Отклонено: добавляет декоративную иллюстрацию и создаёт ложное ожидание точного muscle-area targeting.

## 3. Артефакты

- `01-setup.png` — Setup/Home с 270° duration dial, `−/+`, зонами и одной CTA.
- `02-active.png` — Active с timer/context на общей midY и читаемым inverse pause.
- `03-rest.png` — Rest с явными inverse semantic roles и high-contrast next-up/skip.
- `04-finish.png` — Finish с общей осью primary/secondary и balanced trailing repeat icon.
- `05-confirmation.png` — тематический destructive confirmation modal.
- `contact-sheet.png` — целостный обзор пяти состояний и аннотации compact/AX3.
- `index.html` — локальная галерея для полноразмерного просмотра.
- `render.py` — детерминированный design-only renderer.

PNG имеют `880×1912 px` (логический iPhone 17 Pro Max canvas `440×956 pt`, экспорт 2×).

## 4. System contract

### Tokens

- `surface.canvas = #F5F1E8` (Chalk)
- `surface.active / text.primary = #171714` (Carbon)
- `surface.rest = #2946C6` (Ultramarine)
- `action.player = #D13A25` (Vermilion)
- `action.destructive = #B74731` (Signal)
- `text.secondary = #55534D`
- `text.inverse = #FFFFFF`; inverse secondary 72%; decorative inverse divider 30%; interactive outline 50%.
- Spacing: `4, 8, 12, 16, 20, 24, 32, 40, 56`; outer inset 20/22 pt; action radius 20; media/modal radius 28.

### Corrected user findings

- **Active:** timer/context are one group with aligned visual centers; horizontal fallback changes to vertical at compact/AX3. Pause symbol is explicit White, outline ≥3:1, target 58 pt.
- **Rest:** H1, countdown, next exercise, duration and skip are explicit White; secondary text is 72% White; interactive border is 50% White.
- **Finish:** primary/secondary edges and labels share one center axis. Repeat icon occupies an independent trailing slot and cannot shift the label.
- **Confirmation:** opaque Chalk card replaces system material. Safe default precedes outlined destructive action; outside tap does nothing; background is noninteractive and hidden from accessibility while modal is open.

## 5. Compact, AX3, native and accessibility annotations

- **320×700 / compact height:** roots remain scrollable; media may reduce to 230 pt; timer/context, next title/duration and results switch to vertical stacks; bottom actions remain in `safeAreaInset`; tap targets never shrink below 44 pt.
- **AX3 portrait:** text gets intrinsic height and wraps; central dial stays bounded; essential copy cannot truncate; modal body scrolls before its actions clip; finish results stack vertically.
- **AX3 landscape:** decorative media/ring may shrink or hide only if necessary; H1, timers, next-up, results and actions remain reachable. No horizontal scrolling.
- **VoiceOver order:** Setup heading → dial → `−/+` → zones → CTA; Active exit → progress → exercise/media → combined countdown → pause → next; Rest state → countdown → combined next-up → skip; Confirmation title → body → safe → destructive; Finish title → results → repeat → new.
- **Motion:** Reduce Motion uses opacity-only ≤120 ms. Countdown announcements are sparse: 10/5/3/2/1 and state changes.
- **Contrast:** approved pairs are White/Carbon 17.96:1, White/Ultramarine 7.54:1, White/Vermilion 4.84:1, Signal/Chalk 4.71:1. State is never communicated by color alone.

## 6. Quality gate

Visual QA run against all five rendered PNG and the contact sheet.

| Dimension | Score |
|---|---:|
| Task clarity / IA | 20/20 |
| Hierarchy / composition | 14/15 |
| Typography / content | 9/10 |
| Design-system consistency | 15/15 |
| Interaction states / feedback | 9/10 |
| Native adaptation | 9/10 |
| Accessibility | 14/15 |
| Distinctiveness | 4/5 |
| **Total** | **94/100** |

No P0/P1 visual issue remains in the design artifacts. Residual limitations: static PNG cannot prove real Dynamic Type reflow, VoiceOver cursor/focus return, touch hit geometry or simulator safe-area behavior. Those remain implementation/QA gates.

Slop diagnostic: **0/10** after review. No tech gradient, generic indigo, feature tiles, accent rails, blur, monument metrics, icon toppers, generic center-stack, default web type, or wrong-surface composition.

## 7. Handoff and blocker

Figma destination/credentials are not configured for this repository task, so repository PNG + HTML + renderer are the inspectable source for approval. Before production design lock, the approved frames/components should be transferred to the team Figma destination. Next role after user approval: iOS implementation parity followed by independent screenshot, compact, AX3, VoiceOver and Increase Contrast QA.
