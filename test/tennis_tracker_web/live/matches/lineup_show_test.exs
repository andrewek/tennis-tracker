defmodule TennisTrackerWeb.Matches.LineupShowTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TennisTrackerWeb.LineupTestHelpers

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  # ---------------------------------------------------------------------------
  # 4.1 + 4.2: Read-only lineup renders correctly
  # ---------------------------------------------------------------------------

  describe "read-only lineup section" do
    test "shows empty state when team has no playing slots", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      # Delete all default playing slots so only the Out exclusion slot remains
      Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
      |> Enum.filter(&(&1.participation_type != :out))
      |> Enum.each(&Tennis.delete_lineup_slot!(&1, tenant: grp.id, authorize?: false))

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "#lineup-empty-state")
    end

    test "renders slots and assigned players", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Rafael Nadal")
      reserve_col = get_reserve_col(grp, team)

      slot =
        Tennis.create_lineup_slot!(
          %{
            name: "D1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          authorize?: false
        )

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "#lineup-slot-#{slot.id}")
      assert has_element?(view, "#lineup-player-#{player.id}")
    end

    test "shows empty slot marker when slot has no assignments", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      reserve_col = get_reserve_col(grp, team)

      slot =
        Tennis.create_lineup_slot!(
          %{
            name: "D1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          authorize?: false
        )

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "#lineup-slot-#{slot.id}")
      assert has_element?(view, "#lineup-slot-#{slot.id}", "—")
    end
  end

  # ---------------------------------------------------------------------------
  # 4.3: Edit Lineup link visible to captains only
  # ---------------------------------------------------------------------------

  describe "edit lineup link" do
    test "captain sees 'Edit Lineup' link", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      captain = setup_captain(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, captain), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "a[href*='lineup-edit']")
    end

    test "owner sees 'Edit Lineup' link", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "a[href*='lineup-edit']")
    end

    test "non-captain member does not see 'Edit Lineup' link", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      member = setup_member(grp)

      {:ok, view, _html} =
        live(log_in_user(conn, member), ~p"/g/#{grp.slug}/matches/#{match.id}")

      refute has_element?(view, "a[href*='lineup-edit']")
    end
  end

  # ---------------------------------------------------------------------------
  # 4.4: Empty state variants
  # ---------------------------------------------------------------------------

  describe "empty state" do
    test "captain sees link to team edit page when no playing slots defined", %{
      conn: conn,
      group: grp
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      captain = setup_captain(grp, team)

      Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
      |> Enum.filter(&(&1.participation_type != :out))
      |> Enum.each(&Tennis.delete_lineup_slot!(&1, tenant: grp.id, authorize?: false))

      {:ok, view, _html} =
        live(log_in_user(conn, captain), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "#lineup-empty-state")
      assert has_element?(view, "a[href*='/teams/#{team.id}/settings']")
    end

    test "non-captain member sees message but no team edit link when no playing slots defined", %{
      conn: conn,
      group: grp
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      member = setup_member(grp)

      Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
      |> Enum.filter(&(&1.participation_type != :out))
      |> Enum.each(&Tennis.delete_lineup_slot!(&1, tenant: grp.id, authorize?: false))

      {:ok, view, _html} = live(log_in_user(conn, member), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "#lineup-empty-state")
      refute has_element?(view, "a[href*='/teams/#{team.id}/settings']")
    end
  end

  # ---------------------------------------------------------------------------
  # Copy Lineup button is always visible
  # ---------------------------------------------------------------------------

  describe "copy lineup button" do
    test "copy lineup button is always visible", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "#copy-lineup-btn")
    end

    test "lineup text textarea is hidden by default", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "textarea#lineup-text-area.hidden")
    end

    test "clipboard_copied event shows Copied! flash", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      render_click(view, "clipboard_copied", %{})

      assert has_element?(view, "#flash-info", "Copied!")
    end

    test "clipboard fallback: hidden textarea contains lineup text for manual copy", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      reserve_col = get_reserve_col(grp, team)

      Tennis.create_lineup_slot!(
        %{
          name: "D1",
          team_id: team.id,
          group_id: grp.id,
          team_lineup_column_id: reserve_col.id
        },
        tenant: grp.id,
        authorize?: false
      )

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "textarea#lineup-text-area.hidden")
      assert has_element?(view, "textarea#lineup-text-area", "D1")
    end
  end
end
