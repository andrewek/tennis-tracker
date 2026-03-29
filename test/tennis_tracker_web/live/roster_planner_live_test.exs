defmodule TennisTrackerWeb.RosterPlannerLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  alias TennisTracker.Tennis

  # ---------------------------------------------------------------------------
  # 7.3 — Board loads for a valid context
  # ---------------------------------------------------------------------------

  describe "board loads" do
    test "context selector is shown at /roster-planner", %{conn: conn, group: grp} do
      Factory.team_type(group: grp)
      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/roster-planner")
      assert html =~ "Select a planning session"
    end

    test "board loads for a valid team_type_id and season_year", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert html =~ "Unassigned"
      assert html =~ "Not Participating"
    end

    test "board shows team type name in subtitle", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp, traits: [:_40], name: "40+ 4.0")

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert html =~ "40+ 4.0"
    end

    test "unassigned players appear in the Unassigned column", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Alice Player")

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert html =~ player.name
    end
  end

  # ---------------------------------------------------------------------------
  # 7.4 — Moving a player updates the correct column
  # ---------------------------------------------------------------------------

  describe "moving players" do
    test "moving player to a team removes them from Unassigned", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Bob Smith")
      team = Factory.team(group: grp, team_type: tt, name: "Team Alpha")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      html =
        render_click(view, "move_player", %{
          "player_id" => player.id,
          "target_id" => team.id
        })

      assert html =~ "Team Alpha"
      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")
      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "moving player to Unassigned removes their membership", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Carol Player")
      team = Factory.team(group: grp, team_type: tt, name: "Team B")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      render_click(view, "move_player", %{
        "player_id" => player.id,
        "target_id" => "unassigned"
      })

      render(view)
      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "moving player to Not Participating places them in that column", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Dave Player")
      year = Date.utc_today().year

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{year}")
      {:ok, pseudo} = Tennis.ensure_pseudo_team(tt.id, year, tenant: grp.id, actor: usr)

      render_click(view, "move_player", %{
        "player_id" => player.id,
        "target_id" => pseudo.id
      })

      render(view)
      assert has_element?(view, "#col-#{pseudo.id} #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # Player detail modal
  # ---------------------------------------------------------------------------

  describe "player detail modal" do
    test "clicking a player card shows the player detail modal", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Modal Player")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")
    end

    test "player detail modal shows the player's name", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Named Player")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "h3", player.name)
    end

    test "player detail modal contains a View profile link to the player's show page", %{
      conn: conn,
      group: grp
    } do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Profile Player")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")
    end

    test "firing deselect_player closes the modal", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Deselect Player")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")

      render_click(view, "deselect_player", %{})
      refute has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")
    end

    test "firing move_player closes the modal", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Move Player")
      team = Factory.team(group: grp, team_type: tt, name: "Team Modal")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")

      render_click(view, "move_player", %{
        "player_id" => player.id,
        "target_id" => team.id
      })

      refute has_element?(view, "a[href='/g/#{grp.slug}/players/#{player.id}']")
    end
  end

  # ---------------------------------------------------------------------------
  # 7.5 — Health indicators appear when rules are violated
  # ---------------------------------------------------------------------------

  describe "health indicators" do
    test "warning shown when team is below minimum roster size", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      Factory.season_rules(group: grp, team_type: tt, min_roster: 4, max_roster: 10)
      player = Factory.player(group: grp, name: "Eve Player", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(group: grp, team_type: tt, name: "Small Team")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      assert html =~ "minimum"
    end

    test "warning icon shown for player with invalid NTRP on this team", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      # 4.5 is not in allowed_ntrp_levels for a 3.5 team
      player = Factory.player(group: grp, name: "Frank Player", ntrp_rating: Decimal.new("4.5"))
      team = Factory.team(group: grp, team_type: tt, name: "Team C")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      assert has_element?(view, "#player-#{player.id} span.sr-only", "Rating issue")
    end

    test "caution shown for unrated player on a team", %{conn: conn, group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, traits: [:unrated], name: "Grace Player")
      team = Factory.team(group: grp, team_type: tt, name: "Team D")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      assert html =~ "?"
    end

    test "no rule violations shown when no season rules exist", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Henry Player", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(group: grp, team_type: tt, name: "Team E")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      refute html =~ "minimum"
      refute html =~ "maximum"
      refute html =~ "on-level"
    end
  end

  # ---------------------------------------------------------------------------
  # Unassigned column — player pool
  # ---------------------------------------------------------------------------

  describe "unassigned player pool" do
    test "unassigned player appears in Unassigned column", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Alex Player", ntrp_rating: Decimal.new("3.5"))

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "players outside the team type's allowed NTRP levels are excluded from Unassigned", %{
      conn: conn,
      group: grp
    } do
      # Default team type has allowed_ntrp_levels [3.0, 3.5]; 4.0 is ineligible
      tt = Factory.team_type(group: grp)

      over_rated =
        Factory.player(group: grp, name: "Zara Overrated", ntrp_rating: Decimal.new("4.0"))

      eligible =
        Factory.player(group: grp, name: "Zara Eligible", ntrp_rating: Decimal.new("3.5"))

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      refute has_element?(view, "#col-unassigned #player-#{over_rated.id}")
      assert has_element?(view, "#col-unassigned #player-#{eligible.id}")
    end

    test "nil-rated player appears in Unassigned", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, traits: [:unrated], name: "Cam Unrated")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "player already assigned to a team appears in their team column, not Unassigned", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Eve Assigned", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(group: grp, team_type: tt, name: "Team A")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")
      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # 10.x — Delete team
  # ---------------------------------------------------------------------------

  describe "delete team" do
    test "deleting a team returns its players to Unassigned", %{conn: conn, group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Frank Deleted", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(group: grp, team_type: tt, name: "Doomed Team")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")

      render_click(view, "open_team_modal", %{"mode" => "delete", "team_id" => team.id})
      render_click(view, "confirm_delete_team", %{"team_id" => team.id})

      render(view)
      refute has_element?(view, "#col-#{team.id}")
      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "cancelling delete leaves the team intact", %{conn: conn, group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Grace Survives", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(group: grp, team_type: tt, name: "Surviving Team")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      render_click(view, "open_team_modal", %{"mode" => "delete", "team_id" => team.id})
      render_click(view, "close_team_modal", %{})

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # 7.6 — PubSub broadcast reaches a second subscriber session
  # ---------------------------------------------------------------------------

  describe "PubSub real-time sync" do
    test "a move made in one session is reflected in another", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp)
      player = Factory.player(group: grp, name: "Ivan Player")
      team = Factory.team(group: grp, team_type: tt, name: "Team F")

      # Two separate LiveView connections to the same board
      {:ok, view1, _} = live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")
      {:ok, view2, _} = live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{team.season_year}")

      # Move player in view1
      render_click(view1, "move_player", %{
        "player_id" => player.id,
        "target_id" => team.id
      })

      render(view1)
      # view2 should reflect the change
      html2 = render(view2)
      assert has_element?(view2, "#col-#{team.id} #player-#{player.id}")
      assert html2 =~ player.name
    end
  end
end
