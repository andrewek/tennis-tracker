## 1. Navbar

- [x] 1.1 In `layouts.ex`, replace the navbar left side: remove the Phoenix logo/version link and replace with a "Tennis Tracker" text link to `/`
- [x] 1.2 Remove all external links (Website, GitHub, Get Started) from the navbar right side
- [x] 1.3 Add a "Players" nav link (btn-ghost style) to the navbar right side pointing to `/players`
- [x] 1.4 Verify the theme toggle remains in the navbar

## 2. Age Bracket Chip Component

- [x] 2.1 Add an `age_bracket_chips/1` function component in `core_components.ex` that accepts a `player` assign and renders `badge badge-sm` chips for each eligible bracket (18+, 40+, 55+)

## 3. Players Index Page

- [x] 3.1 In `PlayerFilters.fetch_players/3`, add `Ash.Query.sort(ntrp_rating: :asc, name: :asc)` to the query
- [x] 3.2 In `index_live.ex`, remove the three age-bracket columns ("18+ Eligible?", "40+ Eligible?", "55+ Eligible?") from the `<.table>`
- [x] 3.3 In the Name column, render the player name link followed by `<.age_bracket_chips player={player} />`

## 4. Player Show Page

- [x] 4.1 In `show_live.ex`, add a hero section above `<.list>` containing an `<h1>` with the player's name and a prominent NTRP rating display
- [x] 4.2 Below the name/NTRP in the hero section, add `<.age_bracket_chips player={@player} />` for the sub-header chips
- [x] 4.3 Remove "NTRP Rating", "18+ Eligible?", "40+ Eligible?", and "55+ Eligible?" items from the `<.list>` (they are now in the hero section); keep Email and Phone

## 5. Home Page

- [x] 5.1 Replace the contents of `home.html.heex` with a new layout: retain an abstract SVG background (restyled from the current one) and add a centered card grid
- [x] 5.2 Add three cards to the grid: "Players" (href `/players`), "Teams" (href `#`), "Winter Tennis" (href `#`), each with a label, brief description, and icon or visual element
- [x] 5.3 Apply hover effects to each card (e.g., `group-hover:scale-105` on the background span, matching the existing Phoenix card pattern)
- [x] 5.4 Ensure the SVG background and card colors work in both light and dark mode (use daisyUI `base-*` color tokens or `opacity` modifiers)
- [x] 5.5 Make the card grid responsive: 1 column on mobile, 3 columns on `sm:` and above

## 6. Verification

- [x] 6.1 Run `mix precommit` (compile + format + tests) and fix any errors
- [x] 6.2 Manually verify navbar on players index, player show, and home page
- [x] 6.3 Manually verify chip rendering for a player with brackets, and one without
- [x] 6.4 Manually verify default sort order on the players index
- [x] 6.5 Manually verify home page cards and hover effect in both light and dark mode
