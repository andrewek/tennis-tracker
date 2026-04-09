defmodule TennisTrackerWeb.Matches.LineupEditTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TennisTrackerWeb.LineupTestHelpers

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  defp create_slot(grp, team, name, opts \\ []) do
    col =
      Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, authorize?: false) |> hd()

    attrs = %{name: name, team_id: team.id, group_id: grp.id, team_lineup_column_id: col.id}
    attrs = if ec = opts[:expected_count], do: Map.put(attrs, :expected_count, ec), else: attrs

    Tennis.create_lineup_slot!(attrs, tenant: grp.id, authorize?: false)
  end

  # ---------------------------------------------------------------------------
  # Authorization
  # ---------------------------------------------------------------------------

  describe "authorization" do
    test "non-captain member is redirected to match show", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      member = setup_member(grp)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(log_in_user(conn, member), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      assert path == ~p"/g/#{grp.slug}/matches/#{match.id}"
    end

    test "captain can access lineup edit page", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      captain = setup_captain(grp, team)

      assert {:ok, _view, _html} =
               live(
                 log_in_user(conn, captain),
                 ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit"
               )
    end

    test "owner can access lineup edit page", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      assert {:ok, _view, _html} =
               live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")
    end
  end

  # ---------------------------------------------------------------------------
  # Empty state
  # ---------------------------------------------------------------------------

  describe "empty state" do
    test "shows empty state message and team edit link when no slots defined", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      assert has_element?(view, "#lineup-empty-state")
      assert has_element?(view, "a[href*='/teams/#{team.id}/edit']")
    end
  end

  # ---------------------------------------------------------------------------
  # Board renders correctly
  # ---------------------------------------------------------------------------

  describe "board rendering" do
    test "shows Available column and slot columns", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      create_slot(grp, team, "S1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      assert has_element?(view, "#col-available")
      assert has_element?(view, "[id^='col-']", "S1")
    end

    test "team member appears in Available when unassigned", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Rafael Nadal")
      Factory.team_membership(group: grp, team: team, player: player)
      create_slot(grp, team, "S1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      assert has_element?(view, "#col-available #player-#{player.id}")
    end

    test "assigned player appears in slot column, not Available", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Roger Federer")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      # Player in slot column
      assert has_element?(view, "#col-#{slot.id} #player-#{player.id}")
      # Player not in available column
      refute has_element?(view, "#col-available #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # Assign / Unassign via events
  # ---------------------------------------------------------------------------

  describe "move_lineup_player event" do
    test "assigning a player moves them from Available to slot column", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Andy Murray")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "D1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      assert has_element?(view, "#col-available #player-#{player.id}")

      render_click(view, "move_lineup_player", %{
        "player_id" => player.id,
        "target_id" => slot.id
      })

      refute has_element?(view, "#col-available #player-#{player.id}")
      assert has_element?(view, "#col-#{slot.id} #player-#{player.id}")
    end

    test "unassigning a player moves them back to Available", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Stefanos Tsitsipas")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      assert has_element?(view, "#col-#{slot.id} #player-#{player.id}")

      render_click(view, "move_lineup_player", %{
        "player_id" => player.id,
        "target_id" => "available"
      })

      assert has_element?(view, "#col-available #player-#{player.id}")
      refute has_element?(view, "#col-#{slot.id} #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # expected_count warning
  # ---------------------------------------------------------------------------

  describe "expected_count warning" do
    test "shows warning when assignment count differs from expected_count", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      slot = create_slot(grp, team, "D1", expected_count: 2)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      assert has_element?(view, "#col-#{slot.id}", "Expected 2, have 0")
    end

    test "no warning when assignment count matches expected_count", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp)
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1", expected_count: 1)

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      refute has_element?(view, "#col-#{slot.id}", "Expected")
    end

    test "no warning when expected_count is nil", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      slot = create_slot(grp, team, "S1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      refute has_element?(view, "#col-#{slot.id}", "Expected")
    end
  end

  # ---------------------------------------------------------------------------
  # Tap-to-assign modal
  # ---------------------------------------------------------------------------

  describe "tap-to-assign modal" do
    test "tapping a player card in Available opens the modal", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Modal Available Player")
      Factory.team_membership(group: grp, team: team, player: player)
      create_slot(grp, team, "S1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "h3", player.name)
      assert has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")
    end

    test "tapping a player card in a slot opens the modal", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Modal Slot Player")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "h3", player.name)
      assert has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")
    end

    test "Available player: Available button is filled, slot buttons are outline", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Unassigned Player")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(
               view,
               "button.btn-primary:not(.btn-outline)[phx-value-target_id='available']"
             )

      assert has_element?(view, "button.btn-outline[phx-value-target_id='#{slot.id}']")
    end

    test "assigned player: current slot button is filled, Available and other slots are outline",
         %{
           conn: conn,
           group: grp,
           user: usr
         } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Assigned Player")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(
               view,
               "button.btn-primary:not(.btn-outline)[phx-value-target_id='#{slot.id}']"
             )

      assert has_element?(view, "button.btn-outline[phx-value-target_id='available']")
    end

    test "tapping a slot button assigns the player and closes the modal", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Assign Via Modal Player")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "h3", player.name)

      render_click(view, "move_lineup_player", %{
        "player_id" => player.id,
        "target_id" => slot.id
      })

      refute has_element?(view, "h3", player.name)
      assert has_element?(view, "#col-#{slot.id} #player-#{player.id}")
    end

    test "tapping the Available button unassigns the player and closes the modal", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Unassign Via Modal Player")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "h3", player.name)

      render_click(view, "move_lineup_player", %{
        "player_id" => player.id,
        "target_id" => "available"
      })

      refute has_element?(view, "h3", player.name)
      assert has_element?(view, "#col-available #player-#{player.id}")
    end

    test "dismissing the modal via close button makes no assignment change", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Close Button Player")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "h3", player.name)

      render_click(view, "deselect_player", %{})

      refute has_element?(view, "h3", player.name)
      assert has_element?(view, "#col-#{slot.id} #player-#{player.id}")
    end

    test "tapping a player card while a modal is already open switches to the new player",
         %{
           conn: conn,
           group: grp,
           user: usr
         } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player1 = Factory.player(group: grp, name: "First Modal Player")
      player2 = Factory.player(group: grp, name: "Second Modal Player")
      Factory.team_membership(group: grp, team: team, player: player1)
      Factory.team_membership(group: grp, team: team, player: player2)
      create_slot(grp, team, "S1")

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player1.id})
      assert has_element?(view, "h3", player1.name)

      render_click(view, "select_player", %{"player_id" => player2.id})

      assert has_element?(view, "h3", player2.name)
      refute has_element?(view, "h3", player1.name)
    end

    test "moving a player from an exclusion slot to a playing slot succeeds", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Excluded Player")
      Factory.team_membership(group: grp, team: team, player: player)
      playing_slot = create_slot(grp, team, "S1")

      excl_slot =
        Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
        |> Enum.find(& &1.is_exclusion_slot)

      Tennis.assign_to_slot(match.id, player.id, excl_slot.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit")

      render_click(view, "select_player", %{"player_id" => player.id})

      render_click(view, "move_lineup_player", %{
        "player_id" => player.id,
        "target_id" => playing_slot.id
      })

      assert has_element?(view, "#col-#{playing_slot.id} #player-#{player.id}")
      refute has_element?(view, "#col-#{excl_slot.id} #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # Real-time sync (PubSub)
  # ---------------------------------------------------------------------------

  describe "real-time sync" do
    test "assignment made in one session is reflected in another session", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)
      player = Factory.player(group: grp, name: "Novak Djokovic")
      Factory.team_membership(group: grp, team: team, player: player)
      slot = create_slot(grp, team, "S1")

      url = ~p"/g/#{grp.slug}/matches/#{match.id}/lineup-edit"
      {:ok, view1, _} = live(log_in_user(conn, usr), url)
      {:ok, view2, _} = live(log_in_user(conn, usr), url)

      # Assign player via view1
      render_click(view1, "move_lineup_player", %{
        "player_id" => player.id,
        "target_id" => slot.id
      })

      render(view1)

      # view2 should reflect the change via PubSub
      assert has_element?(view2, "#col-#{slot.id} #player-#{player.id}")
      refute has_element?(view2, "#col-available #player-#{player.id}")
    end
  end
end
