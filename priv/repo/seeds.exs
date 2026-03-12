# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Safe to run multiple times — skips players that already exist by name.

alias TennisTracker.Tennis

# NTRP distribution approximating a normal curve centered between 3.5 and 4.0:
#   2.5 →  5 players
#   3.0 → 15 players
#   3.5 → 30 players
#   4.0 → 30 players
#   4.5 → 15 players
#   5.0 →  5 players
ntrp_pool =
  List.flatten([
    List.duplicate("2.5", 5),
    List.duplicate("3.0", 15),
    List.duplicate("3.5", 30),
    List.duplicate("4.0", 30),
    List.duplicate("4.5", 15),
    List.duplicate("5.0", 5)
  ])

# 100 real tennis player names (mix of eras and tours)
names = [
  "Novak Djokovic",
  "Rafael Nadal",
  "Roger Federer",
  "Andy Murray",
  "Stan Wawrinka",
  "Dominic Thiem",
  "Alexander Zverev",
  "Daniil Medvedev",
  "Stefanos Tsitsipas",
  "Carlos Alcaraz",
  "Jannik Sinner",
  "Casper Ruud",
  "Hubert Hurkacz",
  "Matteo Berrettini",
  "Andrey Rublev",
  "Taylor Fritz",
  "Tommy Paul",
  "Frances Tiafoe",
  "Felix Auger-Aliassime",
  "Denis Shapovalov",
  "Grigor Dimitrov",
  "Roberto Bautista Agut",
  "Karen Khachanov",
  "Marin Cilic",
  "David Goffin",
  "John Isner",
  "Reilly Opelka",
  "Sebastian Korda",
  "Ben Shelton",
  "Alejandro Davidovich Fokina",
  "Nicolas Jarry",
  "Tommy Robredo",
  "Feliciano Lopez",
  "Fernando Verdasco",
  "David Ferrer",
  "Nicolas Almagro",
  "Albert Ramos-Vinolas",
  "Pablo Cuevas",
  "Richard Gasquet",
  "Gael Monfils",
  "Jo-Wilfried Tsonga",
  "Gilles Simon",
  "Jeremy Chardy",
  "Benoit Paire",
  "Nicolas Mahut",
  "Lucas Pouille",
  "Julien Benneteau",
  "Tomas Berdych",
  "Jiri Novak",
  "Radek Stepanek",
  "Ivan Lendl",
  "Stefan Edberg",
  "Boris Becker",
  "Pete Sampras",
  "Andre Agassi",
  "Michael Chang",
  "Jim Courier",
  "Thomas Muster",
  "Goran Ivanisevic",
  "Patrick Rafter",
  "Todd Martin",
  "Michael Stich",
  "Jimmy Connors",
  "John McEnroe",
  "Bjorn Borg",
  "Guillermo Vilas",
  "Vitas Gerulaitis",
  "Brian Gottfried",
  "Roscoe Tanner",
  "Harold Solomon",
  "Eddie Dibbs",
  "Marty Riessen",
  "Bob Lutz",
  "Stan Smith",
  "Arthur Ashe",
  "Ken Rosewall",
  "Rod Laver",
  "John Newcombe",
  "Tony Roche",
  "Fred Stolle",
  "Roy Emerson",
  "Lew Hoad",
  "Neale Fraser",
  "Ashley Cooper",
  "Mal Anderson",
  "Frank Sedgman",
  "Vic Seixas",
  "Jaroslav Drobny",
  "Jack Kramer",
  "Ted Schroeder",
  "Gardnar Mulloy",
  "Frank Parker",
  "Don Budge",
  "Ellsworth Vines",
  "Henri Cochet",
  "Jean Borotra",
  "Rene Lacoste",
  "Jacques Brugnon",
  "Bill Tilden",
  "Bill Johnston",
  "Gerald Patterson"
]

# Eligibility logic:
#
# Players are indexed 0–99. We assign eligibility as follows:
#   - 40+ eligible:  indices 0–66  (67 players ≈ 2/3)
#   - 55+ eligible:  indices 0–16  (17 players ≈ 1/4 of 40+)
#   - 18+ NOT eligible: indices 0–3 (4 players, all are 55+ eligible)
#
# This gives:
#   - 96 players with eligible_18_plus = true
#   -  4 players with eligible_18_plus = false (seniors who play 40+/55+ only)
#   - 67 players with eligible_40_plus = true
#   - 17 players with eligible_55_plus = true

existing_names =
  Tennis.list_players!()
  |> Enum.map(& &1.name)
  |> MapSet.new()

names
|> Enum.zip(ntrp_pool)
|> Enum.with_index()
|> Enum.reject(fn {{name, _ntrp}, _i} -> MapSet.member?(existing_names, name) end)
|> Enum.each(fn {{name, ntrp}, i} ->
  eligible_40_plus = i <= 66
  eligible_55_plus = i <= 16
  eligible_18_plus = i > 3

  {:ok, _} =
    Tennis.create_player(%{
      name: name,
      ntrp_rating: ntrp,
      eligible_18_plus: eligible_18_plus,
      eligible_40_plus: eligible_40_plus,
      eligible_55_plus: eligible_55_plus
    })
end)

IO.puts("Seeded #{length(names)} players (skipped any already present).")

# Players without NTRP ratings
unrated_players = [
  %{
    name: "Alex Rivera",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Jordan Casey",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{name: "Morgan Ellis", eligible_18_plus: true, eligible_40_plus: true, eligible_55_plus: true},
  %{
    name: "Taylor Quinn",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  }
]

unrated_players
|> Enum.reject(fn %{name: name} -> MapSet.member?(existing_names, name) end)
|> Enum.each(fn attrs ->
  {:ok, _} = Tennis.create_player(Map.put(attrs, :ntrp_rating, nil))
end)

IO.puts("Seeded #{length(unrated_players)} unrated players (skipped any already present).")

# ==============================================================================
# TeamTypes — 2 age groups × 4 NTRP levels = 8 types
# Safe to run multiple times — skips types that already exist by name.
# ==============================================================================

team_type_definitions = [
  %{
    age_group: "18_plus",
    ntrp_level: Decimal.new("3.0"),
    allowed_ntrp_levels: [Decimal.new("3.0")],
    name: "18+ 3.0"
  },
  %{
    age_group: "18_plus",
    ntrp_level: Decimal.new("3.5"),
    allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")],
    name: "18+ 3.5"
  },
  %{
    age_group: "18_plus",
    ntrp_level: Decimal.new("4.0"),
    allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")],
    name: "18+ 4.0"
  },
  %{
    age_group: "18_plus",
    ntrp_level: Decimal.new("4.5"),
    allowed_ntrp_levels: [Decimal.new("4.0"), Decimal.new("4.5")],
    name: "18+ 4.5"
  },
  %{
    age_group: "40_plus",
    ntrp_level: Decimal.new("3.0"),
    allowed_ntrp_levels: [Decimal.new("3.0")],
    name: "40+ 3.0"
  },
  %{
    age_group: "40_plus",
    ntrp_level: Decimal.new("3.5"),
    allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")],
    name: "40+ 3.5"
  },
  %{
    age_group: "40_plus",
    ntrp_level: Decimal.new("4.0"),
    allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")],
    name: "40+ 4.0"
  },
  %{
    age_group: "40_plus",
    ntrp_level: Decimal.new("4.5"),
    allowed_ntrp_levels: [Decimal.new("4.0"), Decimal.new("4.5")],
    name: "40+ 4.5"
  }
]

existing_team_type_names =
  Tennis.list_team_types!()
  |> Enum.map(& &1.name)
  |> MapSet.new()

seeded_team_types =
  team_type_definitions
  |> Enum.reject(fn %{name: name} -> MapSet.member?(existing_team_type_names, name) end)
  |> Enum.map(fn attrs ->
    {:ok, tt} = Tennis.create_team_type(attrs)
    tt
  end)

# Build a map of team type name → record for SeasonRules seeding
all_team_types = Tennis.list_team_types!()
team_types_by_name = Map.new(all_team_types, &{&1.name, &1})

IO.puts("Seeded #{length(seeded_team_types)} team types (skipped any already present).")

# ==============================================================================
# SeasonRules for season 2026 — reasonable USTA defaults
# Safe to run multiple times — skips rules that already exist.
# ==============================================================================

season_rules_2026 = [
  %{name: "18+ 3.0", min_roster: 8, max_roster: 18, on_level_min_pct: Decimal.new("0.60")},
  %{name: "18+ 3.5", min_roster: 10, max_roster: 18, on_level_min_pct: Decimal.new("0.60")},
  %{name: "18+ 4.0", min_roster: 10, max_roster: 18, on_level_min_pct: Decimal.new("0.60")},
  %{name: "18+ 4.5", min_roster: 10, max_roster: 18, on_level_min_pct: Decimal.new("0.60")},
  %{name: "40+ 3.0", min_roster: 8, max_roster: 15, on_level_min_pct: Decimal.new("0.60")},
  %{name: "40+ 3.5", min_roster: 8, max_roster: 15, on_level_min_pct: Decimal.new("0.60")},
  %{name: "40+ 4.0", min_roster: 8, max_roster: 15, on_level_min_pct: Decimal.new("0.60")},
  %{name: "40+ 4.5", min_roster: 8, max_roster: 15, on_level_min_pct: Decimal.new("0.60")}
]

require Ash.Query

existing_2026_type_ids =
  TennisTracker.Tennis.SeasonRules
  |> Ash.Query.filter(season_year == 2026)
  |> Ash.read!(domain: Tennis)
  |> Enum.map(& &1.team_type_id)
  |> MapSet.new()

seeded_rules =
  season_rules_2026
  |> Enum.reject(fn %{name: name} ->
    team_type = Map.get(team_types_by_name, name)
    team_type && MapSet.member?(existing_2026_type_ids, team_type.id)
  end)
  |> Enum.each(fn %{name: name} = attrs ->
    team_type = Map.fetch!(team_types_by_name, name)

    {:ok, _} =
      Tennis.create_season_rules(%{
        team_type_id: team_type.id,
        season_year: 2026,
        min_roster: attrs.min_roster,
        max_roster: attrs.max_roster,
        on_level_min_pct: attrs.on_level_min_pct
      })
  end)

IO.puts("Seeded SeasonRules for 2026 (skipped any already present).")

# ==============================================================================
# Dev users — admin@example.com and user@example.com
# Safe to run multiple times — skips users that already exist by email.
# ==============================================================================

alias TennisTracker.Accounts

require Ash.Query

dev_users = [
  %{email: "admin@example.com", password: "Password1!"},
  %{email: "user@example.com", password: "Password1!"}
]

existing_emails =
  TennisTracker.Accounts.User
  |> Ash.Query.new()
  |> Ash.read!(domain: Accounts, authorize?: false)
  |> Enum.map(&to_string(&1.email))
  |> MapSet.new()

Enum.each(dev_users, fn %{email: email, password: password} ->
  unless MapSet.member?(existing_emails, email) do
    {:ok, _} =
      Ash.create(
        TennisTracker.Accounts.User,
        %{email: email, password: password, password_confirmation: password},
        action: :register_with_password,
        domain: Accounts,
        authorize?: false
      )
  end
end)

IO.puts("Seeded dev users (skipped any already present).")
