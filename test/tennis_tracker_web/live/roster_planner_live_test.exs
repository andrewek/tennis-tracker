defmodule TennisTrackerWeb.RosterPlannerLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp create_team_type(attrs \\ %{}) do
    defaults = %{
      name: "18+ 3.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }

    Tennis.create_team_type!(Map.merge(defaults, attrs))
  end

  defp create_season_rules(team_type, attrs) do
    defaults = %{
      team_type_id: team_type.id,
      season_year: 2026,
      min_roster: 4,
      max_roster: 10,
      on_level_min_pct: Decimal.new("0.60")
    }

    Tennis.create_season_rules!(Map.merge(defaults, attrs))
  end

  defp create_player(attrs) do
    defaults = %{name: "Test Player", eligible_18_plus: true}
    Tennis.create_player!(Map.merge(defaults, attrs))
  end

  # ---------------------------------------------------------------------------
  # 7.3 — Board loads for a valid context
  # ---------------------------------------------------------------------------

  describe "board loads" do
    test "context selector is shown at /roster-planner", %{conn: conn} do
      create_team_type()
      {:ok, _view, html} = live(conn, ~p"/roster-planner")
      assert html =~ "Select a planning session"
    end

    test "board loads for a valid team_type_id and season_year", %{conn: conn} do
      tt = create_team_type()
      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")
      assert html =~ "Unassigned"
      assert html =~ "Not Participating"
    end

    test "board shows team type name in subtitle", %{conn: conn} do
      tt =
        create_team_type(%{
          name: "40+ 4.0",
          age_group: "40_plus",
          ntrp_level: Decimal.new("4.0"),
          allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
        })

      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")
      assert html =~ "40+ 4.0"
    end

    test "unassigned players appear in the Unassigned column", %{conn: conn} do
      tt = create_team_type()
      create_player(%{name: "Alice Player"})
      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")
      assert html =~ "Alice Player"
    end
  end

  # ---------------------------------------------------------------------------
  # 7.4 — Moving a player updates the correct column
  # ---------------------------------------------------------------------------

  describe "moving players" do
    test "moving player to a team removes them from Unassigned", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Bob Smith"})

      Tennis.create_team!(%{
        name: "Team Alpha",
        team_type_id: tt.id,
        season_year: 2026,
        is_pseudo: false
      })

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")
      {:ok, teams} = Tennis.list_teams_for_context(tt.id, 2026)
      real_team = Enum.find(teams, &(not &1.is_pseudo))

      html =
        render_click(view, "move_player", %{
          "player_id" => player.id,
          "target_id" => real_team.id
        })

      assert html =~ "Team Alpha"
      # player card should now be in team column, not unassigned
      assert has_element?(view, "#col-#{real_team.id} #player-#{player.id}")
      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "moving player to Unassigned removes their membership", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Carol Player"})

      team =
        Tennis.create_team!(%{
          name: "Team B",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      render_click(view, "move_player", %{
        "player_id" => player.id,
        "target_id" => "unassigned"
      })

      render(view)
      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "moving player to Not Participating places them in that column", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Dave Player"})

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")
      {:ok, pseudo} = Tennis.ensure_pseudo_team(tt.id, 2026)

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
      tt = create_team_type()
      player = create_player(%{name: "Modal Player"})
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "[data-player-modal]")
    end

    test "player detail modal shows the player's name", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Named Player"})
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "[data-player-modal]", "Named Player")
    end

    test "player detail modal contains a View profile link to the player's show page", %{
      conn: conn
    } do
      tt = create_team_type()
      player = create_player(%{name: "Profile Player"})
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      render_click(view, "select_player", %{"player_id" => player.id})

      assert has_element?(view, "a[href='/players/#{player.id}']")
    end

    test "firing deselect_player closes the modal", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Deselect Player"})
      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "[data-player-modal]")

      render_click(view, "deselect_player", %{})
      refute has_element?(view, "[data-player-modal]")
    end

    test "firing move_player closes the modal", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Move Player"})

      team =
        Tennis.create_team!(%{
          name: "Team Modal",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      render_click(view, "select_player", %{"player_id" => player.id})
      assert has_element?(view, "[data-player-modal]")

      render_click(view, "move_player", %{
        "player_id" => player.id,
        "target_id" => team.id
      })

      refute has_element?(view, "[data-player-modal]")
    end
  end

  # ---------------------------------------------------------------------------
  # 7.5 — Health indicators appear when rules are violated
  # ---------------------------------------------------------------------------

  describe "health indicators" do
    test "warning shown when team is below minimum roster size", %{conn: conn} do
      tt = create_team_type()

      create_season_rules(tt, %{
        min_roster: 4,
        max_roster: 10,
        on_level_min_pct: Decimal.new("0.60")
      })

      player = create_player(%{name: "Eve Player", ntrp_rating: Decimal.new("3.5")})

      team =
        Tennis.create_team!(%{
          name: "Small Team",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      # 1 player, min is 4 — should show a below_min warning
      assert html =~ "minimum"
    end

    test "warning icon shown for player with invalid NTRP on this team", %{conn: conn} do
      tt = create_team_type()
      # 4.5 is not in allowed_ntrp_levels for a 3.5 team
      player = create_player(%{name: "Frank Player", ntrp_rating: Decimal.new("4.5")})

      team =
        Tennis.create_team!(%{
          name: "Team C",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      # Player card should have the warning indicator when NTRP is invalid
      assert has_element?(view, "#player-#{player.id} span[title='Rating issue']")
    end

    test "caution shown for unrated player on a team", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Grace Player"})

      team =
        Tennis.create_team!(%{
          name: "Team D",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      assert html =~ "?"
    end

    test "no rule violations shown when no season rules exist", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Henry Player", ntrp_rating: Decimal.new("3.5")})

      team =
        Tennis.create_team!(%{
          name: "Team E",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, _view, html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

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
      tt = create_team_type()

      player =
        create_player(%{
          name: "Alex Eligible",
          ntrp_rating: Decimal.new("3.5"),
          eligible_18_plus: true
        })

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "over-rated player is excluded from Unassigned", %{conn: conn} do
      tt = create_team_type()
      # 4.0 is not in allowed_ntrp_levels [3.0, 3.5] for this team type
      player =
        create_player(%{
          name: "Zara Overrated",
          ntrp_rating: Decimal.new("4.0"),
          eligible_18_plus: true
        })

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "under-rated player is excluded from Unassigned", %{conn: conn} do
      tt =
        create_team_type(%{
          name: "18+ 4.0",
          age_group: "18_plus",
          ntrp_level: Decimal.new("4.0"),
          allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
        })

      # 3.0 is below the 4.0 team's allowed levels
      player =
        create_player(%{
          name: "Ben Underrated",
          ntrp_rating: Decimal.new("3.0"),
          eligible_18_plus: true
        })

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "nil-rated age-eligible player appears in Unassigned", %{conn: conn} do
      tt = create_team_type()
      player = create_player(%{name: "Cam Unrated", ntrp_rating: nil, eligible_18_plus: true})

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "age-ineligible player is excluded from Unassigned", %{conn: conn} do
      tt = create_team_type()
      # eligible_18_plus: false means they can't play on 18+ teams
      player =
        create_player(%{
          name: "Dana Ineligible",
          ntrp_rating: Decimal.new("3.5"),
          eligible_18_plus: false
        })

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "ineligible player already assigned to a team still appears in their team column", %{
      conn: conn
    } do
      tt = create_team_type()
      # 4.5 is not in allowed_ntrp_levels for this 3.5 team type
      player =
        create_player(%{
          name: "Eve Assigned",
          ntrp_rating: Decimal.new("4.5"),
          eligible_18_plus: true
        })

      team =
        Tennis.create_team!(%{
          name: "Team Ineligible",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")
      refute has_element?(view, "#col-unassigned #player-#{player.id}")
    end
  end

  # ---------------------------------------------------------------------------
  # 10.x — Delete team
  # ---------------------------------------------------------------------------

  describe "delete team" do
    test "deleting a team returns its players to Unassigned", %{conn: conn} do
      tt = create_team_type()

      player =
        create_player(%{
          name: "Frank Deleted",
          ntrp_rating: Decimal.new("3.5"),
          eligible_18_plus: true
        })

      team =
        Tennis.create_team!(%{
          name: "Doomed Team",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      assert has_element?(view, "#col-#{team.id} #player-#{player.id}")

      render_click(view, "open_team_modal", %{"mode" => "delete", "team_id" => team.id})
      render_click(view, "confirm_delete_team", %{"team_id" => team.id})

      render(view)
      refute has_element?(view, "#col-#{team.id}")
      assert has_element?(view, "#col-unassigned #player-#{player.id}")
    end

    test "cancelling delete leaves the team intact", %{conn: conn} do
      tt = create_team_type()

      player =
        create_player(%{
          name: "Grace Survives",
          ntrp_rating: Decimal.new("3.5"),
          eligible_18_plus: true
        })

      team =
        Tennis.create_team!(%{
          name: "Surviving Team",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      Tennis.assign_player(player.id, team.id, tt.id, 2026)

      {:ok, view, _html} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

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
      tt = create_team_type()
      player = create_player(%{name: "Ivan Player"})

      team =
        Tennis.create_team!(%{
          name: "Team F",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: false
        })

      # Two separate LiveView connections to the same board
      {:ok, view1, _} = live(conn, ~p"/roster-planner/#{tt.id}/2026")
      {:ok, view2, _} = live(conn, ~p"/roster-planner/#{tt.id}/2026")

      # Move player in view1
      render_click(view1, "move_player", %{
        "player_id" => player.id,
        "target_id" => team.id
      })

      render(view1)
      # view2 should reflect the change
      html2 = render(view2)
      assert has_element?(view2, "#col-#{team.id} #player-#{player.id}")
      assert html2 =~ "Ivan Player"
    end
  end
end
