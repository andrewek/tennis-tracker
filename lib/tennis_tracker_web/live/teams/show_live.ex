defmodule TennisTrackerWeb.Teams.ShowLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.BoardComponents
  import TennisTrackerWeb.MatchHelpers

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    socket
    |> assign(:team, nil)
    |> assign(:players, [])
    |> assign(:selected_player, nil)
    |> assign(:can_edit_team, false)
    |> stream(:upcoming_matches, [])
    |> stream(:past_matches, [])
    |> stream(:captains, [])
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Tennis.get_team_with_roster(id, tenant: group_id, actor: current_user) do
      {:ok, team} ->
        can_edit_team = Ash.can?({team, :update}, current_user, tenant: group_id, domain: Tennis)
        players = team.memberships |> Enum.map(& &1.player) |> Enum.sort_by(& &1.name)

        upcoming =
          Tennis.list_upcoming_matches_for_team!(team.id,
            tenant: group_id,
            actor: current_user,
            load: [:location]
          )

        past =
          Tennis.list_past_matches_for_team!(team.id,
            tenant: group_id,
            actor: current_user,
            load: [:location]
          )

        captains =
          Tennis.list_captains_for_team!(team.id,
            tenant: group_id,
            actor: current_user,
            load: [:user]
          )

        socket
        |> assign(:team, team)
        |> assign(:players, players)
        |> assign(:can_edit_team, can_edit_team)
        |> stream(:upcoming_matches, upcoming, reset: true)
        |> stream(:past_matches, past, reset: true)
        |> stream(:captains, captains, reset: true)
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Team not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()
    end
  end

  def handle_event("show_player", %{"player_id" => player_id}, socket) do
    player = Enum.find(socket.assigns.players, &(&1.id == player_id))
    socket |> assign(:selected_player, player) |> noreply()
  end

  def handle_event("close_player_modal", _params, socket) do
    socket |> assign(:selected_player, nil) |> noreply()
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
        title={@team.name}
        back_href={~p"/g/#{@current_group.slug}/teams"}
        back_label="Teams"
      >
        <:subtitle>{@team.team_type.name} · {@team.season_year}</:subtitle>
        <:actions>
          <a
            href={~p"/g/#{@current_group.slug}/teams/#{@team.id}/calendar.ics"}
            class="btn btn-sm btn-ghost"
          >
            Export Calendar
          </a>
          <.link
            :if={@can_edit_team}
            navigate={~p"/g/#{@current_group.slug}/teams/#{@team.id}/settings"}
            class="btn btn-sm btn-ghost"
          >
            Team Settings
          </.link>
        </:actions>
      </.page_header>

      <%!-- Roster + schedule: flex wrap so each column only takes the space it needs --%>
      <div class="flex flex-wrap gap-6 items-start">
        <%!-- Roster card --%>
        <div class="bg-base-200 rounded-lg p-4 flex-1 min-w-64">
          <div class="flex items-center gap-2 mb-3">
            <h2 class="font-semibold">Roster</h2>
            <span class="badge badge-xs badge-ghost">{length(@players)}</span>
          </div>

          <%= if @players == [] do %>
            <p class="text-sm text-base-content/50">No players on this roster.</p>
          <% else %>
            <div class="space-y-1">
              <.player_card
                :for={player <- @players}
                player={player}
                readonly={true}
                on_click="show_player"
              />
            </div>
          <% end %>
        </div>

        <%!-- Captains card --%>
        <div class="bg-base-200 rounded-lg p-4 min-w-48">
          <h2 class="font-semibold mb-3">Captains</h2>

          <div id="captains-list" phx-update="stream" class="space-y-1">
            <div
              :for={{dom_id, role} <- @streams.captains}
              id={dom_id}
              class="text-sm py-1"
            >
              {role.user.name || role.user.email}
            </div>
          </div>

          <p
            :if={@streams.captains.inserts == []}
            class="text-sm text-base-content/50"
          >
            No captains assigned.
          </p>
        </div>

        <%!-- Match schedule card --%>
        <div class="bg-base-200 rounded-lg p-4 flex-1 min-w-64">
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold">Upcoming Matches</h2>
          </div>

          <div id="upcoming-matches" phx-update="stream" class="space-y-3">
            <div
              :for={{dom_id, match} <- @streams.upcoming_matches}
              id={dom_id}
              class="bg-base-100 rounded px-3 py-2 text-sm"
            >
              <.link
                navigate={~p"/g/#{@current_group.slug}/matches/#{match.id}"}
                class="hover:underline"
              >
                <p class="font-medium">
                  {format_home_or_away(match.home_or_away, match.opponent)}
                </p>
              </.link>
              <p class="text-base-content/60">
                <% {date_str, time_str} =
                  format_match_datetime(match.match_start_datetime, match.timezone) %>
                {date_str} · {time_str}
              </p>
              <p class="text-base-content/60">
                <%= if match.location do %>
                  {match.location.name}
                <% else %>
                  Location TBD
                <% end %>
              </p>
            </div>
          </div>

          <p
            :if={@streams.upcoming_matches.inserts == []}
            class="text-sm text-base-content/50"
          >
            No upcoming matches scheduled.
          </p>

          <%!-- Past matches --%>
          <div class="mt-6">
            <h2 class="font-semibold mb-3">Past Matches</h2>

            <div id="past-matches" phx-update="stream" class="space-y-3">
              <div
                :for={{dom_id, match} <- @streams.past_matches}
                id={dom_id}
                class="bg-base-100 rounded px-3 py-2 text-sm opacity-70"
              >
                <.link
                  navigate={~p"/g/#{@current_group.slug}/matches/#{match.id}"}
                  class="hover:underline"
                >
                  <p class="font-medium">
                    {format_home_or_away(match.home_or_away, match.opponent)}
                  </p>
                </.link>
                <p class="text-base-content/60">
                  <% {date_str, time_str} =
                    format_match_datetime(match.match_start_datetime, match.timezone) %>
                  {date_str} · {time_str}
                </p>
                <p class="text-base-content/60">
                  <%= if match.location do %>
                    {match.location.name}
                  <% else %>
                    Location TBD
                  <% end %>
                </p>
              </div>
            </div>

            <p
              :if={@streams.past_matches.inserts == []}
              class="text-sm text-base-content/50"
            >
              No past matches.
            </p>
          </div>
        </div>
      </div>

      <%!-- Player quick-look modal --%>
      <.player_detail_modal
        :if={@selected_player}
        player={@selected_player}
        current_team={@team.name}
        group_slug={@current_group.slug}
        on_close={JS.push("close_player_modal")}
      />
    </Layouts.app>
    """
  end
end
