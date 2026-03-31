defmodule TennisTrackerWeb.Matches.LineupShowTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  defp setup_captain(grp, team) do
    captain = Factory.user()
    Factory.group_membership(group: grp, user: captain)
    Factory.team_role(group: grp, user: captain, team: team, traits: [:captain])
    captain
  end

  defp setup_member(grp) do
    member = Factory.user()
    Factory.group_membership(group: grp, user: member)
    member
  end

  # ---------------------------------------------------------------------------
  # 4.1 + 4.2: Read-only lineup renders correctly
  # ---------------------------------------------------------------------------

  describe "read-only lineup section" do
    test "shows empty state when team has no slots", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      {:ok, _view, html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "No lineup slots defined"
    end

    test "renders slots and assigned players", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Rafael Nadal")

      slot =
        Tennis.create_lineup_slot!(
          %{name: "#1 Singles", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          authorize?: false
        )

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, _view, html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "#1 Singles"
      assert html =~ "Rafael Nadal"
    end

    test "shows empty slot marker when slot has no assignments", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      Tennis.create_lineup_slot!(
        %{name: "D1", team_id: team.id, group_id: grp.id},
        tenant: grp.id,
        authorize?: false
      )

      {:ok, _view, html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "D1"
      assert html =~ "—"
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
    test "captain sees link to team edit page when no slots defined", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      captain = setup_captain(grp, team)

      {:ok, view, html} =
        live(log_in_user(conn, captain), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "No lineup slots defined"
      assert has_element?(view, "a[href*='/teams/#{team.id}/edit']")
    end

    test "non-captain member sees message but no team edit link when no slots defined", %{
      conn: conn,
      group: grp
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      member = setup_member(grp)

      {:ok, view, html} = live(log_in_user(conn, member), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "No lineup slots defined"
      refute has_element?(view, "a[href*='/teams/#{team.id}/edit']")
    end
  end

  # ---------------------------------------------------------------------------
  # Copy Lineup button is always visible
  # ---------------------------------------------------------------------------

  describe "copy lineup button" do
    test "copy lineup button is always visible", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      {:ok, _view, html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "Copy Lineup"
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

      assert render(view) =~ "Copied!"
    end

    test "clipboard fallback: hidden textarea contains lineup text for manual copy", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      Tennis.create_lineup_slot!(
        %{name: "#1 Singles", team_id: team.id, group_id: grp.id},
        tenant: grp.id,
        authorize?: false
      )

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}")

      # textarea is hidden by default (JS clipboard API not available in tests)
      assert has_element?(view, "textarea#lineup-text-area.hidden")

      # textarea contains formatted lineup text so manual copy would work if revealed
      textarea_text = view |> element("textarea#lineup-text-area") |> render()
      assert textarea_text =~ "#1 Singles"
    end
  end
end
