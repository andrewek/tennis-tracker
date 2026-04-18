defmodule TennisTrackerWeb.Matches.EditLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.MatchHelpers

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.Match

  def mount(_params, _session, socket) do
    socket
    |> assign(:match, nil)
    |> assign(:form, nil)
    |> assign(:team_timezone, "America/Chicago")
    |> assign(:locations, [])
    |> assign(:show_delete_modal, false)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Ash.get(Match, id, domain: Tennis, tenant: group_id, actor: current_user) do
      {:ok, match} ->
        if Ash.can?({match, :update}, current_user, tenant: group_id, domain: Tennis) do
          {:ok, match} =
            Ash.load(match, [:team, :location],
              domain: Tennis,
              tenant: group_id,
              actor: current_user
            )

          locations = Tennis.list_locations!(tenant: group_id, actor: current_user)

          form =
            AshPhoenix.Form.for_update(match, :update,
              domain: Tennis,
              actor: current_user,
              tenant: group_id,
              forms: [auto?: true]
            )
            |> to_form()

          socket
          |> assign(:match, match)
          |> assign(:form, form)
          |> assign(:team_timezone, match.timezone)
          |> assign(:locations, locations)
          |> noreply()
        else
          socket
          |> put_flash(:error, "You don't have permission to edit this match.")
          |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
          |> noreply()
        end

      {:error, _} ->
        socket
        |> put_flash(:error, "Match not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()
    end
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

    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    socket |> assign(:form, form) |> noreply()
  end

  def handle_event("save_match", %{"form" => params}, socket) do
    timezone = socket.assigns.team_timezone
    date_str = params["match_date"]
    time_str = params["match_time"]
    group_slug = socket.assigns.current_group.slug

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

        case AshPhoenix.Form.submit(socket.assigns.form, params: params_with_datetime) do
          {:ok, _match} ->
            team_id = socket.assigns.match.team_id

            socket
            |> put_flash(:info, "Match updated.")
            |> push_navigate(to: ~p"/g/#{group_slug}/teams/#{team_id}/settings/schedule")
            |> noreply()

          {:error, form} ->
            socket |> assign(:form, form) |> noreply()
        end
    end
  end

  def handle_event("show_delete_modal", _params, socket) do
    socket |> assign(:show_delete_modal, true) |> noreply()
  end

  def handle_event("hide_delete_modal", _params, socket) do
    socket |> assign(:show_delete_modal, false) |> noreply()
  end

  def handle_event("delete_match", _params, socket) do
    match = socket.assigns.match
    team_id = match.team_id
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    group_slug = socket.assigns.current_group.slug
    Tennis.destroy_match!(match, tenant: group_id, actor: current_user)

    socket
    |> put_flash(:info, "Match deleted.")
    |> push_navigate(to: ~p"/g/#{group_slug}/teams/#{team_id}/settings/schedule")
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
        title="Edit Match"
        back_href={~p"/g/#{@current_group.slug}/matches/#{@match.id}"}
        back_label="Match"
      >
        <:subtitle>vs. {@match.opponent} · {@match.team.name}</:subtitle>
      </.page_header>

      <div class="max-w-lg">
        <.form for={@form} phx-change="validate_match" phx-submit="save_match">
          <.input field={@form[:opponent]} type="text" label="Opponent" />
          <.input
            field={@form[:home_or_away]}
            type="select"
            label="Home or Away"
            options={[{"Home", "home"}, {"Away", "away"}]}
            prompt="Select..."
          />
          <.input
            field={@form[:match_date]}
            type="date"
            label="Match Date"
            value={
              @match.match_start_datetime
              |> DateTime.shift_zone!(@team_timezone)
              |> DateTime.to_date()
              |> Date.to_iso8601()
            }
          />
          <.input
            field={@form[:match_time]}
            type="time"
            label="Match Time"
            value={
              @match.match_start_datetime
              |> DateTime.shift_zone!(@team_timezone)
              |> then(fn dt ->
                "#{String.pad_leading("#{dt.hour}", 2, "0")}:#{String.pad_leading("#{dt.minute}", 2, "0")}"
              end)
            }
          />
          <.input
            field={@form[:location_id]}
            type="select"
            label="Location"
            options={Enum.map(@locations, &{&1.name, &1.id})}
            prompt="Location TBD"
          />
          <div class="mt-4 flex gap-2">
            <button type="submit" class="btn btn-primary btn-sm">Update Match</button>
            <button type="button" phx-click="show_delete_modal" class="btn btn-error btn-soft btn-sm">
              Delete
            </button>
          </div>
        </.form>
      </div>

      <.modal
        :if={@show_delete_modal}
        title="Delete Match"
        on_close={JS.push("hide_delete_modal")}
      >
        <p class="text-sm text-base-content/70 mb-6">
          Delete the match vs. <strong>{@match.opponent}</strong>? This cannot be undone.
        </p>
        <div class="flex gap-2">
          <button phx-click="delete_match" class="btn btn-error flex-1">Delete</button>
          <button phx-click="hide_delete_modal" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end
end
