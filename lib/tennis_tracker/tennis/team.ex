defmodule TennisTracker.Tennis.Team do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    primary_read_warning?: false,
    extensions: [AshAdmin.Resource]

  postgres do
    table("teams")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:season_year])
      index([:team_type_id, :season_year])
    end
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(TennisTracker.Policies.IsGroupMember)
    end

    policy action_type(:create) do
      authorize_if(TennisTracker.Policies.IsGroupOwnerCheck)
    end

    policy action(:update) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end

    policy action(:destroy) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end

    policy action(:update_assignment_mode) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
      authorize_if(TennisTracker.Policies.IsTeamCaptainOfSelf)
    end
  end

  pub_sub do
    module(Phoenix.PubSub)
    name(TennisTracker.PubSub)
    prefix("roster")

    publish(:create, [:group_id, :team_type_id, :season_year])
    publish(:update, [:group_id, :team_type_id, :season_year])
    publish(:destroy, [:group_id, :team_type_id, :season_year])
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :season_year, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :is_pseudo, :boolean do
      allow_nil?(false)
      public?(true)
      default(false)
    end

    attribute :default_timezone, :string do
      allow_nil?(true)
      public?(true)
      default("America/Chicago")
    end

    attribute :lineup_assignment_mode, :atom do
      allow_nil?(false)
      public?(true)
      default(:one_per_match)
      constraints(one_of: [:one_per_match, :one_per_column, :many_per_match])
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :team_type, TennisTracker.Tennis.TeamType do
      allow_nil?(false)
      public?(true)
    end

    has_many :memberships, TennisTracker.Tennis.TeamMembership
    has_many :matches, TennisTracker.Tennis.Match
    has_many :team_roles, TennisTracker.Tennis.TeamRole
    has_many :lineup_slots, TennisTracker.Tennis.TeamLineupSlot
    has_many :lineup_columns, TennisTracker.Tennis.TeamLineupColumn
  end

  actions do
    read :read do
      primary?(true)
      prepare(&default_sort/2)
    end

    read :list_real do
      filter(expr(is_pseudo == false))
      prepare(&default_sort/2)
    end

    read :for_context do
      argument(:team_type_id, :uuid, allow_nil?: false)
      argument(:season_year, :integer, allow_nil?: false)

      filter(expr(team_type_id == ^arg(:team_type_id) and season_year == ^arg(:season_year)))
    end

    create :create do
      primary?(true)
      accept([:name, :season_year, :is_pseudo, :team_type_id, :group_id])

      change(fn changeset, context ->
        Ash.Changeset.after_action(changeset, fn _changeset, team ->
          unless team.is_pseudo do
            tenant = team.group_id

            col =
              TennisTracker.Tennis.TeamLineupColumn
              |> Ash.Changeset.for_create(
                :create,
                %{name: "Reserve", team_id: team.id, group_id: tenant},
                domain: TennisTracker.Tennis,
                tenant: tenant,
                authorize?: false
              )
              |> Ash.create!()

            TennisTracker.Tennis.TeamLineupSlot
            |> Ash.Changeset.for_create(
              :create,
              %{
                name: "Out",
                participation_type: :out,
                include_in_clipboard: false,
                team_id: team.id,
                team_lineup_column_id: col.id,
                group_id: tenant
              },
              domain: TennisTracker.Tennis,
              tenant: tenant,
              authorize?: false
            )
            |> Ash.create!()
          end

          {:ok, team}
        end)
      end)
    end

    update :update_assignment_mode do
      require_atomic?(false)
      accept([:lineup_assignment_mode])

      validate(fn changeset, context ->
        if Ash.Changeset.changing_attribute?(changeset, :lineup_assignment_mode) do
          new_mode = Ash.Changeset.get_attribute(changeset, :lineup_assignment_mode)
          team = changeset.data
          tenant = context.tenant

          check_mode_change(new_mode, team, tenant)
        else
          :ok
        end
      end)
    end

    update :update do
      primary?(true)
      require_atomic?(false)
      accept([:name, :default_timezone, :lineup_assignment_mode])

      validate(fn changeset, context ->
        if Ash.Changeset.changing_attribute?(changeset, :lineup_assignment_mode) do
          new_mode = Ash.Changeset.get_attribute(changeset, :lineup_assignment_mode)
          team = changeset.data
          tenant = context.tenant

          check_mode_change(new_mode, team, tenant)
        else
          :ok
        end
      end)
    end

    destroy :destroy do
      primary?(true)
    end
  end

  aggregates do
    first :next_match_start_datetime, :matches, :match_start_datetime do
      filter(expr(match_start_datetime >= fragment("NOW()")))
      sort(match_start_datetime: :asc)
    end
  end

  defp default_sort(query, _context) do
    Ash.Query.sort(query, [
      {:season_year, :desc},
      {:team_type_age_group, :asc_nils_last},
      {:team_type_ntrp_level, :desc_nils_last},
      {:name, :asc}
    ])
  end

  calculations do
    calculate(:team_type_name, :string, expr(team_type.name))
    calculate(:team_type_age_group, :string, expr(team_type.age_group))
    calculate(:team_type_ntrp_level, :decimal, expr(team_type.ntrp_level))

    calculate(
      :display_label,
      :string,
      expr(
        fragment(
          "CAST(? AS text) || ' ' || ? || ' - ' || ?",
          season_year,
          team_type.name,
          name
        )
      )
    )

    calculate(
      :short_display_label,
      :string,
      expr(fragment("? || ' - ' || ?", team_type.name, name))
    )
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end

  defp check_mode_change(:many_per_match, _team, _tenant), do: :ok

  defp check_mode_change(:one_per_match, team, tenant) do
    if has_multi_assignment_violations?(team.id, tenant) do
      {:error,
       field: :lineup_assignment_mode,
       message:
         "cannot change to one_per_match: some matches have players with multiple assignments. Resolve conflicts first."}
    else
      :ok
    end
  end

  defp check_mode_change(:one_per_column, team, tenant) do
    if has_same_column_violations?(team.id, tenant) do
      {:error,
       field: :lineup_assignment_mode,
       message:
         "cannot change to one_per_column: some matches have players with multiple assignments in the same column. Resolve conflicts first."}
    else
      :ok
    end
  end

  defp has_multi_assignment_violations?(team_id, tenant) do
    require Ash.Query

    match_ids =
      TennisTracker.Tennis.Match
      |> Ash.Query.filter(team_id == ^team_id)
      |> Ash.read!(domain: TennisTracker.Tennis, tenant: tenant, authorize?: false)
      |> Enum.map(& &1.id)

    if match_ids == [] do
      false
    else
      TennisTracker.Tennis.MatchLineupAssignment
      |> Ash.Query.filter(match_id in ^match_ids)
      |> Ash.read!(domain: TennisTracker.Tennis, tenant: tenant, authorize?: false)
      |> Enum.group_by(&{&1.match_id, &1.player_id})
      |> Enum.any?(fn {_, assignments} -> length(assignments) > 1 end)
    end
  end

  defp has_same_column_violations?(team_id, tenant) do
    require Ash.Query

    match_ids =
      TennisTracker.Tennis.Match
      |> Ash.Query.filter(team_id == ^team_id)
      |> Ash.read!(domain: TennisTracker.Tennis, tenant: tenant, authorize?: false)
      |> Enum.map(& &1.id)

    if match_ids == [] do
      false
    else
      TennisTracker.Tennis.MatchLineupAssignment
      |> Ash.Query.filter(match_id in ^match_ids)
      |> Ash.Query.load(:team_lineup_slot)
      |> Ash.read!(domain: TennisTracker.Tennis, tenant: tenant, authorize?: false)
      |> Enum.group_by(&{&1.match_id, &1.player_id, &1.team_lineup_slot.team_lineup_column_id})
      |> Enum.any?(fn {_, assignments} -> length(assignments) > 1 end)
    end
  end
end
