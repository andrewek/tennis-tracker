defmodule TennisTrackerWeb.Teams.EditLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.MatchHelpers

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Match, TeamLineupColumn, TeamLineupSlot, Team}

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
    |> assign(:show_match_form, false)
    |> assign(:match_form, nil)
    |> assign(:locations, [])
    |> assign(:team_timezone, "America/Chicago")
    |> assign(:match_to_delete, nil)
    |> assign(:can_manage_slots, false)
    |> assign(:assignment_mode_form, nil)
    |> assign(:lineup_columns, [])
    |> assign(:show_add_column_form, false)
    |> assign(:column_form, nil)
    |> assign(:editing_column_id, nil)
    |> assign(:edit_column_form, nil)
    |> assign(:column_delete_error, nil)
    |> assign(:lineup_slots, [])
    |> assign(:show_add_slot_form, false)
    |> assign(:slot_form, nil)
    |> assign(:editing_slot_id, nil)
    |> assign(:edit_slot_form, nil)
    |> assign(:slot_to_delete, nil)
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
        can_update_team =
          Ash.can?({team, :update}, current_user, tenant: group_id, domain: Tennis)

        can_manage_slots =
          Ash.can?(
            {TeamLineupSlot, :create,
             %{team_id: team.id, group_id: group_id, name: "placeholder"}},
            current_user,
            domain: Tennis,
            tenant: group_id
          )

        if can_update_team or can_manage_slots do
          {:ok, team} =
            Ash.load(team, [:team_type], domain: Tennis, tenant: group_id, actor: current_user)

          team_form =
            if can_update_team do
              AshPhoenix.Form.for_update(team, :update,
                domain: Tennis,
                actor: current_user,
                tenant: group_id,
                as: "team_form",
                forms: [auto?: true]
              )
              |> to_form()
            end

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

          lineup_columns = load_lineup_columns(team.id, group_id, current_user)
          lineup_slots = load_lineup_slots(team.id, group_id, current_user)

          assignment_mode_form =
            if can_manage_slots do
              AshPhoenix.Form.for_update(team, :update_assignment_mode,
                domain: Tennis,
                actor: current_user,
                tenant: group_id,
                as: "assignment_mode_form",
                forms: [auto?: true]
              )
              |> to_form()
            end

          socket
          |> assign(:team, team)
          |> assign(:team_form, team_form)
          |> assign(:can_update_team, can_update_team)
          |> assign(:team_timezone, team.default_timezone || "America/Chicago")
          |> assign(:can_manage_slots, can_manage_slots)
          |> assign(:assignment_mode_form, assignment_mode_form)
          |> assign(:lineup_columns, lineup_columns)
          |> assign(:lineup_slots, lineup_slots)
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

  # ---------------------------------------------------------------------------
  # Team form events
  # ---------------------------------------------------------------------------

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
        |> assign(:team_timezone, team.default_timezone || "America/Chicago")
        |> put_flash(:info, "Team updated.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:team_form, form) |> noreply()
    end
  end

  # ---------------------------------------------------------------------------
  # Assignment mode form events
  # ---------------------------------------------------------------------------

  def handle_event("validate_assignment_mode", %{"assignment_mode_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.assignment_mode_form, params)
    socket |> assign(:assignment_mode_form, form) |> noreply()
  end

  def handle_event("save_assignment_mode", %{"assignment_mode_form" => params}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.assignment_mode_form, params: params) do
      {:ok, team} ->
        assignment_mode_form =
          AshPhoenix.Form.for_update(team, :update_assignment_mode,
            domain: Tennis,
            actor: current_user,
            tenant: group_id,
            as: "assignment_mode_form",
            forms: [auto?: true]
          )
          |> to_form()

        socket
        |> assign(:team, team)
        |> assign(:assignment_mode_form, assignment_mode_form)
        |> put_flash(:info, "Lineup assignment mode updated.")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:assignment_mode_form, form)
        |> put_flash(:error, "Could not update assignment mode.")
        |> noreply()
    end
  end

  # ---------------------------------------------------------------------------
  # Match form events
  # ---------------------------------------------------------------------------

  def handle_event("open_match_form", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    form =
      AshPhoenix.Form.for_create(Match, :create,
        domain: Tennis,
        actor: current_user,
        tenant: group_id,
        as: "match_form",
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

  def handle_event("validate_match", %{"match_form" => params}, socket) do
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

  def handle_event("save_match", %{"match_form" => params}, socket) do
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

  # ---------------------------------------------------------------------------
  # Lineup column events
  # ---------------------------------------------------------------------------

  def handle_event("open_add_column_form", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    form =
      AshPhoenix.Form.for_create(TeamLineupColumn, :create,
        domain: Tennis,
        actor: current_user,
        tenant: group_id,
        as: "column_form",
        forms: [auto?: true]
      )
      |> to_form()

    socket
    |> assign(:show_add_column_form, true)
    |> assign(:column_form, form)
    |> noreply()
  end

  def handle_event("close_add_column_form", _params, socket) do
    socket
    |> assign(:show_add_column_form, false)
    |> assign(:column_form, nil)
    |> noreply()
  end

  def handle_event("validate_column", %{"column_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.column_form, params)
    socket |> assign(:column_form, form) |> noreply()
  end

  def handle_event("save_column", %{"column_form" => params}, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    params_with_ids =
      params
      |> Map.put("team_id", team.id)
      |> Map.put("group_id", group_id)

    case AshPhoenix.Form.submit(socket.assigns.column_form, params: params_with_ids) do
      {:ok, _column} ->
        socket
        |> assign(:show_add_column_form, false)
        |> assign(:column_form, nil)
        |> assign(:lineup_columns, load_lineup_columns(team.id, group_id, current_user))
        |> put_flash(:info, "Column added.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:column_form, form) |> noreply()
    end
  end

  def handle_event("open_edit_column", %{"column_id" => column_id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    column = Enum.find(socket.assigns.lineup_columns, &(&1.id == column_id))

    if column do
      form =
        AshPhoenix.Form.for_update(column, :update,
          domain: Tennis,
          actor: current_user,
          tenant: group_id,
          as: "edit_column_form",
          forms: [auto?: true]
        )
        |> to_form()

      socket
      |> assign(:editing_column_id, column_id)
      |> assign(:edit_column_form, form)
      |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_event("close_edit_column", _params, socket) do
    socket
    |> assign(:editing_column_id, nil)
    |> assign(:edit_column_form, nil)
    |> noreply()
  end

  def handle_event("validate_edit_column", %{"edit_column_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.edit_column_form, params)
    socket |> assign(:edit_column_form, form) |> noreply()
  end

  def handle_event("save_edit_column", %{"edit_column_form" => params}, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.edit_column_form, params: params) do
      {:ok, _column} ->
        socket
        |> assign(:editing_column_id, nil)
        |> assign(:edit_column_form, nil)
        |> assign(:lineup_columns, load_lineup_columns(team.id, group_id, current_user))
        |> put_flash(:info, "Column renamed.")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:edit_column_form, form)
        |> put_flash(:error, "Could not rename column — the name may already be in use.")
        |> noreply()
    end
  end

  def handle_event("move_column_up", %{"column_id" => column_id}, socket) do
    do_reorder_column(socket, column_id, :up)
  end

  def handle_event("move_column_down", %{"column_id" => column_id}, socket) do
    do_reorder_column(socket, column_id, :down)
  end

  def handle_event("delete_column", %{"column_id" => column_id}, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    column = Enum.find(socket.assigns.lineup_columns, &(&1.id == column_id))

    if column do
      slots_in_column =
        Enum.filter(socket.assigns.lineup_slots, &(&1.team_lineup_column_id == column.id))

      if slots_in_column != [] do
        socket
        |> assign(
          :column_delete_error,
          "Cannot delete \"#{column.name}\" — reassign or delete its slots first."
        )
        |> noreply()
      else
        Tennis.delete_lineup_column!(column, tenant: group_id, actor: current_user)

        socket
        |> assign(:column_delete_error, nil)
        |> assign(:lineup_columns, load_lineup_columns(team.id, group_id, current_user))
        |> put_flash(:info, "Column deleted.")
        |> noreply()
      end
    else
      socket |> noreply()
    end
  end

  def handle_event("dismiss_column_error", _params, socket) do
    socket |> assign(:column_delete_error, nil) |> noreply()
  end

  # ---------------------------------------------------------------------------
  # Lineup slot events
  # ---------------------------------------------------------------------------

  def handle_event("open_add_slot_form", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    form =
      AshPhoenix.Form.for_create(TeamLineupSlot, :create,
        domain: Tennis,
        actor: current_user,
        tenant: group_id,
        as: "slot_form",
        forms: [auto?: true]
      )
      |> to_form()

    socket
    |> assign(:show_add_slot_form, true)
    |> assign(:slot_form, form)
    |> noreply()
  end

  def handle_event("close_add_slot_form", _params, socket) do
    socket
    |> assign(:show_add_slot_form, false)
    |> assign(:slot_form, nil)
    |> noreply()
  end

  def handle_event("validate_slot", %{"slot_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.slot_form, params)
    socket |> assign(:slot_form, form) |> noreply()
  end

  def handle_event("save_slot", %{"slot_form" => params}, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    params_with_ids =
      params
      |> Map.put("team_id", team.id)
      |> Map.put("group_id", group_id)
      |> maybe_default_column(team.id, group_id, current_user)

    case AshPhoenix.Form.submit(socket.assigns.slot_form, params: params_with_ids) do
      {:ok, _slot} ->
        socket
        |> assign(:show_add_slot_form, false)
        |> assign(:slot_form, nil)
        |> assign(:lineup_slots, load_lineup_slots(team.id, group_id, current_user))
        |> put_flash(:info, "Slot added.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:slot_form, form) |> noreply()
    end
  end

  def handle_event("open_edit_slot", %{"slot_id" => slot_id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    slot = Enum.find(socket.assigns.lineup_slots, &(&1.id == slot_id))

    if slot do
      form =
        AshPhoenix.Form.for_update(slot, :update,
          domain: Tennis,
          actor: current_user,
          tenant: group_id,
          as: "edit_slot_form",
          forms: [auto?: true]
        )
        |> to_form()

      socket
      |> assign(:editing_slot_id, slot_id)
      |> assign(:edit_slot_form, form)
      |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_event("close_edit_slot", _params, socket) do
    socket
    |> assign(:editing_slot_id, nil)
    |> assign(:edit_slot_form, nil)
    |> noreply()
  end

  def handle_event("validate_edit_slot", %{"edit_slot_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.edit_slot_form, params)
    socket |> assign(:edit_slot_form, form) |> noreply()
  end

  def handle_event("save_edit_slot", %{"edit_slot_form" => params}, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case AshPhoenix.Form.submit(socket.assigns.edit_slot_form, params: params) do
      {:ok, _slot} ->
        socket
        |> assign(:editing_slot_id, nil)
        |> assign(:edit_slot_form, nil)
        |> assign(:lineup_slots, load_lineup_slots(team.id, group_id, current_user))
        |> put_flash(:info, "Slot updated.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:edit_slot_form, form) |> noreply()
    end
  end

  def handle_event("show_delete_slot_modal", %{"slot_id" => slot_id}, socket) do
    slot = Enum.find(socket.assigns.lineup_slots, &(&1.id == slot_id))

    if slot && slot.is_exclusion_slot do
      socket |> put_flash(:error, "The exclusion slot cannot be deleted.") |> noreply()
    else
      socket |> assign(:slot_to_delete, slot) |> noreply()
    end
  end

  def handle_event("hide_delete_slot_modal", _params, socket) do
    socket |> assign(:slot_to_delete, nil) |> noreply()
  end

  def handle_event("delete_slot", _params, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    slot = socket.assigns.slot_to_delete

    Tennis.delete_lineup_slot!(slot, tenant: group_id, actor: current_user)

    socket
    |> assign(:slot_to_delete, nil)
    |> assign(:lineup_slots, load_lineup_slots(team.id, group_id, current_user))
    |> put_flash(:info, "Slot deleted.")
    |> noreply()
  end

  def handle_event("move_slot_up", %{"slot_id" => slot_id}, socket) do
    do_reorder_slot(socket, slot_id, :up)
  end

  def handle_event("move_slot_down", %{"slot_id" => slot_id}, socket) do
    do_reorder_slot(socket, slot_id, :down)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp do_reorder_slot(socket, slot_id, direction) do
    slots = socket.assigns.lineup_slots
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    idx = Enum.find_index(slots, &(&1.id == slot_id))

    if idx do
      adjacent_idx = if direction == :up, do: idx - 1, else: idx + 1
      slot = Enum.at(slots, idx)
      adjacent = Enum.at(slots, adjacent_idx)

      if adjacent do
        Tennis.update_lineup_slot!(slot, %{sort_order: adjacent.sort_order},
          tenant: group_id,
          actor: current_user
        )

        Tennis.update_lineup_slot!(adjacent, %{sort_order: slot.sort_order},
          tenant: group_id,
          actor: current_user
        )

        socket
        |> assign(:lineup_slots, load_lineup_slots(team.id, group_id, current_user))
        |> noreply()
      else
        socket |> noreply()
      end
    else
      socket |> noreply()
    end
  end

  defp load_lineup_columns(team_id, group_id, current_user) do
    Tennis.list_lineup_columns_for_team!(team_id, tenant: group_id, actor: current_user)
  end

  defp load_lineup_slots(team_id, group_id, current_user) do
    Tennis.list_lineup_slots_for_team!(team_id, tenant: group_id, actor: current_user)
  end

  defp do_reorder_column(socket, column_id, direction) do
    columns = socket.assigns.lineup_columns
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    idx = Enum.find_index(columns, &(&1.id == column_id))

    if idx do
      adjacent_idx = if direction == :up, do: idx - 1, else: idx + 1
      column = Enum.at(columns, idx)
      adjacent = Enum.at(columns, adjacent_idx)

      if adjacent do
        Tennis.update_lineup_column!(column, %{sort_order: adjacent.sort_order},
          tenant: group_id,
          actor: current_user
        )

        Tennis.update_lineup_column!(adjacent, %{sort_order: column.sort_order},
          tenant: group_id,
          actor: current_user
        )

        socket
        |> assign(:lineup_columns, load_lineup_columns(team.id, group_id, current_user))
        |> noreply()
      else
        socket |> noreply()
      end
    else
      socket |> noreply()
    end
  end

  defp maybe_default_column(params, team_id, group_id, current_user) do
    if params["team_lineup_column_id"] in [nil, ""] do
      columns =
        Tennis.list_lineup_columns_for_team!(team_id, tenant: group_id, actor: current_user)

      case columns do
        [col | _] -> Map.put(params, "team_lineup_column_id", col.id)
        [] -> params
      end
    else
      params
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
        title="Edit Team"
        back_href={~p"/g/#{@current_group.slug}/teams/#{@team.id}"}
        back_label={@team.name}
      >
        <:subtitle>{@team.team_type.name} · {@team.season_year}</:subtitle>
      </.page_header>

      <div class="flex flex-wrap gap-6 items-start">
        <%!-- Team settings form (owners only) --%>
        <div :if={@can_update_team} class="bg-base-200 rounded-lg p-4 w-full max-w-sm">
          <h2 class="font-semibold mb-4">Team Settings</h2>
          <.form id="team-form" for={@team_form} phx-change="validate_team" phx-submit="save_team">
            <.input field={@team_form[:name]} type="text" label="Team Name" />
            <.input
              field={@team_form[:default_timezone]}
              type="select"
              label="Timezone"
              options={@us_timezones}
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
            />
            <div class="mt-4">
              <button type="submit" class="btn btn-primary btn-sm">Save Team</button>
            </div>
          </.form>
        </div>

        <%!-- Assignment Mode section (captains/owners) --%>
        <div
          :if={@can_manage_slots && not @can_update_team}
          class="bg-base-200 rounded-lg p-4 w-full max-w-sm"
        >
          <h2 class="font-semibold mb-4">Lineup Assignment Mode</h2>
          <.form
            id="assignment-mode-form"
            for={@assignment_mode_form}
            phx-change="validate_assignment_mode"
            phx-submit="save_assignment_mode"
          >
            <.input
              field={@assignment_mode_form[:lineup_assignment_mode]}
              type="select"
              label="Mode"
              options={[
                {"One per match", "one_per_match"},
                {"One per column", "one_per_column"},
                {"Many per match", "many_per_match"}
              ]}
            />
            <div class="mt-4">
              <button type="submit" class="btn btn-primary btn-sm">Save</button>
            </div>
          </.form>
        </div>

        <%!-- Lineup Columns section (captains/owners only) --%>
        <div :if={@can_manage_slots} class="bg-base-200 rounded-lg p-4 w-full max-w-sm">
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold">Lineup Columns</h2>
            <button
              :if={not @show_add_column_form}
              class="btn btn-xs btn-ghost"
              phx-click="open_add_column_form"
            >
              <.icon name="hero-plus" class="size-3 inline" /> Add Column
            </button>
          </div>

          <%!-- Column delete error --%>
          <div
            :if={@column_delete_error}
            class="mb-3 bg-error/10 text-error rounded p-2 text-sm flex items-start justify-between gap-2"
          >
            <span>{@column_delete_error}</span>
            <button
              phx-click="dismiss_column_error"
              class="flex-shrink-0 text-error/70 hover:text-error"
            >
              <.icon name="hero-x-mark" class="size-4" />
            </button>
          </div>

          <%!-- Add column form --%>
          <div :if={@show_add_column_form} class="mb-4 bg-base-100 rounded p-3">
            <.form
              id="column-form"
              for={@column_form}
              phx-change="validate_column"
              phx-submit="save_column"
            >
              <.input field={@column_form[:name]} type="text" label="Name" placeholder="e.g. Singles" />
              <div class="flex gap-2 mt-3">
                <button type="submit" class="btn btn-primary btn-xs">Add</button>
                <button type="button" class="btn btn-ghost btn-xs" phx-click="close_add_column_form">
                  Cancel
                </button>
              </div>
            </.form>
          </div>

          <%!-- Column list --%>
          <div :if={@lineup_columns == []} class="text-sm text-base-content/50">
            No columns defined.
          </div>

          <div class="space-y-2">
            <%= for {column, idx} <- Enum.with_index(@lineup_columns) do %>
              <div id={"column-#{column.id}"} class="bg-base-100 rounded px-3 py-2 text-sm">
                <%= if @editing_column_id == column.id do %>
                  <.form
                    id={"edit-column-form-#{column.id}"}
                    for={@edit_column_form}
                    phx-change="validate_edit_column"
                    phx-submit="save_edit_column"
                  >
                    <.input field={@edit_column_form[:name]} type="text" label="Name" />
                    <div class="flex gap-2 mt-2">
                      <button type="submit" class="btn btn-primary btn-xs">Save</button>
                      <button
                        type="button"
                        class="btn btn-ghost btn-xs"
                        phx-click="close_edit_column"
                      >
                        Cancel
                      </button>
                    </div>
                  </.form>
                <% else %>
                  <div class="flex items-center justify-between">
                    <span class="font-medium">{column.name}</span>
                    <div class="flex items-center gap-1 flex-shrink-0">
                      <button
                        :if={idx > 0}
                        phx-click="move_column_up"
                        phx-value-column_id={column.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Move up"
                      >
                        <.icon name="hero-chevron-up" class="size-3" />
                      </button>
                      <button
                        :if={idx < length(@lineup_columns) - 1}
                        phx-click="move_column_down"
                        phx-value-column_id={column.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Move down"
                      >
                        <.icon name="hero-chevron-down" class="size-3" />
                      </button>
                      <button
                        phx-click="open_edit_column"
                        phx-value-column_id={column.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Rename"
                      >
                        <.icon name="hero-pencil-square" class="size-3" />
                      </button>
                      <button
                        phx-click="delete_column"
                        phx-value-column_id={column.id}
                        class="btn btn-xs btn-ghost text-error"
                        aria-label="Delete"
                      >
                        <.icon name="hero-trash" class="size-3" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Lineup Slots section (captains/owners only) --%>
        <div
          :if={@can_manage_slots}
          id="slots-management-section"
          class="bg-base-200 rounded-lg p-4 w-full max-w-sm"
        >
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold">Lineup Slots</h2>
            <button
              :if={not @show_add_slot_form}
              class="btn btn-xs btn-ghost"
              phx-click="open_add_slot_form"
            >
              <.icon name="hero-plus" class="size-3 inline" /> Add Slot
            </button>
          </div>

          <%!-- Add slot form --%>
          <div :if={@show_add_slot_form} class="mb-4 bg-base-100 rounded p-3">
            <.form id="slot-form" for={@slot_form} phx-change="validate_slot" phx-submit="save_slot">
              <.input
                field={@slot_form[:name]}
                type="text"
                label="Name"
                placeholder="e.g. #1 Singles"
              />
              <.input
                field={@slot_form[:expected_count]}
                type="number"
                label="Expected Players (optional)"
              />
              <.input
                field={@slot_form[:include_in_clipboard]}
                type="checkbox"
                label="Include in clipboard"
              />
              <.input
                field={@slot_form[:team_lineup_column_id]}
                type="select"
                label="Column"
                options={Enum.map(@lineup_columns, &{&1.name, &1.id})}
                prompt="Select column..."
              />
              <div class="flex gap-2 mt-3">
                <button type="submit" class="btn btn-primary btn-xs">Add</button>
                <button type="button" class="btn btn-ghost btn-xs" phx-click="close_add_slot_form">
                  Cancel
                </button>
              </div>
            </.form>
          </div>

          <%!-- Slot list --%>
          <div :if={@lineup_slots == []} class="text-sm text-base-content/50">
            No lineup slots defined. Add a slot to get started.
          </div>

          <div class="space-y-2">
            <%= for {slot, idx} <- Enum.with_index(@lineup_slots) do %>
              <div id={"slot-#{slot.id}"} class="bg-base-100 rounded px-3 py-2 text-sm">
                <%= if @editing_slot_id == slot.id do %>
                  <%!-- Inline edit form --%>
                  <.form
                    id={"edit-slot-form-#{slot.id}"}
                    for={@edit_slot_form}
                    phx-change="validate_edit_slot"
                    phx-submit="save_edit_slot"
                  >
                    <.input field={@edit_slot_form[:name]} type="text" label="Name" />
                    <.input
                      field={@edit_slot_form[:expected_count]}
                      type="number"
                      label="Expected Players"
                    />
                    <.input
                      field={@edit_slot_form[:include_in_clipboard]}
                      type="checkbox"
                      label="Include in clipboard"
                    />
                    <.input
                      field={@edit_slot_form[:team_lineup_column_id]}
                      type="select"
                      label="Column"
                      options={Enum.map(@lineup_columns, &{&1.name, &1.id})}
                      prompt="Select column..."
                    />
                    <div class="flex gap-2 mt-2">
                      <button type="submit" class="btn btn-primary btn-xs">Save</button>
                      <button type="button" class="btn btn-ghost btn-xs" phx-click="close_edit_slot">
                        Cancel
                      </button>
                    </div>
                  </.form>
                <% else %>
                  <div class="flex items-center justify-between">
                    <div class="min-w-0">
                      <span class="font-medium">{slot.name}</span>
                      <% col = Enum.find(@lineup_columns, &(&1.id == slot.team_lineup_column_id)) %>
                      <span :if={col} class="text-base-content/40 text-xs ml-1">
                        [{col.name}]
                      </span>
                      <span :if={slot.expected_count} class="text-base-content/50 text-xs ml-2">
                        ({slot.expected_count})
                      </span>
                      <span
                        :if={not slot.include_in_clipboard}
                        class="text-base-content/40 text-xs ml-1"
                      >
                        (no copy)
                      </span>
                    </div>
                    <div class="flex items-center gap-1 flex-shrink-0">
                      <button
                        :if={idx > 0}
                        phx-click="move_slot_up"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Move up"
                      >
                        <.icon name="hero-chevron-up" class="size-3" />
                      </button>
                      <button
                        :if={idx < length(@lineup_slots) - 1}
                        phx-click="move_slot_down"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Move down"
                      >
                        <.icon name="hero-chevron-down" class="size-3" />
                      </button>
                      <button
                        phx-click="open_edit_slot"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Edit"
                      >
                        <.icon name="hero-pencil-square" class="size-3" />
                      </button>
                      <button
                        phx-click="show_delete_slot_modal"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost text-error"
                        aria-label="Delete"
                      >
                        <.icon name="hero-trash" class="size-3" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Match schedule (owners only) --%>
        <div :if={@can_update_team} class="bg-base-200 rounded-lg p-4 w-full max-w-md">
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

      <%!-- Delete slot confirmation modal --%>
      <.modal
        :if={@slot_to_delete}
        title="Delete Slot"
        on_close={JS.push("hide_delete_slot_modal")}
      >
        <p class="text-sm text-base-content/70 mb-6">
          Delete slot <strong>{@slot_to_delete.name}</strong>? All lineup assignments for this slot will also be removed.
        </p>
        <div class="flex gap-2">
          <button phx-click="delete_slot" class="btn btn-error flex-1">Delete</button>
          <button phx-click="hide_delete_slot_modal" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end
end
