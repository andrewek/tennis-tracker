defmodule TennisTracker.Tennis.PlayerFilters do
  @moduledoc """
  Shared query filter logic for players. Used by both the players index LiveView
  and the CSV export controller so filtering behaviour stays in sync.
  """

  require Ash.Query

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.Player

  @doc """
  Fetch players matching the given filter params, ordered by NTRP then name ascending.

  Params:
    - `name_search` – partial, case-insensitive name match (empty string = no filter)
    - `ntrp_filter` – list of NTRP rating strings, e.g. `["3.5", "4.0"]`; use `"none"` to include unrated players
    - `bracket_filter` – list of age bracket strings: `"18"`, `"40"`, `"55"`
    - `ntrp_sort` – `:asc_nils_first` or `:desc_nils_last` (default `:desc_nils_last`)

  Options (keyword list):
    - `tenant:` – required group_id for multitenancy
    - `actor:` – required actor for authorization
  """
  def fetch_players(name_search, ntrp_filter, bracket_filter, opts_or_sort \\ :desc_nils_last)

  def fetch_players(name_search, ntrp_filter, bracket_filter, opts) when is_list(opts) do
    ntrp_sort = Keyword.get(opts, :ntrp_sort, :desc_nils_last)
    ash_opts = Keyword.take(opts, [:tenant, :actor])

    Player
    |> maybe_filter_name(name_search)
    |> maybe_filter_ntrp(ntrp_filter)
    |> maybe_filter_bracket(bracket_filter)
    |> Ash.Query.sort(ntrp_rating: ntrp_sort, name: :asc)
    |> Ash.read!(Keyword.merge([domain: Tennis], ash_opts))
  end

  def fetch_players(name_search, ntrp_filter, bracket_filter, ntrp_sort)
      when is_atom(ntrp_sort) do
    Player
    |> maybe_filter_name(name_search)
    |> maybe_filter_ntrp(ntrp_filter)
    |> maybe_filter_bracket(bracket_filter)
    |> Ash.Query.sort(ntrp_rating: ntrp_sort, name: :asc)
    |> Ash.read!(domain: Tennis)
  end

  @doc """
  Parse a comma-separated query param string into a list of strings.
  Returns `[]` for nil or empty string.
  """
  def parse_list_param(nil), do: []
  def parse_list_param(""), do: []
  def parse_list_param(s), do: String.split(s, ",")

  defp maybe_filter_name(query, ""), do: query

  defp maybe_filter_name(query, search) do
    pattern = "%#{search}%"
    Ash.Query.filter(query, fragment("? ILIKE ?", name, ^pattern))
  end

  defp maybe_filter_ntrp(query, []), do: query

  defp maybe_filter_ntrp(query, ratings) do
    include_none = "none" in ratings
    rated = Enum.reject(ratings, &(&1 == "none"))

    cond do
      include_none and rated == [] ->
        Ash.Query.filter(query, is_nil(ntrp_rating))

      include_none ->
        decimal_ratings = Enum.map(rated, &Decimal.new/1)
        Ash.Query.filter(query, is_nil(ntrp_rating) or ntrp_rating in ^decimal_ratings)

      true ->
        decimal_ratings = Enum.map(rated, &Decimal.new/1)
        Ash.Query.filter(query, ntrp_rating in ^decimal_ratings)
    end
  end

  defp maybe_filter_bracket(query, []), do: query

  defp maybe_filter_bracket(query, brackets) do
    Enum.reduce(brackets, query, fn bracket, q ->
      case bracket do
        "18" -> Ash.Query.filter(q, eligible_18_plus == true)
        "40" -> Ash.Query.filter(q, eligible_40_plus == true)
        "55" -> Ash.Query.filter(q, eligible_55_plus == true)
      end
    end)
  end
end
