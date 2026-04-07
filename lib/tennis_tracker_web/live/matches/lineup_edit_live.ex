defmodule TennisTrackerWeb.Matches.LineupEditLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.BoardComponents

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.MatchLineupAssignment

  # ---------------------------------------------------------------------------
  # Mount / Params
  # ---------------------------------------------------------------------------

  def mount(_params, _session, socket) do
    socket
    |> assign(:match, nil)
    |> assign(:lineup_columns, [])
    |> assign(:lineup_slots, [])
    |> assign(:assignments, [])
    |> assign(:available, [])
    |> assign(:player_column_assignments, %{})
    |> assign(:mode, :one_per_match)
    |> assign(:selected_player_id, nil)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Ash.get(Tennis.Match, id, domain: Tennis, tenant: group_id, actor: current_user) do
      {:ok, match} ->
        can_edit =
          Ash.can?(
            {MatchLineupAssignment, :create, %{group_id: group_id, match_id: match.id}},
            current_user,
            domain: Tennis,
            tenant: group_id
          )

        if can_edit do
          {:ok, match} =
            Ash.load(match, [:team, location: []],
              domain: Tennis,
              tenant: group_id,
              actor: current_user
            )

          if connected?(socket) do
            Phoenix.PubSub.subscribe(
              TennisTracker.PubSub,
              "lineup:#{group_id}:#{match.id}"
            )
          end

          socket
          |> assign(:match, match)
          |> load_board(group_id, current_user)
          |> noreply()
        else
          socket
          |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/matches/#{id}")
          |> noreply()
        end

      {:error, _} ->
        socket
        |> put_flash(:error, "Match not found.")
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/teams")
        |> noreply()
    end
  end

  # ---------------------------------------------------------------------------
  # Events
  # ---------------------------------------------------------------------------

  def handle_event(
        "move_lineup_player",
        %{"player_id" => player_id, "target_id" => "available"},
        socket
      ) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    match = socket.assigns.match

    case Tennis.unassign_from_lineup(match.id, player_id,
           tenant: group_id,
           actor: current_user
         ) do
      result when result in [:ok, {:ok, nil}] ->
        # Board reload driven by PubSub notification
        socket |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Could not update lineup.") |> noreply()
    end
  end

  def handle_event(
        "move_lineup_player",
        %{"player_id" => player_id, "target_id" => slot_id},
        socket
      ) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    match = socket.assigns.match

    result = do_slot_assignment(socket, match.id, player_id, slot_id, group_id, current_user)

    case result do
      {:ok, _} ->
        socket |> noreply()

      :ok ->
        socket |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Could not update lineup.") |> noreply()
    end
  end

  def handle_event("select_player", %{"player_id" => player_id}, socket) do
    current = socket.assigns.selected_player_id
    new_id = if current == player_id, do: nil, else: player_id
    socket |> assign(:selected_player_id, new_id) |> noreply()
  end

  def handle_event("assign_selected_player", %{"slot_id" => slot_id}, socket) do
    selected_player_id = socket.assigns.selected_player_id

    if selected_player_id do
      group_id = socket.assigns.current_group_id
      current_user = socket.assigns.current_user
      match = socket.assigns.match

      result =
        do_slot_assignment(socket, match.id, selected_player_id, slot_id, group_id, current_user)

      case result do
        r when r in [{:ok, :no_change}, {:ok, nil}] ->
          socket |> assign(:selected_player_id, nil) |> noreply()

        {:ok, _} ->
          socket |> assign(:selected_player_id, nil) |> noreply()

        :ok ->
          socket |> assign(:selected_player_id, nil) |> noreply()

        {:error, _} ->
          socket
          |> assign(:selected_player_id, nil)
          |> put_flash(:error, "Could not assign player.")
          |> noreply()
      end
    else
      socket |> noreply()
    end
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  def handle_info(%Ash.Notifier.Notification{}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    socket
    |> load_board(group_id, current_user)
    |> noreply()
  end

  # ---------------------------------------------------------------------------
  # Board helpers
  # ---------------------------------------------------------------------------

  defp load_board(socket, group_id, current_user) do
    match = socket.assigns.match
    mode = match.team.lineup_assignment_mode

    lineup_columns =
      Tennis.list_lineup_columns_for_team!(match.team.id,
        tenant: group_id,
        actor: current_user
      )

    lineup_slots =
      Tennis.list_lineup_slots_for_team!(match.team.id,
        tenant: group_id,
        actor: current_user
      )

    assignments =
      Tennis.list_assignments_for_match!(match.id,
        tenant: group_id,
        actor: current_user,
        load: [:player, :team_lineup_slot]
      )

    memberships =
      Tennis.list_memberships_for_team!(match.team.id,
        tenant: group_id,
        actor: current_user,
        load: [:player]
      )

    all_players = memberships |> Enum.map(& &1.player) |> Enum.sort_by(& &1.name)

    excl_player_ids =
      assignments
      |> Enum.filter(& &1.team_lineup_slot.is_exclusion_slot)
      |> MapSet.new(& &1.player_id)

    playing_assignments = Enum.reject(assignments, & &1.team_lineup_slot.is_exclusion_slot)

    {available, player_column_assignments} =
      case mode do
        :one_per_match ->
          assigned_ids = MapSet.new(playing_assignments, & &1.player_id)

          avail =
            all_players
            |> Enum.reject(
              &(MapSet.member?(assigned_ids, &1.id) or MapSet.member?(excl_player_ids, &1.id))
            )

          {avail, %{}}

        :one_per_column ->
          avail = Enum.reject(all_players, &MapSet.member?(excl_player_ids, &1.id))

          col_map =
            Enum.group_by(playing_assignments, & &1.player_id)
            |> Map.new(fn {pid, plist} ->
              names =
                plist
                |> Enum.map(fn a ->
                  col =
                    Enum.find(
                      lineup_columns,
                      &(&1.id == a.team_lineup_slot.team_lineup_column_id)
                    )

                  col && col.name
                end)
                |> Enum.reject(&is_nil/1)
                |> Enum.uniq()

              {pid, names}
            end)

          {avail, col_map}

        :many_per_match ->
          avail = Enum.reject(all_players, &MapSet.member?(excl_player_ids, &1.id))
          {avail, %{}}
      end

    socket
    |> assign(:mode, mode)
    |> assign(:lineup_columns, lineup_columns)
    |> assign(:lineup_slots, lineup_slots)
    |> assign(:assignments, assignments)
    |> assign(:available, available)
    |> assign(:player_column_assignments, player_column_assignments)
  end

  defp do_slot_assignment(socket, match_id, player_id, slot_id, group_id, current_user) do
    mode = socket.assigns.mode

    case mode do
      :one_per_match ->
        Tennis.assign_to_slot(match_id, player_id, slot_id,
          tenant: group_id,
          actor: current_user
        )

      :one_per_column ->
        target_slot = Enum.find(socket.assigns.lineup_slots, &(&1.id == slot_id))

        if target_slot do
          existing_in_column =
            Enum.find(socket.assigns.assignments, fn a ->
              a.player_id == player_id &&
                !a.team_lineup_slot.is_exclusion_slot &&
                a.team_lineup_slot.team_lineup_column_id == target_slot.team_lineup_column_id
            end)

          cond do
            existing_in_column && existing_in_column.team_lineup_slot_id == slot_id ->
              {:ok, :no_change}

            existing_in_column ->
              Tennis.destroy_lineup_assignment!(existing_in_column,
                tenant: group_id,
                actor: current_user
              )

              Tennis.assign_to_slot(match_id, player_id, slot_id,
                tenant: group_id,
                actor: current_user
              )

            true ->
              Tennis.assign_to_slot(match_id, player_id, slot_id,
                tenant: group_id,
                actor: current_user
              )
          end
        else
          {:error, :slot_not_found}
        end

      :many_per_match ->
        already_in_slot =
          Enum.any?(socket.assigns.assignments, fn a ->
            a.player_id == player_id && a.team_lineup_slot_id == slot_id
          end)

        if already_in_slot do
          {:ok, :no_change}
        else
          Tennis.assign_to_slot(match_id, player_id, slot_id,
            tenant: group_id,
            actor: current_user
          )
        end
    end
  end

  defp slot_violations(slot, assignments) do
    if slot.expected_count do
      count = Enum.count(assignments, &(&1.team_lineup_slot_id == slot.id))

      if count != slot.expected_count do
        [
          %{
            level: :warning,
            message: "Expected #{slot.expected_count}, have #{count}"
          }
        ]
      else
        []
      end
    else
      []
    end
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <div class="flex flex-col h-[calc(100dvh-8rem)] lg:h-[calc(100dvh-4rem)] -mx-6 -my-8">
        <%!-- Header bar --%>
        <div class="flex items-center gap-3 py-3 px-4 flex-shrink-0">
          <.link
            navigate={~p"/g/#{@current_group.slug}/matches/#{@match.id}"}
            class="btn btn-sm btn-ghost"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>
          <span class="font-bold text-sm truncate">
            Edit Lineup
            <span :if={@match} class="font-normal text-base-content/50">
              — {@match.opponent}
            </span>
          </span>
        </div>

        <%!-- Empty state: no playable slots --%>
        <% has_playing_slots = Enum.any?(@lineup_slots, &(!&1.is_exclusion_slot)) %>
        <div :if={@match && not has_playing_slots} id="lineup-empty-state" class="px-4 py-6">
          <p class="text-sm text-base-content/50 mb-2">
            No lineup slots defined for this team.
          </p>
          <.link
            navigate={~p"/g/#{@current_group.slug}/teams/#{@match.team.id}/edit"}
            class="text-sm text-primary hover:underline"
          >
            Define slots on the team page
          </.link>
        </div>

        <%!-- Board --%>
        <div
          :if={has_playing_slots}
          class="flex-1 min-h-0 flex gap-3 overflow-x-auto pb-4 px-4 items-stretch"
        >
          <%!-- Available column --%>
          <.board_column
            id="col-available"
            title="Available"
            count={length(@available)}
            target_id="available"
            drop_event="move_lineup_player"
          >
            <.player_card
              :for={player <- @available}
              player={player}
              readonly={false}
              selected={@selected_player_id == player.id}
              column_badges={Map.get(@player_column_assignments, player.id, [])}
            />
          </.board_column>

          <%!-- Slot columns grouped by lineup column --%>
          <%= for column <- @lineup_columns do %>
            <% col_slots = Enum.filter(@lineup_slots, &(&1.team_lineup_column_id == column.id)) %>
            <.lineup_column_group
              :if={col_slots != []}
              id={"col-grp-#{column.id}"}
              column_name={column.name}
            >
              <%= for slot <- col_slots do %>
                <% slot_players =
                  @assignments
                  |> Enum.filter(&(&1.team_lineup_slot_id == slot.id))
                  |> Enum.map(& &1.player)
                  |> Enum.sort_by(& &1.name) %>
                <.lineup_slot_zone
                  id={"col-#{slot.id}"}
                  title={slot.name}
                  count={length(slot_players)}
                  target_id={slot.id}
                  violations={slot_violations(slot, @assignments)}
                  drop_event="move_lineup_player"
                  assign_event="assign_selected_player"
                >
                  <.player_card
                    :for={player <- slot_players}
                    player={player}
                    readonly={false}
                    selected={@selected_player_id == player.id}
                  />
                </.lineup_slot_zone>
              <% end %>
            </.lineup_column_group>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
