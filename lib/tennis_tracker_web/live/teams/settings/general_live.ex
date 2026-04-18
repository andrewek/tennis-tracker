defmodule TennisTrackerWeb.Teams.Settings.GeneralLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTrackerWeb.TeamComponents
  alias TennisTrackerWeb.Teams.Settings.Helpers

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
    |> assign(:can_update_team, false)
    |> assign(:can_manage_slots, false)
    |> assign(:can_manage_captains, false)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Helpers.load_team_settings(id, group_id, current_user) do
      {:ok, assigns} ->
        team = assigns.team

        team_form =
          AshPhoenix.Form.for_update(team, :update,
            domain: Tennis,
            actor: current_user,
            tenant: group_id,
            as: "team_form",
            forms: [auto?: true]
          )
          |> to_form()

        socket
        |> assign(assigns)
        |> assign(:team_form, team_form)
        |> assign(:page_title, "#{team.name} · Settings")
        |> noreply()

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Team not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()

      {:error, :unauthorized} ->
        socket
        |> put_flash(:error, "You don't have permission to edit this team.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams/#{id}")
        |> noreply()
    end
  end

  def handle_event("validate_team", %{"team_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.team_form, params)
    socket |> assign(:team_form, form) |> noreply()
  end

  def handle_event("save_team", %{"team_form" => params}, socket) do
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
            as: "team_form",
            forms: [auto?: true]
          )
          |> to_form()

        socket
        |> assign(:team, team)
        |> assign(:team_form, team_form)
        |> put_flash(:info, "Team updated.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:team_form, form) |> noreply()
    end
  end

  def render(assigns) do
    assigns = assign(assigns, :us_timezones, @us_timezones)

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
        current_page={:general}
        team={@team}
        current_group={@current_group}
      >
        <div class="max-w-sm">
          <.form
            id="team-form"
            for={@team_form}
            phx-change="validate_team"
            phx-submit="save_team"
            class="space-y-4"
          >
            <.input
              field={@team_form[:name]}
              type="text"
              label="Team Name"
              disabled={not @can_update_team}
            />
            <.input
              field={@team_form[:default_timezone]}
              type="select"
              label="Timezone"
              options={@us_timezones}
              disabled={not @can_update_team}
            />
            <.input
              field={@team_form[:lineup_assignment_mode]}
              type="select"
              label="Lineup Assignment Mode"
              options={[
                {"One per match", "one_per_match"},
                {"One per column", "one_per_column"},
                {"Many per match", "many_per_match"}
              ]}
              disabled={not @can_update_team}
            />
            <div :if={@can_update_team} class="mt-4">
              <.button type="submit">Save</.button>
            </div>
          </.form>
        </div>
      </TeamComponents.settings_layout>
    </Layouts.app>
    """
  end
end
