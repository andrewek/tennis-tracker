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
    - `tag_filter` – map with keys:
        - `:include` – `%{category_id => [tag_id]}` (OR within category, AND between categories)
        - `:show_untagged` – list of category_ids; include players with no tags in that category
    - `ntrp_sort` – `:asc_nils_first` or `:desc_nils_last` (default `:desc_nils_last`)

  Options (keyword list):
    - `tenant:` – required group_id for multitenancy
    - `actor:` – required actor for authorization
  """
  def fetch_players(name_search, ntrp_filter, tag_filter, opts_or_sort \\ :desc_nils_last)

  def fetch_players(name_search, ntrp_filter, tag_filter, opts) when is_list(opts) do
    ntrp_sort = Keyword.get(opts, :ntrp_sort, :desc_nils_last)
    load = Keyword.get(opts, :load, [])
    ash_opts = Keyword.take(opts, [:tenant, :actor])

    query =
      Player
      |> maybe_filter_name(name_search)
      |> maybe_filter_ntrp(ntrp_filter)
      |> apply_tag_filter(tag_filter)
      |> Ash.Query.sort(ntrp_rating: ntrp_sort, name: :asc)

    query =
      if load != [] do
        Ash.Query.load(query, load)
      else
        query
      end

    Ash.read!(query, Keyword.merge([domain: Tennis], ash_opts))
  end

  def fetch_players(name_search, ntrp_filter, tag_filter, ntrp_sort)
      when is_atom(ntrp_sort) do
    Player
    |> maybe_filter_name(name_search)
    |> maybe_filter_ntrp(ntrp_filter)
    |> apply_tag_filter(tag_filter)
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

  # No active facets — return query unmodified
  def apply_tag_filter(query, nil), do: query
  def apply_tag_filter(query, %{include: include}) when map_size(include) == 0, do: query

  def apply_tag_filter(query, %{include: include, show_untagged: show_untagged}) do
    # For each active category (those with at least one tag selected), apply:
    # OR within the category (player has at least one of the selected tags)
    # AND between categories (all active categories must match, with show_untagged exception)
    Enum.reduce(include, query, fn {category_id, tag_ids}, q ->
      if tag_ids == [] do
        q
      else
        show_untagged_for_this = category_id in show_untagged

        if show_untagged_for_this do
          # Include players with the selected tags OR with no tags in this category
          Ash.Query.filter(
            q,
            exists(tags, id in ^tag_ids) or
              not exists(tags, tag_category_id == ^category_id)
          )
        else
          # Include only players with at least one of the selected tags
          Ash.Query.filter(q, exists(tags, id in ^tag_ids))
        end
      end
    end)
  end
end
