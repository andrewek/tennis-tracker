defmodule TennisTrackerWeb.RosterPlannerLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  alias TennisTracker.Tennis

  # ---------------------------------------------------------------------------
  # 7.3 — Board loads for a valid context
  # ---------------------------------------------------------------------------

  describe "board loads" do
    test "context selector is shown at /roster-planner", %{conn: conn} do
      Factory.team_type()
      {:ok, _view, html} = live(conn, ~p"/roster-planner")
      assert html =~ "Select a planning session"
    end

    test "board loads for a valid team_type_id and season_year", %{conn: conn} do
      tt = Factory.team_type()
      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")
      assert html =~ "Unassigned"
      assert html =~ "Not Participating"
    end

    test "board shows team type name in subtitle", %{conn: conn} do
      tt = Factory.team_type(traits: [:_40], name: "40+ 4.0")
      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")
      assert html =~ "40+ 4.0"
    end

    test "unassigned players appear in the Unassigned column", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Alice Player")
      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")
      assert html =~ player.name
    end
  end

  # ---------------------------------------------------------------------------
  # 7.4 — Moving a player updates the correct column
  # ---------------------------------------------------------------------------

  describe "moving players" do
    test "moving player to a team removes them from Unassigned", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Bob Smith")
      team = Factory.team(team_type: tt, name: "Team Alpha")

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      html =
        render_click(view, "move_player", %{
          "player_id" => player.id,
          "target_id" => team.id
        })

      assert html =~ "Team Alpha"
      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")
      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "moving player to Unassigned removes their membership", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Carol Player")
      team = Factory.team(team_type: tt, name: "Team B")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      render_click(view, "move_player", %{
        "player_id" => player.id,
        "target_id" => "unassigned"
      })

      render(view)
      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "moving player to Not Participating places them in that column", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Dave Player")
      year = Date.utc_today().year

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{year}")
      {:ok, pseudo} = Tennis.ensure_pseudo_team(tt.id, year)

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
    test "clicking a player card shows the player detail modal", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Modal Player")
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "a[href='/players/#{player.id}']")
    end

    test "player detail modal shows the player's name", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Named Player")
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "h3", player.name)
    end

    test "player detail modal contains a View profile link to the player's show page", %{
      conn: conn
    } do
      tt = Factory.team_type()
      player = Factory.player(name: "Profile Player")
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "a[href='/players/#{player.id}']")
    end

    test "firing deselect_player closes the modal", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Deselect Player")
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "a[href='/players/#{player.id}']")

      render_click(view, "deselect_player", %{})
      refute has_element?(view, "a[href='/players/#{player.id}']")
    end

    test "firing move_player closes the modal", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Move Player")
      team = Factory.team(team_type: tt, name: "Team Modal")

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "a[href='/players/#{player.id}']")

      render_click(view, "move_player", %{
        "player_id" => player.id,
        "target_id" => team.id
      })

      refute has_element?(view, "a[href='/players/#{player.id}']")
    end
  end

  # ---------------------------------------------------------------------------
  # 7.5 — Health indicators appear when rules are violated
  # ---------------------------------------------------------------------------

  describe "health indicators" do
    test "warning shown when team is below minimum roster size", %{conn: conn} do
      tt = Factory.team_type()
      Factory.season_rules(team_type: tt, min_roster: 4, max_roster: 10)
      player = Factory.player(name: "Eve Player", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(team_type: tt, name: "Small Team")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      assert html =~ "minimum"
    end

    test "warning icon shown for player with invalid NTRP on this team", %{conn: conn} do
      tt = Factory.team_type()
      # 4.5 is not in allowed_ntrp_levels for a 3.5 team
      player = Factory.player(name: "Frank Player", ntrp_rating: Decimal.new("4.5"))
      team = Factory.team(team_type: tt, name: "Team C")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      assert has_element?(view, "#player-#{player.id} span.sr-only", "Rating issue")
    end

    test "caution shown for unrated player on a team", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(traits: [:unrated], name: "Grace Player")
      team = Factory.team(team_type: tt, name: "Team D")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      assert html =~ "?"
    end

    test "no rule violations shown when no season rules exist", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Henry Player", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(team_type: tt, name: "Team E")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      refute html =~ "minimum"
      refute html =~ "maximum"
      refute html =~ "on-level"
    end
  end

  # ---------------------------------------------------------------------------
  # 8.x — Eligibility filtering for Unassigned column
  # ---------------------------------------------------------------------------

  describe "eligibility filtering" do
    test "eligible player with matching NTRP appears in Unassigned", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Alex Eligible", ntrp_rating: Decimal.new("3.5"))

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "over-rated player is excluded from Unassigned", %{conn: conn} do
      tt = Factory.team_type()
      # 4.0 is not in allowed_ntrp_levels [3.0, 3.5] for this team type
      player = Factory.player(name: "Zara Overrated", ntrp_rating: Decimal.new("4.0"))

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "under-rated player is excluded from Unassigned", %{conn: conn} do
      tt = Factory.team_type(traits: [:_40], name: "18+ 4.0")
      # 3.0 is below the 4.0 team's allowed levels
      player = Factory.player(name: "Ben Underrated", ntrp_rating: Decimal.new("3.0"))

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "nil-rated age-eligible player appears in Unassigned", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(traits: [:unrated], name: "Cam Unrated")

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "age-ineligible player is excluded from Unassigned", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(traits: [:ineligible], name: "Dana Ineligible")

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "ineligible player already assigned to a team still appears in their team column", %{
      conn: conn
    } do
      tt = Factory.team_type()
      # 4.5 is not in allowed_ntrp_levels for this 3.5 team type
      player = Factory.player(name: "Eve Assigned", ntrp_rating: Decimal.new("4.5"))
      team = Factory.team(team_type: tt, name: "Team Ineligible")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")
      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # 10.x — Delete team
  # ---------------------------------------------------------------------------

  describe "delete team" do
    test "deleting a team returns its players to Unassigned", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Frank Deleted", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(team_type: tt, name: "Doomed Team")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")

      render_click(view, "open_team_modal", %{"mode" => "delete", "team_id" => team.id})
      render_click(view, "confirm_delete_team", %{"team_id" => team.id})

      render(view)
      refute has_element?(view, "#col-#{team.id}")
      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "cancelling delete leaves the team intact", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Grace Survives", ntrp_rating: Decimal.new("3.5"))
      team = Factory.team(team_type: tt, name: "Surviving Team")

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

      render_click(view, "open_team_modal", %{"mode" => "delete", "team_id" => team.id})
      render_click(view, "close_team_modal", %{})

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # 7.6 — PubSub broadcast reaches a second subscriber session
  # ---------------------------------------------------------------------------

  describe "PubSub real-time sync" do
    test "a move made in one session is reflected in another", %{conn: conn} do
      tt = Factory.team_type()
      player = Factory.player(name: "Ivan Player")
      team = Factory.team(team_type: tt, name: "Team F")

      # Two separate LiveView connections to the same board
      {:ok, view1, _} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")
      {:ok, view2, _} = live(conn, ~p"/roster-planner/#{tt.id}/#{team.season_year}")

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
