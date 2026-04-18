defmodule TennisTrackerWeb.Matches.ShowLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.MatchHelpers

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.MatchLineupAssignment
  alias TennisTrackerWeb.LineupFormatter

  def mount(_params, _session, socket) do
    socket
    |> assign(:match, nil)
    |> assign(:lineup_slots, [])
    |> assign(:assignments, [])
    |> assign(:lineup_text, "")
    |> assign(:can_edit_lineup, false)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    with {:ok, match} <-
           Ash.get(Tennis.Match, id, domain: Tennis, tenant: group_id, actor: current_user),
         {:ok, match} <-
           Ash.load(match, [:team, location: [:formatted_address]],
             domain: Tennis,
             tenant: group_id,
             actor: current_user
           ) do
      lineup_slots =
        Tennis.list_lineup_slots_for_team!(match.team.id,
          tenant: group_id,
          actor: current_user
        )
        |> Enum.reject(&(&1.participation_type == :out))

      assignments =
        Tennis.list_assignments_for_match!(match.id,
          tenant: group_id,
          actor: current_user,
          load: [:player, :team_lineup_slot]
        )

      can_edit_lineup =
        Ash.can?(
          {MatchLineupAssignment, :create, %{group_id: group_id, match_id: match.id}},
          current_user,
          domain: Tennis,
          tenant: group_id
        )

      lineup_text = LineupFormatter.format(match, lineup_slots, assignments)

      socket
      |> assign(:match, match)
      |> assign(:lineup_slots, lineup_slots)
      |> assign(:assignments, assignments)
      |> assign(:can_edit_lineup, can_edit_lineup)
      |> assign(:lineup_text, lineup_text)
      |> noreply()
    else
      {:error, _} ->
        socket
        |> put_flash(:error, "Match not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()
    end
  end

  def handle_event("clipboard_copied", _params, socket) do
    socket |> put_flash(:info, "Copied!") |> noreply()
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
        title={format_home_or_away(@match.home_or_away, @match.opponent)}
        back_href={~p"/g/#{@current_group.slug}/teams/#{@match.team.id}"}
        back_label={@match.team.name}
      >
        <:subtitle>
          <.link
            navigate={~p"/g/#{@current_group.slug}/teams/#{@match.team.id}"}
            class="hover:underline"
          >
            {@match.team.name}
          </.link>
        </:subtitle>
        <:actions>
          <.link
            navigate={~p"/g/#{@current_group.slug}/matches/#{@match.id}/edit"}
            class="btn btn-sm btn-ghost"
          >
            Edit Match
          </.link>
        </:actions>
      </.page_header>

      <div class="max-w-lg space-y-6">
        <%!-- Match details --%>
        <div class="bg-base-200 rounded-lg p-5 space-y-4">
          <div>
            <p class="text-xs text-base-content/50 uppercase tracking-wide mb-1">Date & Time</p>
            <% {date_str, time_str} =
              format_match_datetime(@match.match_start_datetime, @match.timezone) %>
            <p class="font-medium">{date_str}</p>
            <p class="text-base-content/70">
              {time_str} ({@match.timezone})
            </p>
          </div>

          <div>
            <p class="text-xs text-base-content/50 uppercase tracking-wide mb-1">Location</p>
            <%= if @match.location do %>
              <p class="font-medium">{@match.location.name}</p>
              <p :if={@match.location.formatted_address} class="text-base-content/70">
                {@match.location.formatted_address}
              </p>
              <a
                :if={@match.location.google_maps_url}
                href={@match.location.google_maps_url}
                target="_blank"
                rel="noopener noreferrer"
                class="text-sm text-primary hover:underline inline-flex items-center gap-1 mt-1"
              >
                <.icon name="hero-map-pin" class="size-3" /> Directions
              </a>
            <% else %>
              <p class="text-base-content/50">Location TBD</p>
            <% end %>
          </div>
        </div>

        <%!-- Lineup section --%>
        <div class="bg-base-200 rounded-lg p-5">
          <div class="flex items-center justify-between mb-4">
            <h2 class="font-semibold">Lineup</h2>
            <div class="flex items-center gap-2">
              <.link
                :if={@can_edit_lineup}
                navigate={~p"/g/#{@current_group.slug}/matches/#{@match.id}/lineup-edit"}
                class="btn btn-xs btn-ghost"
              >
                Edit Lineup
              </.link>
              <button
                id="copy-lineup-btn"
                phx-hook=".CopyLineup"
                data-lineup-textarea-id="lineup-text-area"
                class="btn btn-xs btn-outline"
              >
                Copy Lineup
              </button>
            </div>
          </div>

          <%!-- Empty state: no slots defined --%>
          <div :if={@lineup_slots == []} id="lineup-empty-state">
            <p class="text-sm text-base-content/50">No lineup slots defined for this team.</p>
            <.link
              :if={@can_edit_lineup}
              navigate={~p"/g/#{@current_group.slug}/teams/#{@match.team.id}/settings"}
              class="text-sm text-primary hover:underline mt-1 inline-block"
            >
              Define slots on the team page
            </.link>
          </div>

          <%!-- Slot assignment list --%>
          <div :if={@lineup_slots != []} class="space-y-3">
            <%= for slot <- @lineup_slots do %>
              <div id={"lineup-slot-#{slot.id}"}>
                <p class="text-xs font-semibold text-base-content/60 uppercase tracking-wide">
                  {slot.name}
                </p>
                <% slot_players =
                  @assignments
                  |> Enum.filter(&(&1.team_lineup_slot_id == slot.id))
                  |> Enum.map(& &1.player)
                  |> Enum.sort_by(& &1.name) %>
                <%= if slot_players == [] do %>
                  <p class="text-sm text-base-content/40">—</p>
                <% else %>
                  <p
                    :for={player <- slot_players}
                    id={"lineup-player-#{player.id}"}
                    class="text-sm"
                  >
                    {player.name}
                  </p>
                <% end %>
              </div>
            <% end %>
          </div>

          <%!-- Hidden textarea for clipboard fallback --%>
          <textarea
            id="lineup-text-area"
            class="hidden w-full mt-4 p-2 text-sm font-mono border rounded resize-none"
            rows="10"
            readonly
          >{@lineup_text}</textarea>
        </div>
      </div>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyLineup">
      export default {
        mounted() {
          this.el.addEventListener("click", (e) => {
            e.preventDefault()
            const textareaId = this.el.dataset.lineupTextareaId
            const textarea = document.getElementById(textareaId)
            if (!textarea) return

            navigator.clipboard.writeText(textarea.value).then(() => {
              this.pushEvent("clipboard_copied", {})
            }).catch(() => {
              textarea.classList.remove("hidden")
              textarea.select()
            })
          })
        }
      }
    </script>
    """
  end
end
