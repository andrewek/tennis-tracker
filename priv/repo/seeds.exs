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
