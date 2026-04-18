defmodule TennisTracker.Tennis.MatchLineupAssignment do
  @moduledoc false

  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshAdmin.Resource]

  require Ash.Query

  postgres do
    table("match_lineup_assignments")
    repo(TennisTracker.Repo)

    references do
      reference(:team_lineup_slot, on_delete: :delete)
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
      authorize_if(TennisTracker.Policies.IsTeamCaptainForLineupAssignmentCheck)
    end

    policy action_type([:update, :destroy]) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
      authorize_if(TennisTracker.Policies.IsTeamCaptainForLineupAssignment)
    end
  end

  pub_sub do
    module(Phoenix.PubSub)
    name(TennisTracker.PubSub)
    prefix("lineup")

    publish(:create, [:group_id, :match_id])
    publish(:update, [:group_id, :match_id])
    publish(:destroy, [:group_id, :match_id])
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :match, TennisTracker.Tennis.Match do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :player, TennisTracker.Tennis.Player do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :team_lineup_slot, TennisTracker.Tennis.TeamLineupSlot do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    read :for_match do
      argument(:match_id, :uuid, allow_nil?: false)
      filter(expr(match_id == ^arg(:match_id)))
    end

    create :create do
      primary?(true)
      accept([:match_id, :player_id, :team_lineup_slot_id, :group_id])

      change(fn changeset, context ->
        Ash.Changeset.before_action(changeset, fn changeset ->
          slot_id = Ash.Changeset.get_attribute(changeset, :team_lineup_slot_id)
          match_id = Ash.Changeset.get_attribute(changeset, :match_id)
          player_id = Ash.Changeset.get_attribute(changeset, :player_id)
          tenant = context.tenant

          if slot_id && match_id && player_id && tenant do
            slot =
              Ash.get!(TennisTracker.Tennis.TeamLineupSlot, slot_id,
                domain: TennisTracker.Tennis,
                tenant: tenant,
                authorize?: false
              )

            existing =
              TennisTracker.Tennis.MatchLineupAssignment
              |> Ash.Query.filter(match_id == ^match_id and player_id == ^player_id)
              |> Ash.Query.load(:team_lineup_slot)
              |> Ash.read!(domain: TennisTracker.Tennis, tenant: tenant, authorize?: false)

            if slot.participation_type == :out do
              existing
              |> Enum.reject(&(&1.team_lineup_slot.participation_type == :out))
              |> Enum.each(
                &Ash.destroy!(&1,
                  domain: TennisTracker.Tennis,
                  authorize?: false,
                  tenant: tenant
                )
              )

              changeset
            else
              case Enum.find(existing, &(&1.team_lineup_slot.participation_type == :out)) do
                nil ->
                  apply_mode_constraint(changeset, existing, slot, match_id, tenant)

                _excl ->
                  Ash.Changeset.add_error(changeset,
                    field: :player_id,
                    message:
                      "is excluded from this match and cannot be assigned to a playing slot"
                  )
              end
            end
          else
            changeset
          end
        end)
      end)
    end

    update :update do
      primary?(true)
      accept([:team_lineup_slot_id])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:player_per_slot_per_match, [:match_id, :player_id, :team_lineup_slot_id])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end

  defp apply_mode_constraint(changeset, existing, target_slot, match_id, tenant) do
    match =
      Ash.get!(TennisTracker.Tennis.Match, match_id,
        domain: TennisTracker.Tennis,
        tenant: tenant,
        authorize?: false
      )

    team =
      Ash.get!(TennisTracker.Tennis.Team, match.team_id,
        domain: TennisTracker.Tennis,
        tenant: tenant,
        authorize?: false
      )

    case team.lineup_assignment_mode do
      :one_per_match ->
        if existing == [] do
          changeset
        else
          Ash.Changeset.add_error(changeset,
            field: :player_id,
            message: "already has an assignment for this match"
          )
        end

      :one_per_column ->
        same_column =
          Enum.find(existing, fn a ->
            a.team_lineup_slot.team_lineup_column_id == target_slot.team_lineup_column_id
          end)

        if same_column do
          Ash.Changeset.add_error(changeset,
            field: :player_id,
            message: "already has an assignment in this column for this match"
          )
        else
          changeset
        end

      :many_per_match ->
        changeset
    end
  end
end
