defmodule TennisTrackerWeb.Teams.Settings.MembersLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.TeamRole
  alias TennisTracker.Groups
  alias TennisTrackerWeb.TeamComponents
  alias TennisTrackerWeb.Teams.Settings.Helpers

  require Ash.Query

  def mount(_params, _session, socket) do
    socket
    |> assign(:team, nil)
    |> assign(:can_update_team, false)
    |> assign(:can_manage_slots, false)
    |> assign(:can_manage_captains, false)
    |> assign(:candidate_user_id, nil)
    |> assign(:candidate_members, [])
    |> assign(:remove_pending_role, nil)
    |> stream(:captains, [])
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Helpers.load_team_settings(id, group_id, current_user) do
      {:ok, assigns} ->
        team = assigns.team

        captains =
          Tennis.list_captains_for_team!(team.id,
            tenant: group_id,
            actor: current_user,
            load: [:user]
          )

        candidate_members =
          Groups.list_candidate_members_for_team!(group_id, team.id,
            tenant: group_id,
            actor: current_user
          )

        socket
        |> assign(assigns)
        |> assign(:page_title, "#{team.name} · Members")
        |> stream(:captains, captains, reset: true)
        |> assign(:candidate_members, candidate_members)
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

  def handle_event("select_captain_candidate", %{"user_id" => user_id}, socket) do
    socket |> assign(:candidate_user_id, user_id) |> noreply()
  end

  def handle_event("add_captain", _params, socket) do
    candidate_user_id = socket.assigns.candidate_user_id

    if is_nil(candidate_user_id) or candidate_user_id == "" do
      socket |> noreply()
    else
      group_id = socket.assigns.current_group_id
      current_user = socket.assigns.current_user
      team = socket.assigns.team

      existing_role =
        TeamRole
        |> Ash.Query.filter(team_id == ^team.id and user_id == ^candidate_user_id)
        |> Ash.read_one!(domain: Tennis, tenant: group_id, actor: current_user)

      result =
        if existing_role && existing_role.role == :member do
          Tennis.update_team_role_role!(existing_role, %{role: :captain},
            tenant: group_id,
            actor: current_user
          )

          :ok
        else
          case Tennis.create_team_role(
                 %{
                   user_id: candidate_user_id,
                   team_id: team.id,
                   group_id: group_id,
                   role: :captain
                 },
                 tenant: group_id,
                 actor: current_user
               ) do
            {:ok, _} -> :ok
            {:error, reason} -> {:error, reason}
          end
        end

      case result do
        :ok ->
          socket
          |> reload_captains_and_candidates()
          |> assign(:candidate_user_id, nil)
          |> noreply()

        {:error, _} ->
          socket
          |> put_flash(:error, "Could not add captain. Please refresh the page.")
          |> noreply()
      end
    end
  end

  def handle_event("remove_captain", %{"team_role_id" => team_role_id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    role =
      Ash.get!(TeamRole, team_role_id,
        domain: Tennis,
        tenant: group_id,
        actor: current_user
      )

    {:ok, role} = Ash.load(role, [:user], domain: Tennis, tenant: group_id, actor: current_user)

    socket |> assign(:remove_pending_role, role) |> noreply()
  end

  def handle_event("confirm_remove_entirely", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    role = socket.assigns.remove_pending_role

    Tennis.destroy_team_role!(role, tenant: group_id, actor: current_user)

    socket
    |> assign(:remove_pending_role, nil)
    |> reload_captains_and_candidates()
    |> noreply()
  end

  def handle_event("confirm_convert_to_member", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    role = socket.assigns.remove_pending_role

    Tennis.update_team_role_role!(role, %{role: :member}, tenant: group_id, actor: current_user)

    socket
    |> assign(:remove_pending_role, nil)
    |> reload_captains_and_candidates()
    |> noreply()
  end

  def handle_event("cancel_remove", _params, socket) do
    socket |> assign(:remove_pending_role, nil) |> noreply()
  end

  defp reload_captains_and_candidates(socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    team = socket.assigns.team

    captains =
      Tennis.list_captains_for_team!(team.id,
        tenant: group_id,
        actor: current_user,
        load: [:user]
      )

    candidate_members =
      Groups.list_candidate_members_for_team!(group_id, team.id,
        tenant: group_id,
        actor: current_user
      )

    socket
    |> stream(:captains, captains, reset: true)
    |> assign(:candidate_members, candidate_members)
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
        current_page={:members}
        team={@team}
        current_group={@current_group}
      >
        <div class="max-w-sm">
          <h2 class="font-semibold mb-3">Captains</h2>

          <div id="captains-list" phx-update="stream" class="space-y-1 mb-3">
            <div
              :for={{dom_id, role} <- @streams.captains}
              id={dom_id}
              class="bg-base-200 rounded px-3 py-2 text-sm flex items-center justify-between"
            >
              <span>{role.user.name || role.user.email}</span>
              <button
                :if={@can_manage_captains}
                phx-click="remove_captain"
                phx-value-team_role_id={role.id}
                class="btn btn-xs btn-ghost text-error"
              >
                Remove
              </button>
            </div>
          </div>

          <p :if={@streams.captains.inserts == []} class="text-sm text-base-content/50 mb-3">
            No captains assigned.
          </p>

          <form
            :if={@can_manage_captains}
            phx-change="select_captain_candidate"
            phx-submit="add_captain"
            class="flex gap-2 items-end"
          >
            <div class="flex-1">
              <select class="select select-bordered select-sm w-full" name="user_id">
                <option value="">Select a member...</option>
                <%= for membership <- @candidate_members do %>
                  <option
                    value={membership.user_id}
                    selected={@candidate_user_id == membership.user_id}
                  >
                    {membership.user.name || membership.user.email}
                  </option>
                <% end %>
              </select>
            </div>
            <button
              type="submit"
              class="btn btn-sm btn-primary"
              disabled={is_nil(@candidate_user_id) or @candidate_user_id == ""}
            >
              Add Captain
            </button>
          </form>
        </div>
      </TeamComponents.settings_layout>

      <%!-- Remove captain confirmation modal --%>
      <.modal
        :if={@remove_pending_role}
        title="Remove Captain"
        on_close={JS.push("cancel_remove")}
      >
        <p class="text-sm text-base-content/70 mb-6">
          What would you like to do with <strong>{@remove_pending_role.user && (@remove_pending_role.user.name || @remove_pending_role.user.email)}</strong>?
        </p>
        <div class="flex flex-col gap-2">
          <button phx-click="confirm_remove_entirely" class="btn btn-error">
            Remove from team entirely
          </button>
          <button phx-click="confirm_convert_to_member" class="btn btn-warning">
            Convert to Member
          </button>
          <button phx-click="cancel_remove" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end
end
