defmodule TennisTracker.Factory do
  alias TennisTracker.Tennis

  # ---------------------------------------------------------------------------
  # Player
  # ---------------------------------------------------------------------------

  def player(opts \\ []) do
    {traits, opts} = Keyword.pop(opts, :traits, [])
    n = System.unique_integer([:positive])

    base = %{
      name: "Player #{n}",
      email: "player#{n}@example.com",
      phone_number: "555-#{String.pad_leading(to_string(rem(n, 10_000)), 4, "0")}",
      ntrp_rating: Decimal.new("3.5"),
      eligible_18_plus: true,
      eligible_40_plus: false,
      eligible_55_plus: false
    }

    attrs =
      Enum.reduce(traits, base, fn trait, acc -> Map.merge(acc, player_trait(trait)) end)
      |> Map.merge(Map.new(opts))

    Tennis.create_player!(attrs)
  end

  defp player_trait(:unrated), do: %{ntrp_rating: nil}
  defp player_trait(:eligible_40_plus), do: %{eligible_40_plus: true}
  defp player_trait(:eligible_55_plus), do: %{eligible_55_plus: true}

  defp player_trait(:ineligible),
    do: %{eligible_18_plus: false, eligible_40_plus: false, eligible_55_plus: false}

  # ---------------------------------------------------------------------------
  # TeamType
  # ---------------------------------------------------------------------------

  def team_type(opts \\ []) do
    {traits, opts} = Keyword.pop(opts, :traits, [])
    n = System.unique_integer([:positive])

    base = %{
      name: "Team Type #{n}",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }

    attrs =
      Enum.reduce(traits, base, fn trait, acc -> Map.merge(acc, team_type_trait(trait)) end)
      |> Map.merge(Map.new(opts))

    Tennis.create_team_type!(attrs)
  end

  defp team_type_trait(:_35) do
    %{
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }
  end

  defp team_type_trait(:_40) do
    %{
      age_group: "18_plus",
      ntrp_level: Decimal.new("4.0"),
      allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
    }
  end

  defp team_type_trait(:_40_plus_35) do
    %{
      age_group: "40_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }
  end

  defp team_type_trait(:_40_plus_40) do
    %{
      age_group: "40_plus",
      ntrp_level: Decimal.new("4.0"),
      allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
    }
  end

  # ---------------------------------------------------------------------------
  # Team
  # ---------------------------------------------------------------------------

  def team(opts \\ []) do
    {traits, opts} = Keyword.pop(opts, :traits, [])
    {tt, opts} = Keyword.pop(opts, :team_type)
    tt = tt || team_type()
    n = System.unique_integer([:positive])

    base = %{
      name: "Team #{n}",
      team_type_id: tt.id,
      season_year: Date.utc_today().year,
      is_pseudo: false
    }

    attrs =
      Enum.reduce(traits, base, fn trait, acc -> Map.merge(acc, team_trait(trait)) end)
      |> Map.merge(Map.new(opts))

    Tennis.create_team!(attrs)
  end

  defp team_trait(:pseudo), do: %{is_pseudo: true}

  # ---------------------------------------------------------------------------
  # SeasonRules
  # ---------------------------------------------------------------------------

  def season_rules(opts \\ []) do
    {_traits, opts} = Keyword.pop(opts, :traits, [])
    {tt, opts} = Keyword.pop(opts, :team_type)
    tt = tt || team_type()

    base = %{
      team_type_id: tt.id,
      season_year: Date.utc_today().year,
      min_roster: 8,
      max_roster: 18,
      on_level_min_pct: Decimal.new("0.60")
    }

    attrs = Map.merge(base, Map.new(opts))

    Tennis.create_season_rules!(attrs)
  end

  # ---------------------------------------------------------------------------
  # TeamMembership
  # ---------------------------------------------------------------------------

  def team_membership(opts \\ []) do
    {_traits, opts} = Keyword.pop(opts, :traits, [])
    {p, opts} = Keyword.pop(opts, :player)
    {t, _opts} = Keyword.pop(opts, :team)
    p = p || player()
    t = t || team()

    {:ok, membership} = Tennis.assign_player(p.id, t.id, t.team_type_id, t.season_year)
    membership
  end
end
