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
    |> assign(:lineup_slots, [])
    |> assign(:assignments, [])
    |> assign(:available, [])
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

    case Tennis.assign_to_slot(match.id, player_id, slot_id,
           tenant: group_id,
           actor: current_user
         ) do
      {:ok, _} ->
        # Board reload driven by PubSub notification
        socket |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Could not update lineup.") |> noreply()
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

    assigned_player_ids = MapSet.new(assignments, & &1.player_id)

    available =
      memberships
      |> Enum.reject(&MapSet.member?(assigned_player_ids, &1.player_id))
      |> Enum.map(& &1.player)
      |> Enum.sort_by(& &1.name)

    socket
    |> assign(:lineup_slots, lineup_slots)
    |> assign(:assignments, assignments)
    |> assign(:available, available)
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

        <%!-- Empty state: no slots --%>
        <div :if={@match && @lineup_slots == []} class="px-4 py-6">
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
          :if={@lineup_slots != []}
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
            />
          </.board_column>

          <%!-- Slot columns --%>
          <%= for slot <- @lineup_slots do %>
            <% slot_players =
              @assignments
              |> Enum.filter(&(&1.team_lineup_slot_id == slot.id))
              |> Enum.map(& &1.player)
              |> Enum.sort_by(& &1.name) %>
            <.board_column
              id={"col-#{slot.id}"}
              title={slot.name}
              count={length(slot_players)}
              target_id={slot.id}
              violations={slot_violations(slot, @assignments)}
              drop_event="move_lineup_player"
            >
              <.player_card
                :for={player <- slot_players}
                player={player}
                readonly={false}
              />
            </.board_column>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
