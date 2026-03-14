# Tennis Tracker

Tennis Tracker is meant to make life easier for me and a few of the other USTA
league captains I coordinate with. In theory, it replaces a whole slew of
home-brewed spreadsheets and overly lengthy text-chains.

This project has the following broad use cases:

- Plan USTA rosters (or other team rosters), especially in a scenario where you
  are splitting players into many teams
- Manage your broad roster of players, including things like exporting to CSV,
  keeping contact info up to date, seeing which team(s) a player is on now or has
  been on in the past, etc.
- Manage formal USTA league schedules (availability, lineups, etc.) with some
  convenience tools for captains and players
- Manage informal league schedules (availability, off-weeks, sub rosters, etc.)
  with some convenience tools for organizers and players

Right now it does not track match results or keep any sort of player stats.
There is no current mechanism for tracking things like court fees, dues, or
other financials. There is no current ability for managing communications.

## Setup

Install dependencies with `asdf install` (or check `.tool-versions` for
recommended versions of tools). You'll also need Postgres 16+ installed and
running on port 5432.

To start your Phoenix server:

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix
  phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Dev Users

Running `mix run priv/repo/seeds.exs` (or `mix setup`) creates two local dev accounts:

| Email | Password | Role |
|---|---|---|
| `admin@example.com` | `Password1!` | admin |
| `user@example.com` | `Password1!` | member |

The admin panel is at [`localhost:4000/admin`](http://localhost:4000/admin) — requires an account with the `:admin` role.

To promote an existing user to admin via IEx:

```elixir
iex -S mix

user = Ash.get!(TennisTracker.Accounts.User, "user-uuid-here", domain: TennisTracker.Accounts, authorize?: false)
Ash.update!(user, %{role: :admin}, action: :update_role, domain: TennisTracker.Accounts, authorize?: false)
```

Or directly in the database:

```sql
UPDATE users SET role = 'admin' WHERE email = 'user@example.com';
```

## Development

I'm currently using OpenSpec to design things, and then implementing as built.
Check the OpenSpec folder for more.

The whole thing uses the Ash framework as a business layer DSL, and for the
moment, LiveView on the front-end with Phoenix default tooling (Tailwind, JS
Hooks).

## AI Disclosure

I'm building a whole lot of this by providing what are basically PRDs to Claude
(via OpenSpec), and letting Claude do most of the implementation. All code
still gets reviewed and edited by hand. 

I recognize that there are _many_ strong reasons to be very concerned by the
role of LLMs and AI in society, and also I am doing it this way as a low-stakes
way to really push my own processes. I still share most of those concerns.

## What if I want to use this for myself?

Go for it. I make no promises nor guarantees about the codebase, whether in
terms of stability of the code, support for features, ability to help debug, or
anything else. You can just go ahead and use the code as you see fit, entirely
at your own risk.

## I have a feature request!

No.


## I have a feature request AND we play tennis together!

Maybe. The answer is still probably no.
