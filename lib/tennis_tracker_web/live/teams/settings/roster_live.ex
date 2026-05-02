defmodule TennisTrackerWeb.Teams.Settings.RosterLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.TeamMembership
  alias TennisTrackerWeb.TeamComponents
  alias TennisTrackerWeb.Teams.Settings.Helpers

  require Ash.Query

  def mount(_params, _session, socket) do
    socket
    |> assign(:team, nil)
    |> assign(:season_rules, nil)
    |> assign(:can_manage_roster, false)
    |> assign(:member_count, 0)
    |> assign(:on_level_count, 0)
    |> assign(:on_level_pct_display, nil)
    |> assign(:on_level_below_threshold, false)
    |> assign(:show_add_panel, false)
    |> assign(:selected_candidate_id, nil)
    |> assign(:selected_candidate_name, nil)
    |> assign(:selected_candidate_ntrp, nil)
    |> assign(:eligibility_unknown, false)
    |> assign(:eligibility_warning, nil)
    |> assign(:on_level_impact_display, nil)
    |> assign(:on_level_below_threshold_after_add, false)
    |> assign(:add_error, nil)
    |> assign(:remove_pending_membership, nil)
    |> assign(:remove_error, nil)
    |> stream(:members, [])
    |> stream(:candidate_players, [])
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Helpers.load_team_settings(id, group_id, current_user) do
      {:ok, assigns} ->
        team = assigns.team

        can_manage_roster =
          Ash.can?(
            {TeamMembership, :add_to_roster, %{team_id: team.id, group_id: group_id}},
            current_user,
            domain: Tennis,
            tenant: group_id
          )

        if can_manage_roster do
          memberships =
            Tennis.list_memberships_for_team!(team.id,
              tenant: group_id,
              actor: current_user,
              load: [:player]
            )

          season_rules =
            case Tennis.get_season_rules_for_context(team.team_type_id, team.season_year,
                   tenant: group_id,
                   actor: current_user
                 ) do
              {:ok, rules} -> rules
              _ -> nil
            end

          {member_count, on_level_count, on_level_pct_display, on_level_below_threshold} =
            compute_health(memberships, team, season_rules)

          candidates = load_candidates(memberships, group_id, current_user)

          socket
          |> assign(assigns)
          |> assign(:page_title, "#{team.name} · Roster")
          |> assign(:can_manage_roster, can_manage_roster)
          |> assign(:season_rules, season_rules)
          |> assign(:member_count, member_count)
          |> assign(:on_level_count, on_level_count)
          |> assign(:on_level_pct_display, on_level_pct_display)
          |> assign(:on_level_below_threshold, on_level_below_threshold)
          |> stream(:members, memberships, reset: true)
          |> stream(:candidate_players, candidates, reset: true)
          |> noreply()
        else
          socket
          |> put_flash(:error, "You don't have permission to manage this team's roster.")
          |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams/#{id}")
          |> noreply()
        end

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Team not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You don't have permission to manage this team's roster.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams/#{id}")
        |> noreply()
    end
  end

  def handle_event("open_add_panel", _params, socket) do
    socket |> assign(:show_add_panel, true) |> noreply()
  end

  def handle_event("close_add_panel", _params, socket) do
    socket
    |> assign(:show_add_panel, false)
    |> clear_candidate_selection()
    |> noreply()
  end

  def handle_event("select_candidate", params, socket) do
    team = socket.assigns.team
    season_rules = socket.assigns.season_rules
    on_level_count = socket.assigns.on_level_count
    member_count = socket.assigns.member_count

    ntrp =
      case params["ntrp_rating"] do
        n when n in ["", nil] -> nil
        val -> Decimal.new(val)
      end

    allowed_levels = team.team_type.allowed_ntrp_levels
    ntrp_level = team.team_type.ntrp_level

    {eligibility_unknown, eligibility_warning} =
      cond do
        is_nil(ntrp) ->
          {true, nil}

        not Enum.any?(allowed_levels, &Decimal.eq?(&1, ntrp)) ->
          {false,
           "This player's rating (#{ntrp}) is not in the allowed NTRP levels for this team type."}

        true ->
          {false, nil}
      end

    {on_level_impact_display, on_level_below_threshold_after_add} =
      if season_rules do
        new_count = member_count + 1

        new_on_level =
          if not is_nil(ntrp) and Decimal.eq?(ntrp, ntrp_level) do
            on_level_count + 1
          else
            on_level_count
          end

        projected_pct = Decimal.div(new_on_level, new_count)

        projected_display =
          projected_pct |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_string()

        below = Decimal.compare(projected_pct, season_rules.on_level_min_pct) == :lt
        {projected_display, below}
      else
        {nil, false}
      end

    socket
    |> assign(:selected_candidate_id, params["player_id"])
    |> assign(:selected_candidate_name, params["player_name"])
    |> assign(:selected_candidate_ntrp, ntrp)
    |> assign(:eligibility_unknown, eligibility_unknown)
    |> assign(:eligibility_warning, eligibility_warning)
    |> assign(:on_level_impact_display, on_level_impact_display)
    |> assign(:on_level_below_threshold_after_add, on_level_below_threshold_after_add)
    |> assign(:add_error, nil)
    |> noreply()
  end

  def handle_event("confirm_add", _params, socket) do
    player_id = socket.assigns.selected_candidate_id

    if is_nil(player_id) do
      socket |> noreply()
    else
      %{
        current_user: current_user,
        current_group_id: group_id,
        team: team
      } = socket.assigns

      result =
        Tennis.add_to_roster(
          %{
            player_id: player_id,
            team_id: team.id,
            team_type_id: team.team_type_id,
            season_year: team.season_year,
            group_id: group_id
          },
          tenant: group_id,
          actor: current_user
        )

      case result do
        {:ok, _membership} ->
          socket
          |> reload_roster_data()
          |> assign(:show_add_panel, false)
          |> clear_candidate_selection()
          |> noreply()

        {:error, _error} ->
          socket
          |> assign(
            :add_error,
            "Could not add player. They may already be assigned to another team for this season."
          )
          |> noreply()
      end
    end
  end

  def handle_event("remove_member", %{"membership_id" => id, "player_name" => name}, socket) do
    socket
    |> assign(:remove_pending_membership, %{id: id, player_name: name})
    |> assign(:remove_error, nil)
    |> noreply()
  end

  def handle_event("confirm_remove", _params, socket) do
    %{
      current_user: current_user,
      current_group_id: group_id,
      remove_pending_membership: pending
    } = socket.assigns

    case Ash.get(TeamMembership, pending.id,
           domain: Tennis,
           tenant: group_id,
           actor: current_user
         ) do
      {:ok, membership} ->
        case Tennis.remove_from_roster(membership, tenant: group_id, actor: current_user) do
          :ok ->
            socket
            |> reload_roster_data()
            |> assign(:remove_pending_membership, nil)
            |> assign(:remove_error, nil)
            |> noreply()

          {:error, error} ->
            socket |> assign(:remove_error, remove_error_message(error)) |> noreply()
        end

      {:error, _} ->
        socket
        |> assign(:remove_error, "Could not find the membership record. Please refresh.")
        |> noreply()
    end
  end

  def handle_event("cancel_remove", _params, socket) do
    socket
    |> assign(:remove_pending_membership, nil)
    |> assign(:remove_error, nil)
    |> noreply()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <.page_header
        title="Team Settings"
        back_href={~p"/g/#{@current_group.slug}/teams/#{@team.id}"}
        back_label={@team.name}
      >
        <:subtitle>{@team.team_type.name} · {@team.season_year}</:subtitle>
      </.page_header>

      <TeamComponents.settings_layout
        current_page={:roster}
        team={@team}
        current_group={@current_group}
      >
        <%!-- Health summary --%>
        <div class="bg-base-200 rounded p-4 mb-6 flex flex-wrap gap-6">
          <div :if={@on_level_pct_display}>
            <p class="text-xs text-base-content/60 mb-1">On-Level %</p>
            <p class={["text-lg font-semibold", @on_level_below_threshold && "text-warning"]}>
              {@on_level_pct_display}%
              <span :if={@on_level_below_threshold} class="text-xs font-normal">
                (below target)
              </span>
            </p>
          </div>

          <div :if={@season_rules}>
            <p class="text-xs text-base-content/60 mb-1">Roster Size</p>
            <p class={[
              "text-lg font-semibold",
              @season_rules && @member_count < @season_rules.min_roster && "text-warning",
              @season_rules && @member_count > @season_rules.max_roster && "text-warning"
            ]}>
              {@member_count}
              <span class="text-sm font-normal text-base-content/60">
                / {@season_rules.min_roster}–{@season_rules.max_roster}
              </span>
            </p>
          </div>

          <div :if={is_nil(@on_level_pct_display) and is_nil(@season_rules)}>
            <p class="text-sm text-base-content/50">No health data — roster is empty.</p>
          </div>
        </div>

        <%!-- Roster header --%>
        <div class="flex justify-between items-center mb-3">
          <h2 class="font-semibold">Players ({@member_count})</h2>
          <button
            :if={@can_manage_roster and not @show_add_panel}
            phx-click="open_add_panel"
            class="btn btn-sm btn-primary"
          >
            Add Player
          </button>
        </div>

        <%!-- Member list --%>
        <div id="members-list" phx-update="stream" class="space-y-1 mb-4">
          <div
            :for={{dom_id, membership} <- @streams.members}
            id={dom_id}
            class="bg-base-200 rounded px-3 py-2 text-sm flex items-center justify-between"
          >
            <span>
              {membership.player.name}
              <span class="text-base-content/50 ml-2">
                {membership.player.ntrp_rating || "No rating"}
              </span>
            </span>
            <button
              :if={@can_manage_roster}
              phx-click="remove_member"
              phx-value-membership_id={membership.id}
              phx-value-player_name={membership.player.name}
              class="btn btn-xs btn-ghost text-error"
            >
              Remove
            </button>
          </div>
        </div>

        <p :if={@member_count == 0} class="text-sm text-base-content/50 mb-4">
          No players on this roster yet.
        </p>

        <%!-- Add player panel --%>
        <div :if={@show_add_panel} class="border border-base-300 rounded p-4 mt-4">
          <div class="flex justify-between items-center mb-3">
            <h3 class="font-semibold text-sm">Add Player</h3>
            <button phx-click="close_add_panel" class="btn btn-xs btn-ghost">Cancel</button>
          </div>

          <div id="candidate-list" phx-update="stream" class="space-y-1 mb-4 max-h-64 overflow-y-auto">
            <button
              :for={{dom_id, player} <- @streams.candidate_players}
              id={dom_id}
              phx-click="select_candidate"
              phx-value-player_id={player.id}
              phx-value-player_name={player.name}
              phx-value-ntrp_rating={player.ntrp_rating || ""}
              class={[
                "w-full text-left bg-base-200 rounded px-3 py-2 text-sm flex justify-between hover:bg-base-300",
                @selected_candidate_id == player.id && "ring-2 ring-primary"
              ]}
            >
              <span>{player.name}</span>
              <span class="text-base-content/50">{player.ntrp_rating || "No rating"}</span>
            </button>
          </div>

          <%!-- Selection warnings --%>
          <div :if={@selected_candidate_id} class="space-y-2 mb-4">
            <div :if={@eligibility_unknown} class="alert alert-info text-sm py-2">
              Rating unknown — eligibility cannot be verified.
            </div>
            <div :if={@eligibility_warning} class="alert alert-warning text-sm py-2">
              {@eligibility_warning}
            </div>
            <div :if={@on_level_below_threshold_after_add} class="alert alert-warning text-sm py-2">
              Adding this player would drop on-level percentage to {@on_level_impact_display}%, below the required threshold.
            </div>
            <div :if={@add_error} class="alert alert-error text-sm py-2">
              {@add_error}
            </div>
          </div>

          <button
            phx-click="confirm_add"
            disabled={is_nil(@selected_candidate_id)}
            class="btn btn-sm btn-primary"
          >
            Add {if @selected_candidate_name, do: @selected_candidate_name, else: "Player"}
          </button>
        </div>
      </TeamComponents.settings_layout>

      <%!-- Remove confirmation modal --%>
      <.modal
        :if={@remove_pending_membership}
        title="Remove Player"
        on_close="cancel_remove"
      >
        <p class="text-sm text-base-content/70 mb-4">
          Remove <strong>{@remove_pending_membership.player_name}</strong> from this roster?
        </p>

        <div :if={@remove_error} class="alert alert-error text-sm py-2 mb-4">
          {@remove_error}
        </div>

        <div class="flex flex-col gap-2">
          <button phx-click="confirm_remove" class="btn btn-error">Remove from Roster</button>
          <button phx-click="cancel_remove" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  defp reload_roster_data(socket) do
    %{
      current_user: current_user,
      current_group_id: group_id,
      team: team,
      season_rules: season_rules
    } = socket.assigns

    memberships =
      Tennis.list_memberships_for_team!(team.id,
        tenant: group_id,
        actor: current_user,
        load: [:player]
      )

    {member_count, on_level_count, on_level_pct_display, on_level_below_threshold} =
      compute_health(memberships, team, season_rules)

    candidates = load_candidates(memberships, group_id, current_user)

    socket
    |> assign(:member_count, member_count)
    |> assign(:on_level_count, on_level_count)
    |> assign(:on_level_pct_display, on_level_pct_display)
    |> assign(:on_level_below_threshold, on_level_below_threshold)
    |> stream(:members, memberships, reset: true)
    |> stream(:candidate_players, candidates, reset: true)
  end

  defp load_candidates(memberships, group_id, current_user) do
    existing_player_ids = Enum.map(memberships, & &1.player_id)

    TennisTracker.Tennis.Player
    |> Ash.Query.filter(id not in ^existing_player_ids)
    |> Ash.Query.sort(:name)
    |> Ash.read!(domain: Tennis, tenant: group_id, actor: current_user)
  end

  defp compute_health(memberships, team, season_rules) do
    count = length(memberships)

    if count > 0 do
      on_level_count =
        Enum.count(memberships, fn m ->
          not is_nil(m.player.ntrp_rating) and
            Decimal.eq?(m.player.ntrp_rating, team.team_type.ntrp_level)
        end)

      on_level_pct =
        on_level_count
        |> Decimal.new()
        |> Decimal.div(Decimal.new(count))

      pct_display = on_level_pct |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_string()

      below_threshold =
        case season_rules do
          nil -> false
          rules -> Decimal.compare(on_level_pct, rules.on_level_min_pct) == :lt
        end

      {count, on_level_count, pct_display, below_threshold}
    else
      {0, 0, nil, false}
    end
  end

  defp clear_candidate_selection(socket) do
    socket
    |> assign(:selected_candidate_id, nil)
    |> assign(:selected_candidate_name, nil)
    |> assign(:selected_candidate_ntrp, nil)
    |> assign(:eligibility_unknown, false)
    |> assign(:eligibility_warning, nil)
    |> assign(:on_level_impact_display, nil)
    |> assign(:on_level_below_threshold_after_add, false)
    |> assign(:add_error, nil)
  end

  defp remove_error_message(%Ash.Error.Invalid{errors: errors}) do
    case errors do
      [%{field: :player_id, message: msg} | _] ->
        "Cannot remove: player #{msg}."

      _ ->
        "Could not remove player."
    end
  end

  defp remove_error_message(_), do: "Could not remove player."
end
