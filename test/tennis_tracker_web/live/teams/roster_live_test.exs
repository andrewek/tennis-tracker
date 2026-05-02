defmodule TennisTrackerWeb.Teams.Settings.RosterLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.MatchLineupAssignment

  require Ash.Query

  setup :setup_group_with_owner

  setup %{group: grp, user: owner} do
    tt =
      Factory.team_type(
        group: grp,
        ntrp_level: Decimal.new("3.5"),
        allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
      )

    team = Factory.team(group: grp, team_type: tt)

    captain_user = Factory.user()
    Factory.group_membership(group: grp, user: captain_user)
    Factory.team_role(group: grp, user: captain_user, team: team, traits: [:captain])

    member_user = Factory.user()
    Factory.group_membership(group: grp, user: member_user)

    {:ok, team: team, team_type: tt, owner: owner, captain: captain_user, member: member_user}
  end

  # ---------------------------------------------------------------------------
  # 5.1 — Basic access and member list
  # ---------------------------------------------------------------------------

  describe "access — team captain" do
    test "loads the Roster tab", %{conn: conn, group: grp, captain: captain, team: team} do
      conn = log_in_user(conn, captain)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, "h2", "Players")
    end
  end

  describe "access — group owner" do
    test "loads the Roster tab", %{conn: conn, group: grp, user: owner, team: team} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, "h2", "Players")
    end
  end

  describe "access — regular group member" do
    test "is redirected to the team show page", %{
      conn: conn,
      group: grp,
      member: member,
      team: team
    } do
      conn = log_in_user(conn, member)

      {:error, {:live_redirect, %{to: to}}} =
        live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert to == ~p"/g/#{grp.slug}/teams/#{team.id}"
    end
  end

  describe "member list — with members" do
    test "shows each member's name and NTRP rating", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      player = Factory.player(group: grp, name: "Alice Archer", ntrp_rating: Decimal.new("3.5"))
      Factory.team_membership(group: grp, player: player, team: team)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, "#members-list", "Alice Archer")
      assert has_element?(view, "#members-list", "3.5")
    end
  end

  describe "member list — empty roster" do
    test "shows the empty state message", %{conn: conn, group: grp, user: owner, team: team} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, "p", "No players on this roster yet")
    end
  end

  describe "health summary — with SeasonRules" do
    test "shows roster size and on-level percentage", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team,
      team_type: tt
    } do
      Factory.season_rules(
        group: grp,
        team_type: tt,
        min_roster: 4,
        max_roster: 10,
        on_level_min_pct: Decimal.new("0.60")
      )

      on_level_player = Factory.player(group: grp, ntrp_rating: Decimal.new("3.5"))
      off_level_player = Factory.player(group: grp, ntrp_rating: Decimal.new("3.0"))
      Factory.team_membership(group: grp, player: on_level_player, team: team)
      Factory.team_membership(group: grp, player: off_level_player, team: team)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, "[data-role=roster-size], .bg-base-200", "4")
      assert has_element?(view, ".bg-base-200", "50%")
    end
  end

  describe "health summary — no SeasonRules, members present" do
    test "shows on-level percentage but no roster size targets", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      player = Factory.player(group: grp, ntrp_rating: Decimal.new("3.5"))
      Factory.team_membership(group: grp, player: player, team: team)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, ".bg-base-200", "100%")
      refute has_element?(view, ".bg-base-200", "–")
    end
  end

  describe "tab navigation" do
    test "Roster tab is highlighted as active", %{conn: conn, group: grp, user: owner, team: team} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, ".tab.tab-active", "Roster")
    end

    test "all five tabs are rendered", %{conn: conn, group: grp, user: owner, team: team} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, ".tab", "General")
      assert has_element?(view, ".tab", "Match Schedule")
      assert has_element?(view, ".tab", "Lineup Settings")
      assert has_element?(view, ".tab", "Roster")
      assert has_element?(view, ".tab", "Members")
    end
  end

  # ---------------------------------------------------------------------------
  # 5.2 — Add player flow
  # ---------------------------------------------------------------------------

  describe "add player — eligibility warning for ineligible NTRP" do
    test "shows warning when selected player's NTRP is not in allowed levels", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      ineligible =
        Factory.player(group: grp, name: "Ineligible Player", ntrp_rating: Decimal.new("4.5"))

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      view |> render_hook("open_add_panel", %{})

      view
      |> render_hook("select_candidate", %{
        "player_id" => ineligible.id,
        "player_name" => "Ineligible Player",
        "ntrp_rating" => "4.5"
      })

      assert has_element?(view, ".alert-warning", "not in the allowed NTRP levels")
    end
  end

  describe "add player — rating unknown note for nil NTRP" do
    test "shows unknown rating note when player has no NTRP rating", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      unrated = Factory.player(group: grp, traits: [:unrated], name: "Unrated Player")

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      view |> render_hook("open_add_panel", %{})

      view
      |> render_hook("select_candidate", %{
        "player_id" => unrated.id,
        "player_name" => "Unrated Player",
        "ntrp_rating" => ""
      })

      assert has_element?(view, ".alert-info", "Rating unknown")
    end
  end

  describe "add player — on-level warning when threshold would be broken" do
    test "shows warning when adding an off-level player would drop below threshold", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team,
      team_type: tt
    } do
      Factory.season_rules(
        group: grp,
        team_type: tt,
        min_roster: 4,
        max_roster: 10,
        on_level_min_pct: Decimal.new("0.75")
      )

      on_level = Factory.player(group: grp, ntrp_rating: Decimal.new("3.5"))
      Factory.team_membership(group: grp, player: on_level, team: team)

      off_level =
        Factory.player(group: grp, name: "Off Level Player", ntrp_rating: Decimal.new("3.0"))

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      view |> render_hook("open_add_panel", %{})

      view
      |> render_hook("select_candidate", %{
        "player_id" => off_level.id,
        "player_name" => "Off Level Player",
        "ntrp_rating" => "3.0"
      })

      assert has_element?(view, ".alert-warning", "below the required threshold")
    end
  end

  describe "add player — successful add" do
    test "creates the membership and player appears in roster", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      new_player = Factory.player(group: grp, name: "New Player", ntrp_rating: Decimal.new("3.5"))

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      view |> render_hook("open_add_panel", %{})

      view
      |> render_hook("select_candidate", %{
        "player_id" => new_player.id,
        "player_name" => "New Player",
        "ntrp_rating" => "3.5"
      })

      view |> render_hook("confirm_add", %{})

      assert has_element?(view, "#members-list", "New Player")
      refute has_element?(view, "#candidate-list", "New Player")
    end
  end

  # ---------------------------------------------------------------------------
  # 5.3 — Remove player flow
  # ---------------------------------------------------------------------------

  describe "remove player — successful remove" do
    test "destroys the membership and player no longer appears", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      player = Factory.player(group: grp, name: "Removable Player")
      membership = Factory.team_membership(group: grp, player: player, team: team)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      assert has_element?(view, "#members-list", "Removable Player")

      view
      |> render_hook("remove_member", %{
        "membership_id" => membership.id,
        "player_name" => "Removable Player"
      })

      view |> render_hook("confirm_remove", %{})

      refute has_element?(view, "#members-list", "Removable Player")
    end
  end

  describe "remove player — player assigned to a match lineup" do
    test "shows inline error and does not remove the membership", %{
      conn: conn,
      group: grp,
      user: owner
    } do
      tt = Factory.team_type(group: grp)
      team = Factory.team(group: grp, team_type: tt)
      player = Factory.player(group: grp, name: "Assigned Player")
      membership = Factory.team_membership(group: grp, player: player, team: team)
      match = Factory.match(group: grp, team: team)

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
      slot = Enum.find(slots, &(&1.participation_type == :playing))

      MatchLineupAssignment
      |> Ash.Changeset.for_create(
        :create,
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot.id,
          group_id: grp.id
        },
        domain: Tennis,
        tenant: grp.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      view
      |> render_hook("remove_member", %{
        "membership_id" => membership.id,
        "player_name" => "Assigned Player"
      })

      view |> render_hook("confirm_remove", %{})

      assert has_element?(view, ".alert-error", "assigned to a match lineup")

      memberships = Tennis.list_memberships_for_team!(team.id, tenant: grp.id, authorize?: false)
      assert Enum.any?(memberships, &(&1.player_id == player.id))
    end
  end

  describe "remove player — cancel" do
    test "leaves the membership intact", %{conn: conn, group: grp, user: owner, team: team} do
      player = Factory.player(group: grp, name: "Cancellable Player")
      membership = Factory.team_membership(group: grp, player: player, team: team)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/settings/roster")

      view
      |> render_hook("remove_member", %{
        "membership_id" => membership.id,
        "player_name" => "Cancellable Player"
      })

      view |> render_hook("cancel_remove", %{})

      assert has_element?(view, "#members-list", "Cancellable Player")
      refute has_element?(view, "button", "Remove from Roster")
    end
  end
end
