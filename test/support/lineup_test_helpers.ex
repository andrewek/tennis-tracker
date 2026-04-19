defmodule TennisTrackerWeb.LineupTestHelpers do
  @moduledoc """
  Shared helpers for lineup-related LiveView tests.
  """

  alias TennisTracker.{Factory, Tennis}

  def setup_captain(grp, team) do
    captain = Factory.user()
    Factory.group_membership(group: grp, user: captain)
    Factory.team_role(group: grp, user: captain, team: team, traits: [:captain])
    captain
  end

  def setup_member(grp) do
    member = Factory.user()
    Factory.group_membership(group: grp, user: member)
    member
  end

  def get_reserve_col(grp, team) do
    Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, authorize?: false)
    |> Enum.find(&(&1.name == "Reserve"))
  end
end
