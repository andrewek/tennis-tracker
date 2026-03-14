## 1. Global Layout Spacing

- [ ] 1.1 In `Layouts.app`, change `py-20` to `py-6` on the `<main>` element

## 2. Full-Bleed Layout Component

- [ ] 2.1 Add `Layouts.full_bleed` to `layouts.ex` — wraps content in `div.h-dvh.flex.flex-col`, same navbar as `Layouts.app`, `<main class="flex-1 min-h-0 overflow-hidden">` with no padding
- [ ] 2.2 Add `attr` declarations to `full_bleed/1` matching `Layouts.app` (flash, current_user, inner_block)

## 3. Board Column Internal Scrolling

- [ ] 3.1 In `board_components.ex`, update `board_column` outer div to add `flex flex-col` (keep existing classes)
- [ ] 3.2 Change the player drop zone div from `space-y-1 min-h-8` to `flex-1 overflow-y-auto min-h-0 space-y-1`

## 4. Roster Planner Board Layout

- [ ] 4.1 Switch `<Layouts.app>` to `<Layouts.full_bleed>` in `roster_planner_live.ex`
- [ ] 4.2 Replace `<.header>` with a compact single-line title bar (`flex items-center gap-4 py-3 px-4 flex-shrink-0`)
- [ ] 4.3 Update the board wrapper div from `mt-4` to `h-full flex flex-col`
- [ ] 4.4 Update the board toolbar div to include `flex-shrink-0`
- [ ] 4.5 Update the columns container from `flex gap-3 overflow-x-auto pb-4 items-start` to `flex-1 min-h-0 flex gap-3 overflow-x-auto pb-4 px-4 items-stretch`
