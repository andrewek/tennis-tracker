defmodule TennisTrackerWeb.Teams.EditLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.MatchHelpers

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Match, Team}

  @us_timezones [
    {"Eastern", "America/New_York"},
    {"Central", "America/Chicago"},
    {"Mountain", "America/Denver"},
    {"Mountain (no DST)", "America/Phoenix"},
    {"Pacific", "America/Los_Angeles"},
    {"Alaska", "America/Anchorage"},
    {"Hawaii", "Pacific/Honolulu"}
  ]

  def mount(_params, _session, socket) do
    socket
    |> assign(:team, nil)
    |> assign(:team_form, nil)
    |> assign(:show_match_form, false)
    |> assign(:match_form, nil)
    |> assign(:locations, [])
    |> assign(:team_timezone, "America/Chicago")
    |> assign(:match_to_delete, nil)
    |> stream(:upcoming_matches, [])
    |> stream(:past_matches, [])
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Ash.get(Team, id, domain: Tennis, tenant: group_id, actor: current_user) do
      {:ok, team} when team.is_pseudo ->
        socket
        |> put_flash(:error, "Team not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()

      {:ok, team} ->
        if Ash.can?({team, :update}, current_user, tenant: group_id, domain: Tennis) do
          {:ok, team} =
            Ash.load(team, [:team_type], domain: Tennis, tenant: group_id, actor: current_user)

          team_form =
            AshPhoenix.Form.for_update(team, :update,
              domain: Tennis,
              actor: current_user,
              tenant: group_id,
              forms: [auto?: true]
            )
            |> to_form()

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

          socket
          |> assign(:team, team)
          |> assign(:team_form, team_form)
          |> assign(:team_timezone, team.default_timezone || "America/Chicago")
          |> stream(:upcoming_matches, upcoming, reset: true)
          |> stream(:past_matches, past, reset: true)
          |> noreply()
        else
          socket
          |> put_flash(:error, "You don't have permission to edit this team.")
          |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams/#{team.id}")
          |> noreply()
        end

      {:error, _} ->
        socket
        |> put_flash(:error, "Team not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()
    end
  end

  def handle_event("validate_team", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.team_form, params)
    socket |> assign(:team_form, form) |> noreply()
  end

  def handle_event("save_team", %{"form" => params}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.team_form, params: params) do
      {:ok, team} ->
        {:ok, team} =
          Ash.load(team, [:team_type], domain: Tennis, tenant: group_id, actor: current_user)

        team_form =
          AshPhoenix.Form.for_update(team, :update,
            domain: Tennis,
            actor: current_user,
            tenant: group_id,
            forms: [auto?: true]
          )
          |> to_form()

        socket
        |> assign(:team, team)
        |> assign(:team_form, team_form)
        |> assign(:team_timezone, team.default_timezone || "America/Chicago")
        |> put_flash(:info, "Team updated.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:team_form, form) |> noreply()
    end
  end

  def handle_event("open_match_form", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    form =
      AshPhoenix.Form.for_create(Match, :create,
        domain: Tennis,
        actor: current_user,
        tenant: group_id,
        forms: [auto?: true]
      )
      |> to_form()

    locations = Tennis.list_locations!(tenant: group_id, actor: current_user)

    socket
    |> assign(:show_match_form, true)
    |> assign(:match_form, form)
    |> assign(:locations, locations)
    |> noreply()
  end

  def handle_event("close_match_form", _params, socket) do
    socket
    |> assign(:show_match_form, false)
    |> assign(:match_form, nil)
    |> noreply()
  end

  def handle_event("validate_match", %{"form" => params}, socket) do
    timezone = socket.assigns.team_timezone
    date_str = params["match_date"]
    time_str = params["match_time"]

    params =
      case build_match_datetime_params(date_str, time_str, timezone) do
        {:ok, utc_dt} ->
          params
          |> Map.put("match_start_datetime", DateTime.to_iso8601(utc_dt))
          |> Map.put("timezone", timezone)

        {:error, _} ->
          params
      end

    form = AshPhoenix.Form.validate(socket.assigns.match_form, params)
    socket |> assign(:match_form, form) |> noreply()
  end

  def handle_event("save_match", %{"form" => params}, socket) do
    team = socket.assigns.team
    timezone = socket.assigns.team_timezone
    date_str = params["match_date"]
    time_str = params["match_time"]
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case build_match_datetime_params(date_str, time_str, timezone) do
      {:error, _} ->
        socket
        |> put_flash(:error, "Date or time is invalid — please check the values you entered")
        |> noreply()

      {:ok, utc_dt} ->
        params_with_datetime =
          params
          |> Map.put("match_start_datetime", DateTime.to_iso8601(utc_dt))
          |> Map.put("timezone", timezone)
          |> Map.put("team_id", team.id)
          |> Map.put("group_id", group_id)

        case AshPhoenix.Form.submit(socket.assigns.match_form, params: params_with_datetime) do
          {:ok, _match} ->
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

            socket
            |> assign(:show_match_form, false)
            |> assign(:match_form, nil)
            |> stream(:upcoming_matches, upcoming, reset: true)
            |> stream(:past_matches, past, reset: true)
            |> put_flash(:info, "Match added.")
            |> noreply()

          {:error, form} ->
            socket |> assign(:match_form, form) |> noreply()
        end
    end
  end

  def handle_event("show_delete_match_modal", %{"match_id" => match_id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    match = Ash.get!(Match, match_id, domain: Tennis, tenant: group_id, actor: current_user)
    socket |> assign(:match_to_delete, match) |> noreply()
  end

  def handle_event("hide_delete_match_modal", _params, socket) do
    socket |> assign(:match_to_delete, nil) |> noreply()
  end

  def handle_event("delete_match", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    Tennis.destroy_match!(socket.assigns.match_to_delete, tenant: group_id, actor: current_user)
    team = socket.assigns.team

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

    socket
    |> stream(:upcoming_matches, upcoming, reset: true)
    |> stream(:past_matches, past, reset: true)
    |> assign(:match_to_delete, nil)
    |> put_flash(:info, "Match deleted.")
    |> noreply()
  end

  defp format_home_or_away(:home, opponent), do: "HOME v. #{opponent}"
  defp format_home_or_away(:away, opponent), do: "AWAY v. #{opponent}"

  def render(assigns) do
    assigns = assign(assigns, :us_timezones, @us_timezones)

    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_group={@current_group}>
      <.page_header
        title="Edit Team"
        back_href={~p"/g/#{@current_group.slug}/teams/#{@team.id}"}
        back_label={@team.name}
      >
        <:subtitle>{@team.team_type.name} · {@team.season_year}</:subtitle>
      </.page_header>

      <div class="flex flex-wrap gap-6 items-start">
        <%!-- Team settings form --%>
        <div class="bg-base-200 rounded-lg p-4 w-full max-w-sm">
          <h2 class="font-semibold mb-4">Team Settings</h2>
          <.form for={@team_form} phx-change="validate_team" phx-submit="save_team">
            <.input field={@team_form[:name]} type="text" label="Team Name" />
            <.input
              field={@team_form[:default_timezone]}
              type="select"
              label="Timezone"
              options={@us_timezones}
            />
            <div class="mt-4">
              <button type="submit" class="btn btn-primary btn-sm">Save Team</button>
            </div>
          </.form>
        </div>

        <%!-- Match schedule --%>
        <div class="bg-base-200 rounded-lg p-4 w-full max-w-md">
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold">Upcoming Matches</h2>
            <button class="btn btn-xs btn-ghost" phx-click="open_match_form">
              <.icon name="hero-plus" class="size-3 inline" /> Add Match
            </button>
          </div>

          <div id="upcoming-matches" phx-update="stream" class="space-y-3">
            <div
              :for={{dom_id, match} <- @streams.upcoming_matches}
              id={dom_id}
              class="bg-base-100 rounded px-3 py-2 text-sm"
            >
              <p class="font-medium">
                {format_home_or_away(match.home_or_away, match.opponent)}
              </p>
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
              <div class="flex gap-2 mt-1">
                <.link
                  navigate={~p"/g/#{@current_group.slug}/matches/#{match.id}/edit"}
                  class="text-xs text-primary hover:underline"
                >
                  Edit
                </.link>
                <button
                  phx-click="show_delete_match_modal"
                  phx-value-match_id={match.id}
                  class="text-xs text-error hover:underline"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>

          <p
            :if={@streams.upcoming_matches.inserts == []}
            class="text-sm text-base-content/50"
          >
            No upcoming matches scheduled.
          </p>

          <div class="mt-6">
            <h2 class="font-semibold mb-3">Past Matches</h2>

            <div id="past-matches" phx-update="stream" class="space-y-3">
              <div
                :for={{dom_id, match} <- @streams.past_matches}
                id={dom_id}
                class="bg-base-100 rounded px-3 py-2 text-sm opacity-70"
              >
                <p class="font-medium">
                  {format_home_or_away(match.home_or_away, match.opponent)}
                </p>
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
                <div class="flex gap-2 mt-1">
                  <.link
                    navigate={~p"/g/#{@current_group.slug}/matches/#{match.id}/edit"}
                    class="text-xs text-primary hover:underline"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="show_delete_match_modal"
                    phx-value-match_id={match.id}
                    class="text-xs text-error hover:underline"
                  >
                    Delete
                  </button>
                </div>
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

      <%!-- Add Match modal --%>
      <.modal
        :if={@show_match_form}
        title="Add Match"
        on_close={JS.push("close_match_form")}
        max_width="max-w-lg"
      >
        <.form for={@match_form} phx-change="validate_match" phx-submit="save_match">
          <.input field={@match_form[:opponent]} type="text" label="Opponent" />
          <.input
            field={@match_form[:home_or_away]}
            type="select"
            label="Home or Away"
            options={[{"Home", "home"}, {"Away", "away"}]}
            prompt="Select..."
          />
          <.input field={@match_form[:match_date]} type="date" label="Match Date" />
          <.input field={@match_form[:match_time]} type="time" label="Match Time" />
          <.input
            field={@match_form[:location_id]}
            type="select"
            label="Location"
            options={Enum.map(@locations, &{&1.name, &1.id})}
            prompt="Location TBD"
          />
          <div class="mt-4 flex gap-2 justify-end">
            <button type="button" class="btn btn-ghost btn-sm" phx-click="close_match_form">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary btn-sm">Save Match</button>
          </div>
        </.form>
      </.modal>

      <%!-- Delete match confirmation modal --%>
      <.modal
        :if={@match_to_delete}
        title="Delete Match"
        on_close={JS.push("hide_delete_match_modal")}
      >
        <p class="text-sm text-base-content/70 mb-6">
          Delete the match vs. <strong>{@match_to_delete.opponent}</strong>? This cannot be undone.
        </p>
        <div class="flex gap-2">
          <button phx-click="delete_match" class="btn btn-error flex-1">Delete</button>
          <button phx-click="hide_delete_match_modal" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end
end
