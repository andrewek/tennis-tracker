defmodule TennisTrackerWeb.Matches.LineupEditLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.BoardComponents
  import TennisTrackerWeb.MatchHelpers, only: [format_match_datetime: 2, format_home_or_away: 2]

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
    |> assign(:all_players, [])
    |> assign(:stats_open, false)
    |> assign(:stats_sort, :name)
    |> assign(:season_stats, nil)
    |> assign(:prev_match, nil)
    |> assign(:next_match, nil)
    |> assign(:neutral_slot_names, [])
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
        socket
        |> assign(:selected_player_id, nil)
        |> load_board(group_id, current_user)
        |> noreply()

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
        socket
        |> assign(:selected_player_id, nil)
        |> load_board(group_id, current_user)
        |> noreply()

      :ok ->
        socket
        |> assign(:selected_player_id, nil)
        |> load_board(group_id, current_user)
        |> noreply()

      {:error, _} ->
        socket |> put_flash(:error, "Could not update lineup.") |> noreply()
    end
  end

  def handle_event("select_player", %{"player_id" => player_id}, socket) do
    socket |> assign(:selected_player_id, player_id) |> noreply()
  end

  def handle_event("deselect_player", _params, socket) do
    socket |> assign(:selected_player_id, nil) |> noreply()
  end

  def handle_event("toggle_stats", _params, socket) do
    socket |> assign(:stats_open, !socket.assigns.stats_open) |> noreply()
  end

  def handle_event("set_stats_sort", %{"sort" => sort}, socket)
      when sort in ~w(name total_asc total_desc out_desc) do
    socket |> assign(:stats_sort, String.to_existing_atom(sort)) |> noreply()
  end

  def handle_event("set_stats_sort", _params, socket) do
    socket |> noreply()
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

    all_players = Enum.map(memberships, & &1.player)

    all_matches =
      Tennis.list_all_matches_for_team!(match.team.id,
        tenant: group_id,
        actor: current_user
      )

    current_index = Enum.find_index(all_matches, &(&1.id == match.id))

    prev_match =
      if current_index && current_index > 0, do: Enum.at(all_matches, current_index - 1)

    next_match =
      if current_index, do: Enum.at(all_matches, current_index + 1)

    season_stats =
      Tennis.season_stats_for_team!(match.team.id, all_matches,
        tenant: group_id,
        actor: current_user
      )

    neutral_slot_names =
      lineup_slots
      |> Enum.filter(&(&1.participation_type == :neutral))
      |> Enum.map(& &1.name)

    excl_player_ids =
      assignments
      |> Enum.filter(&(&1.team_lineup_slot.participation_type == :out))
      |> MapSet.new(& &1.player_id)

    playing_assignments =
      Enum.reject(assignments, &(&1.team_lineup_slot.participation_type == :out))

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
    |> assign(:all_players, all_players)
    |> assign(:player_column_assignments, player_column_assignments)
    |> assign(:prev_match, prev_match)
    |> assign(:next_match, next_match)
    |> assign(:season_stats, season_stats)
    |> assign(:neutral_slot_names, neutral_slot_names)
  end

  defp do_slot_assignment(socket, match_id, player_id, slot_id, group_id, current_user) do
    mode = socket.assigns.mode

    # Remove any exclusion slot (Out/Sub) assignments before reassigning.
    # This allows tap-to-assign to move a player from an exclusion slot to any other slot.
    excl_result =
      socket.assigns.assignments
      |> Enum.filter(
        &(&1.player_id == player_id && &1.team_lineup_slot.participation_type == :out)
      )
      |> Enum.reduce_while(:ok, fn assignment, :ok ->
        case Tennis.destroy_lineup_assignment(assignment, tenant: group_id, actor: current_user) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)

    with :ok <- excl_result do
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
                  a.team_lineup_slot.participation_type != :out &&
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
        <div class="flex items-center gap-2 py-3 px-4 flex-shrink-0">
          <.link
            navigate={~p"/g/#{@current_group.slug}/matches/#{@match.id}"}
            class="btn btn-sm btn-ghost"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back
          </.link>
          <span class="font-bold text-sm truncate flex-1">
            Edit Lineup
            <span :if={@match} class="font-normal text-base-content/50">
              — {@match.opponent}
            </span>
          </span>
          <%!-- Stats toggle --%>
          <button
            phx-click="toggle_stats"
            class={["btn btn-sm btn-ghost gap-1", @stats_open && "btn-active"]}
            id="stats-toggle"
            aria-label="Toggle stats"
          >
            <.icon name="hero-table-cells" class="size-4" />
            <span class="text-xs">Stats</span>
          </button>
        </div>
        <%!-- Match info --%>
        <% {date_str, time_str} = format_match_datetime(@match.match_start_datetime, @match.timezone) %>
        <div class="flex items-center gap-1.5 px-4 pb-2 text-xs text-base-content/60 flex-shrink-0">
          <span>{date_str}</span>
          <span>·</span>
          <span>{time_str}</span>
          <span>·</span>
          <span>{format_home_or_away(@match.home_or_away, @match.opponent)}</span>
          <%= if @match.location do %>
            <span>·</span>
            <span>{@match.location.name}</span>
          <% end %>
        </div>
        <%!-- Match navigation sub-bar --%>
        <div
          :if={@prev_match || @next_match}
          class="flex items-center justify-between px-4 pb-2 flex-shrink-0"
        >
          <div>
            <.link
              :if={@prev_match}
              navigate={~p"/g/#{@current_group.slug}/matches/#{@prev_match.id}/lineup-edit"}
              class="btn btn-sm btn-ghost"
              id="prev-match-link"
            >
              <.icon name="hero-arrow-left" class="size-4" /> Previous Match
            </.link>
          </div>
          <div>
            <.link
              :if={@next_match}
              navigate={~p"/g/#{@current_group.slug}/matches/#{@next_match.id}/lineup-edit"}
              class="btn btn-sm btn-ghost"
              id="next-match-link"
            >
              Next Match <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </div>

        <%!-- Empty state: no playable slots --%>
        <% has_playing_slots = Enum.any?(@lineup_slots, &(&1.participation_type != :out)) %>
        <div :if={@match && not has_playing_slots} id="lineup-empty-state" class="px-4 py-6">
          <p class="text-sm text-base-content/50 mb-2">
            No lineup slots defined for this team.
          </p>
          <.link
            navigate={~p"/g/#{@current_group.slug}/teams/#{@match.team.id}/settings"}
            class="text-sm text-primary hover:underline"
          >
            Define slots on the team page
          </.link>
        </div>

        <%!-- Board + optional stats drawer --%>
        <div :if={has_playing_slots} class="flex-1 min-h-0 flex overflow-hidden">
          <%!-- Board --%>
          <div class="flex-1 min-h-0 flex gap-3 overflow-x-auto pb-4 px-4 items-stretch">
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
                  >
                    <.player_card
                      :for={player <- slot_players}
                      player={player}
                      readonly={false}
                    />
                  </.lineup_slot_zone>
                <% end %>
              </.lineup_column_group>
            <% end %>
          </div>
          <%!-- Stats drawer - always in DOM so width transition plays on open/close --%>
          <.stats_drawer
            stats_open={@stats_open}
            season_stats={@season_stats}
            stats_sort={@stats_sort}
            all_players={@all_players}
            neutral_slot_names={@neutral_slot_names}
          />
        </div>

        <%!-- Tap-to-assign: player detail modal --%>
        <% selected_player =
          @selected_player_id &&
            (Enum.find(@available, &(&1.id == @selected_player_id)) ||
               @assignments
               |> Enum.find(&(&1.player_id == @selected_player_id))
               |> then(&(&1 && &1.player))) %>
        <.player_detail_modal
          :if={selected_player}
          player={selected_player}
          group_slug={@current_group.slug}
          on_close={JS.push("deselect_player")}
        >
          <:actions>
            <% current_slot_ids =
              @assignments
              |> Enum.filter(&(&1.player_id == @selected_player_id))
              |> Enum.map(& &1.team_lineup_slot_id) %>
            <% in_available = current_slot_ids == [] %>
            <button
              phx-click="move_lineup_player"
              phx-value-player_id={selected_player.id}
              phx-value-target_id="available"
              class={[
                "btn btn-sm w-full",
                if(in_available, do: "btn-primary", else: "btn-outline btn-primary")
              ]}
            >
              Available
            </button>
            <%= for column <- @lineup_columns do %>
              <% col_slots = Enum.filter(@lineup_slots, &(&1.team_lineup_column_id == column.id)) %>
              <%= for slot <- col_slots do %>
                <button
                  phx-click="move_lineup_player"
                  phx-value-player_id={selected_player.id}
                  phx-value-target_id={slot.id}
                  class={[
                    "btn btn-sm w-full",
                    if(slot.id in current_slot_ids,
                      do: "btn-primary",
                      else: "btn-outline btn-primary"
                    )
                  ]}
                >
                  {column.name} - {slot.name}
                </button>
              <% end %>
            <% end %>
          </:actions>
        </.player_detail_modal>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Stats drawer component
  # ---------------------------------------------------------------------------

  attr :stats_open, :boolean, required: true
  attr :season_stats, :map, default: nil
  attr :stats_sort, :atom, required: true
  attr :all_players, :list, required: true
  attr :neutral_slot_names, :list, required: true

  defp stats_drawer(assigns) do
    assigns = assign(assigns, :drawer_width, drawer_width(assigns.neutral_slot_names))

    ~H"""
    <%!-- Outer wrapper drives the width transition --%>
    <div style={"flex-shrink: 0; overflow: hidden; transition: width 300ms cubic-bezier(0.4,0,0.2,1); width: #{if @stats_open, do: @drawer_width, else: 0}px;"}>
      <div
        id="stats-drawer"
        data-open={to_string(@stats_open)}
        class="flex flex-col h-full border-l border-base-300 bg-base-200 overflow-y-auto"
        style={"width: #{@drawer_width}px; min-width: #{@drawer_width}px; box-shadow: -6px 0 24px rgba(0,0,0,0.25);"}
      >
        <%!-- Drawer header --%>
        <div class="flex items-center justify-between px-4 py-3 border-b border-base-300 bg-base-300/40 flex-shrink-0">
          <span class="font-semibold text-sm tracking-wide">Season Stats</span>
          <form phx-change="set_stats_sort">
            <.input
              type="select"
              id="stats-sort-select"
              name="sort"
              value={Atom.to_string(@stats_sort)}
              options={[
                {"Name A–Z", "name"},
                {"Fewest played", "total_asc"},
                {"Most played", "total_desc"},
                {"Most out", "out_desc"}
              ]}
              class="select select-xs"
            />
          </form>
        </div>
        <%!-- Table --%>
        <div :if={@season_stats} class="overflow-x-auto flex-1">
          <table class="table table-xs w-full">
            <thead class="sticky top-0 bg-base-200 z-10">
              <tr>
                <th class="bg-base-300/60">Name</th>
                <th class="bg-base-300/60 text-center" title="Past matches played">Played</th>
                <th class="bg-base-300/60 text-center" title="Future matches planned">Planned</th>
                <th class="bg-base-300/60 text-center" title="Played + Planned out of total">
                  Total
                </th>
                <th class="bg-base-300/60 text-center">Out</th>
                <th
                  :for={name <- @neutral_slot_names}
                  class="bg-base-300/60 text-center"
                  style="min-width: 72px"
                >
                  {name}
                </th>
              </tr>
            </thead>
            <tbody>
              <%= for {player, idx} <- Enum.with_index(sorted_players(@all_players, @season_stats, @stats_sort)) do %>
                <% stats =
                  Map.get(@season_stats.by_player, player.id, %{
                    played_past: 0,
                    played_future: 0,
                    out: 0,
                    neutral: %{}
                  }) %>
                <% total = stats.played_past + stats.played_future %>
                <tr
                  id={"stats-row-#{player.id}"}
                  class={[
                    "hover:bg-base-300/40 transition-colors",
                    rem(idx, 2) == 1 && "bg-base-300/20"
                  ]}
                >
                  <td class="truncate max-w-[9rem] font-medium">{player.name}</td>
                  <td class="text-center text-base-content/60">{stats.played_past}</td>
                  <td class="text-center font-medium">{stats.played_future}</td>
                  <td class="text-center text-base-content/70">
                    {total} / {@season_stats.total_matches}
                  </td>
                  <td class={["text-center", stats.out > 0 && "text-warning font-medium"]}>
                    {stats.out}
                  </td>
                  <td
                    :for={name <- @neutral_slot_names}
                    class="text-center text-base-content/70"
                  >
                    {Map.get(stats.neutral, name, 0)}
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp drawer_width(neutral_slot_names) do
    # Base covers Name + Played + Planned + Total + Out columns
    # Each neutral slot adds a fixed column width
    336 + length(neutral_slot_names) * 90
  end

  defp sorted_players(all_players, season_stats, sort) do
    by_player = season_stats.by_player

    case sort do
      :name ->
        Enum.sort_by(all_players, & &1.name)

      :total_asc ->
        Enum.sort_by(all_players, fn p ->
          stats = Map.get(by_player, p.id, %{played_past: 0, played_future: 0})
          {stats.played_past + stats.played_future, p.name}
        end)

      :total_desc ->
        Enum.sort_by(all_players, fn p ->
          stats = Map.get(by_player, p.id, %{played_past: 0, played_future: 0})
          {-(stats.played_past + stats.played_future), p.name}
        end)

      :out_desc ->
        Enum.sort_by(all_players, fn p ->
          stats = Map.get(by_player, p.id, %{out: 0})
          {-stats.out, p.name}
        end)
    end
  end
end
