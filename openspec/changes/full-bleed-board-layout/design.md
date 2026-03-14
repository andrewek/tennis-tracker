## Context

The app uses a single `Layouts.app` component for all pages. It renders a navbar and a `<main>` with `py-20` (80px top/bottom padding) — a Phoenix generator default suited for content pages but excessive for a board tool. The roster planner board uses a horizontal flex row of columns with no height constraint, so tall columns push the page long and require full-page vertical scroll.

The board already has `fluid={true}` passed to remove the max-width constraint. This change adds a second layout variant — `Layouts.full_bleed` — for pages that also need to fill the viewport height.

## Goals / Non-Goals

**Goals:**
- Reduce vertical spacing between navbar and page content across all pages
- Provide a layout that fills the viewport height for board-style pages
- Make each board column independently scrollable within a fixed board height
- No JS changes — pure CSS flexbox approach

**Non-Goals:**
- Auto-scroll when dragging near the top/bottom of a column
- Mobile layout changes (tap-to-assign flow stays as-is; mobile scrolls normally)
- Changing any other LiveView pages to use `full_bleed`

## Decisions

**Use `h-dvh` over `h-screen` / `100vh`**
`dvh` (dynamic viewport height) accounts for mobile browser chrome (address bar appearing/disappearing). More correct than `vh` on mobile, same on desktop.

**Wrap in a flex column div inside `full_bleed`, not on `<body>`**
Modifying `<body>` in root.html.heex would affect all pages. Instead `full_bleed` wraps its output in a `div.h-dvh.flex.flex-col` that contains the navbar and main. This keeps the change self-contained.

**`min-h-0` on flex children**
CSS flex children have `min-height: auto` by default, which prevents them from shrinking below their content height. Every element in the height chain needs `min-h-0` to participate in the fixed-height layout.

**Column player zone: `flex-1 overflow-y-auto`**
The column becomes `flex flex-col`. The header and violation banners are `flex-shrink-0`; the player drop zone is `flex-1 overflow-y-auto`, so it fills remaining column height and scrolls internally.

**Compact inline title in roster planner**
The `<.header>` component (large page title) is replaced by a compact single-line bar (title + toolbar) that is `flex-shrink-0`, keeping the board columns as large as possible.

## Risks / Trade-offs

- **Drop zone clipping**: When a column is scrolled, cards below the fold are not visible during a drag. Users must scroll the column before dropping onto a hidden card. Acceptable given the tap-to-assign mobile preference; drag-and-drop is desktop-only.
- **`py-20` → `py-6` is a global change**: All pages get less top/bottom whitespace. This is the intent, but any page that relied on the padding for visual breathing room should be reviewed.

## Migration Plan

No database or API changes. Changes are purely to layout templates and a shared component. Deploy is atomic — no phased rollout needed.
