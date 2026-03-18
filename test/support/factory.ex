defmodule TennisTracker.Factory do
  alias TennisTracker.{Accounts, Groups, Tennis}
  alias TennisTracker.Accounts.User
  alias TennisTracker.Groups.{Group, GroupMembership}
  alias TennisTracker.Tennis.TeamRole

  require Ash.Query

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  def user(opts \\ []) do
    n = System.unique_integer([:positive])
    email = Keyword.get(opts, :email, "user#{n}@example.com")
    password = Keyword.get(opts, :password, "Password1!")
    role = Keyword.get(opts, :role, :member)

    {:ok, user} =
      Ash.create(
        User,
        %{email: email, password: password, password_confirmation: password},
        action: :register_with_password,
        domain: Accounts,
        authorize?: false
      )

    if role != :member do
      {:ok, user} =
        Ash.update(user, %{role: role}, action: :update_role, domain: Accounts, authorize?: false)

      user
    else
      user
    end
  end

  # ---------------------------------------------------------------------------
  # Group
  # ---------------------------------------------------------------------------

  def group(opts \\ []) do
    n = System.unique_integer([:positive])
    name = Keyword.get(opts, :name, "Group #{n}")
    slug = Keyword.get(opts, :slug, "group-#{n}")

    Group
    |> Ash.Changeset.for_create(:create, %{name: name, slug: slug},
      domain: Groups,
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # GroupMembership
  # ---------------------------------------------------------------------------

  def group_membership(opts \\ []) do
    {traits, opts} = Keyword.pop(opts, :traits, [])
    grp = Keyword.fetch!(opts, :group)
    usr = Keyword.fetch!(opts, :user)
    role = if :owner in traits, do: :owner, else: Keyword.get(opts, :role, :member)

    GroupMembership
    |> Ash.Changeset.for_create(
      :create,
      %{group_id: grp.id, user_id: usr.id, role: role}, domain: Groups, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # TeamRole
  # ---------------------------------------------------------------------------

  def team_role(opts \\ []) do
    {traits, opts} = Keyword.pop(opts, :traits, [])
    grp = Keyword.fetch!(opts, :group)
    usr = Keyword.fetch!(opts, :user)
    t = Keyword.fetch!(opts, :team)
    role = if :captain in traits, do: :captain, else: Keyword.get(opts, :role, :member)

    TeamRole
    |> Ash.Changeset.for_create(
      :create,
      %{user_id: usr.id, team_id: t.id, role: role, group_id: grp.id},
      domain: Tennis,
      tenant: grp.id,
      authorize?: false
    )
    |> Ash.create!(authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # Player
  # ---------------------------------------------------------------------------

  def player(opts \\ []) do
    {traits, opts} = Keyword.pop(opts, :traits, [])
    {grp, opts} = Keyword.pop(opts, :group)

    grp || raise ArgumentError, "Factory.player/1 requires group: option (tenant-scoped resource)"

    n = System.unique_integer([:positive])

    base = %{
      name: "Player #{n}",
      email: "player#{n}@example.com",
      phone_number: "555-#{String.pad_leading(to_string(rem(n, 10_000)), 4, "0")}",
      ntrp_rating: Decimal.new("3.5"),
      eligible_18_plus: true,
      eligible_40_plus: false,
      eligible_55_plus: false,
      group_id: grp.id
    }

    attrs =
      Enum.reduce(traits, base, fn trait, acc -> Map.merge(acc, player_trait(trait)) end)
      |> Map.merge(Map.new(opts))

    Tennis.create_player!(attrs, tenant: grp.id, authorize?: false)
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
    {grp, opts} = Keyword.pop(opts, :group)

    grp ||
      raise ArgumentError, "Factory.team_type/1 requires group: option (tenant-scoped resource)"

    n = System.unique_integer([:positive])

    base = %{
      name: "Team Type #{n}",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")],
      group_id: grp.id
    }

    attrs =
      Enum.reduce(traits, base, fn trait, acc -> Map.merge(acc, team_type_trait(trait)) end)
      |> Map.merge(Map.new(opts))

    Tennis.create_team_type!(attrs, tenant: grp.id, authorize?: false)
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
    {grp, opts} = Keyword.pop(opts, :group)
    {tt, opts} = Keyword.pop(opts, :team_type)

    grp || raise ArgumentError, "Factory.team/1 requires group: option (tenant-scoped resource)"

    tt = tt || team_type(group: grp)
    n = System.unique_integer([:positive])

    base = %{
      name: "Team #{n}",
      team_type_id: tt.id,
      season_year: Date.utc_today().year,
      is_pseudo: false,
      group_id: grp.id
    }

    attrs =
      Enum.reduce(traits, base, fn trait, acc -> Map.merge(acc, team_trait(trait)) end)
      |> Map.merge(Map.new(opts))

    Tennis.create_team!(attrs, tenant: grp.id, authorize?: false)
  end

  defp team_trait(:pseudo), do: %{is_pseudo: true}

  # ---------------------------------------------------------------------------
  # SeasonRules
  # ---------------------------------------------------------------------------

  def season_rules(opts \\ []) do
    {_traits, opts} = Keyword.pop(opts, :traits, [])
    {grp, opts} = Keyword.pop(opts, :group)
    {tt, opts} = Keyword.pop(opts, :team_type)

    grp ||
      raise ArgumentError,
            "Factory.season_rules/1 requires group: option (tenant-scoped resource)"

    tt = tt || team_type(group: grp)

    base = %{
      team_type_id: tt.id,
      season_year: Date.utc_today().year,
      min_roster: 8,
      max_roster: 18,
      on_level_min_pct: Decimal.new("0.60"),
      group_id: grp.id
    }

    attrs = Map.merge(base, Map.new(opts))

    Tennis.create_season_rules!(attrs, tenant: grp.id, authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # TeamMembership
  # ---------------------------------------------------------------------------

  def team_membership(opts \\ []) do
    {_traits, opts} = Keyword.pop(opts, :traits, [])
    {grp, opts} = Keyword.pop(opts, :group)
    {p, opts} = Keyword.pop(opts, :player)
    {t, _opts} = Keyword.pop(opts, :team)

    grp ||
      raise ArgumentError,
            "Factory.team_membership/1 requires group: option (tenant-scoped resource)"

    p = p || player(group: grp)
    t = t || team(group: grp)

    TennisTracker.Tennis.TeamMembership
    |> Ash.Changeset.for_create(
      :create,
      %{
        player_id: p.id,
        team_id: t.id,
        team_type_id: t.team_type_id,
        season_year: t.season_year,
        group_id: grp.id
      },
      domain: Tennis,
      tenant: grp.id,
      authorize?: false
    )
    |> Ash.create!(
      upsert?: true,
      upsert_identity: :unique_player_context,
      upsert_fields: [:team_id],
      authorize?: false
    )
  end

  # ---------------------------------------------------------------------------
  # Location
  # ---------------------------------------------------------------------------

  def location(opts \\ []) do
    {grp, opts} = Keyword.pop(opts, :group)

    grp ||
      raise ArgumentError, "Factory.location/1 requires group: option (tenant-scoped resource)"

    n = System.unique_integer([:positive])

    base = %{
      name: "Location #{n}",
      address: "#{n} Tennis Ave, Omaha, NE 68101",
      google_maps_url: nil,
      group_id: grp.id
    }

    attrs = Map.merge(base, Map.new(opts))
    Tennis.create_location!(attrs, tenant: grp.id, authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # Match
  # ---------------------------------------------------------------------------

  def match(opts \\ []) do
    {grp, opts} = Keyword.pop(opts, :group)
    {t, opts} = Keyword.pop(opts, :team)
    {loc, opts} = Keyword.pop(opts, :location)

    grp || raise ArgumentError, "Factory.match/1 requires group: option (tenant-scoped resource)"

    t = t || team(group: grp)

    base = %{
      match_start_datetime:
        DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second),
      timezone: "America/Chicago",
      duration_minutes: 90,
      opponent: "Opponent Team",
      home_or_away: :home,
      team_id: t.id,
      location_id: loc && loc.id,
      group_id: grp.id
    }

    attrs = Map.merge(base, Map.new(opts))
    Tennis.create_match!(attrs, tenant: grp.id, authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # 11.5 Shared setup helper
  # ---------------------------------------------------------------------------

  @doc """
  ExUnit setup helper that creates a test group, a test user, and a GroupMembership.

  Usage:
      setup :setup_group

  Returns: %{group: group, user: user, membership: membership}
  """
  def setup_group(_context \\ %{}) do
    usr = user()
    grp = group()
    membership = group_membership(group: grp, user: usr)
    %{group: grp, user: usr, membership: membership}
  end

  @doc """
  ExUnit setup helper that creates a test group with an owner user.

  Usage:
      setup :setup_group_with_owner

  Returns: %{group: group, user: user, membership: membership}
  """
  def setup_group_with_owner(_context \\ %{}) do
    usr = user()
    grp = group()
    membership = group_membership(group: grp, user: usr, traits: [:owner])
    %{group: grp, user: usr, membership: membership}
  end
end
