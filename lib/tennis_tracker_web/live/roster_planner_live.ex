defmodule TennisTrackerWeb.RosterPlannerLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.BoardComponents

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{RosterHealth, Team}
  alias AshPhoenix.Form

  # ---------------------------------------------------------------------------
  # Mount / Params
  # ---------------------------------------------------------------------------

  def mount(_params, _session, socket) do
    team_types = Tennis.list_team_types!()
    planning_contexts = Tennis.list_planning_contexts()

    socket
    |> assign(:page_title, "Roster Planner")
    |> assign(:team_types, team_types)
    |> assign(:planning_contexts, planning_contexts)
    |> assign(:show_create_form, false)
    |> assign(:context, nil)
    |> assign(:board, nil)
    |> assign(:season_year_input, "2026")
    |> assign(:selected_team_type_id, nil)
    |> assign(:selected_player_id, nil)
    |> assign(:selected_player, nil)
    |> assign(:team_modal, nil)
    |> assign(:show_season_rules, false)
    |> ok()
  end

  def handle_params(
        %{"team_type_id" => team_type_id, "season_year" => season_year_str},
        _url,
        socket
      ) do
    case Integer.parse(season_year_str) do
      {season_year, ""} ->
        team_type = Tennis.get_team_type!(team_type_id)
        {:ok, pseudo_team} = Tennis.ensure_pseudo_team(team_type_id, season_year)
        topic = topic(team_type_id, season_year)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(TennisTracker.PubSub, topic)
        end

        {:ok, season_rules} = Tennis.get_season_rules_for_context(team_type_id, season_year)
        board = load_board(team_type_id, season_year, pseudo_team, team_type, season_rules)

        socket
        |> assign(:context, %{
          team_type: team_type,
          team_type_id: team_type_id,
          season_year: season_year,
          pseudo_team: pseudo_team,
          season_rules: season_rules
        })
        |> assign(:board, board)
        |> noreply()

      _ ->
        socket
        |> push_navigate(to: ~p"/roster-planner")
        |> noreply()
    end
  end

  def handle_params(_params, _url, socket) do
    socket |> noreply()
  end

  # ---------------------------------------------------------------------------
  # Events — context selector
  # ---------------------------------------------------------------------------

  def handle_event("select_context", %{"team_type_id" => ttid, "season_year" => year}, socket) do
    socket
    |> push_navigate(to: ~p"/roster-planner/#{ttid}/#{year}")
    |> noreply()
  end

  def handle_event("update_season_year", %{"value" => val}, socket) do
    socket
    |> assign(:season_year_input, val)
    |> noreply()
  end

  def handle_event("show_create_form", _params, socket) do
    socket
    |> assign(:show_create_form, true)
    |> noreply()
  end

  def handle_event("hide_create_form", _params, socket) do
    socket
    |> assign(:show_create_form, false)
    |> noreply()
  end

  def handle_event("show_season_rules", _params, socket) do
    socket
    |> assign(:show_season_rules, true)
    |> noreply()
  end

  def handle_event("hide_season_rules", _params, socket) do
    socket
    |> assign(:show_season_rules, false)
    |> noreply()
  end

  # ---------------------------------------------------------------------------
  # Events — player selection (mobile tap-to-assign)
  # ---------------------------------------------------------------------------

  def handle_event("select_player", %{"player_id" => player_id}, socket) do
    player = find_player_in_board(socket.assigns.board, player_id)

    socket
    |> assign(:selected_player_id, player_id)
    |> assign(:selected_player, player)
    |> noreply()
  end

  def handle_event("deselect_player", _params, socket) do
    socket
    |> assign(:selected_player_id, nil)
    |> assign(:selected_player, nil)
    |> noreply()
  end

  # ---------------------------------------------------------------------------
  # Events — move player (drag-and-drop + tap-to-assign)
  # ---------------------------------------------------------------------------

  def handle_event(
        "move_player",
        %{"player_id" => player_id, "target_id" => "unassigned"},
        socket
      ) do
    ctx = socket.assigns.context
    Tennis.unassign_player(player_id, ctx.team_type_id, ctx.season_year)
    # Board reload is driven by the PubSub notification from the Ash action
    socket
    |> assign(:selected_player_id, nil)
    |> assign(:selected_player, nil)
    |> noreply()
  end

  def handle_event(
        "move_player",
        %{"player_id" => player_id, "target_id" => target_id},
        socket
      ) do
    ctx = socket.assigns.context
    Tennis.assign_player(player_id, target_id, ctx.team_type_id, ctx.season_year)
    # Board reload is driven by the PubSub notification from the Ash action
    socket
    |> assign(:selected_player_id, nil)
    |> assign(:selected_player, nil)
    |> noreply()
  end

  # ---------------------------------------------------------------------------
  # Events — team modal
  # ---------------------------------------------------------------------------

  def handle_event("open_team_modal", %{"mode" => "create"}, socket) do
    ctx = socket.assigns.context

    form =
      Form.for_create(Team, :create,
        domain: Tennis,
        as: "team",
        prepare_source: fn changeset ->
          Ash.Changeset.set_argument(changeset, :team_type_id, ctx.team_type_id)
          |> Ash.Changeset.force_change_attribute(:team_type_id, ctx.team_type_id)
          |> Ash.Changeset.force_change_attribute(:season_year, ctx.season_year)
          |> Ash.Changeset.force_change_attribute(:is_pseudo, false)
        end
      )
      |> to_form()

    socket
    |> assign(:team_modal, %{mode: :create, form: form, team: nil})
    |> noreply()
  end

  def handle_event("open_team_modal", %{"mode" => "edit", "team_id" => team_id}, socket) do
    entry = Enum.find(socket.assigns.board.real_teams, &(&1.team.id == team_id))

    if entry do
      form = Form.for_update(entry.team, :update, domain: Tennis, as: "team") |> to_form()

      socket
      |> assign(:team_modal, %{mode: :edit, form: form, team: entry.team})
      |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_event("open_team_modal", %{"mode" => "delete", "team_id" => team_id}, socket) do
    entry = Enum.find(socket.assigns.board.real_teams, &(&1.team.id == team_id))

    if entry do
      socket
      |> assign(:team_modal, %{mode: :delete, form: nil, team: entry.team})
      |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_event("close_team_modal", _params, socket) do
    socket
    |> assign(:team_modal, nil)
    |> noreply()
  end

  def handle_event("validate_team_form", %{"team" => params}, socket) do
    modal = socket.assigns.team_modal
    form = Form.validate(modal.form.source, params) |> to_form()

    socket
    |> assign(:team_modal, %{modal | form: form})
    |> noreply()
  end

  def handle_event("submit_team_form", %{"team" => params}, socket) do
    ctx = socket.assigns.context
    modal = socket.assigns.team_modal

    extra_params =
      if modal.mode == :create do
        %{
          "team_type_id" => ctx.team_type_id,
          "season_year" => ctx.season_year,
          "is_pseudo" => false
        }
      else
        %{}
      end

    case Form.submit(modal.form.source, params: Map.merge(params, extra_params)) do
      {:ok, _team} ->
        socket
        |> assign(:team_modal, nil)
        |> reload_board(ctx)
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:team_modal, %{modal | form: to_form(form)})
        |> noreply()
    end
  end

  def handle_event("confirm_delete_team", %{"team_id" => team_id}, socket) do
    ctx = socket.assigns.context

    team =
      socket.assigns.board.real_teams
      |> Enum.find(&(&1.team.id == team_id))
      |> then(fn
        nil -> nil
        entry -> entry.team
      end)

    if team do
      Tennis.delete_team(team)
    end

    socket
    |> assign(:team_modal, nil)
    |> reload_board(ctx)
    |> noreply()
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  def handle_info(%Ash.Notifier.Notification{}, socket) do
    ctx = socket.assigns.context

    if ctx do
      socket
      |> reload_board(ctx)
      |> noreply()
    else
      socket |> noreply()
    end
  end

  # ---------------------------------------------------------------------------
  # Board helpers
  # ---------------------------------------------------------------------------

  defp topic(team_type_id, season_year), do: "roster:#{team_type_id}:#{season_year}"

  defp find_player_in_board(board, player_id) do
    all_players =
      board.unassigned ++
        board.not_participating ++
        Enum.flat_map(board.real_teams, & &1.players)

    Enum.find(all_players, &(&1.id == player_id))
  end

  defp reload_board(socket, ctx) do
    board =
      load_board(
        ctx.team_type_id,
        ctx.season_year,
        ctx.pseudo_team,
        ctx.team_type,
        ctx.season_rules
      )

    assign(socket, :board, board)
  end

  defp load_board(team_type_id, season_year, pseudo_team, team_type, season_rules) do
    {:ok, all_teams} = Tennis.list_teams_for_context(team_type_id, season_year)
    {:ok, all_memberships} = Tennis.list_memberships_for_context(team_type_id, season_year)

    real_teams = Enum.reject(all_teams, & &1.is_pseudo)
    unassigned = Tennis.list_eligible_unassigned_players(team_type, team_type_id, season_year)

    not_participating =
      all_memberships
      |> Enum.filter(fn m -> m.team_id == pseudo_team.id end)
      |> Enum.map(& &1.player)
      |> Enum.sort_by(& &1.name)

    team_with_players =
      Enum.map(real_teams, fn team ->
        players =
          all_memberships
          |> Enum.filter(fn m -> m.team_id == team.id end)
          |> Enum.map(& &1.player)
          |> Enum.sort_by(& &1.name)

        team_with_type = Map.put(team, :team_type, team_type)

        health = RosterHealth.check(team_with_type, players, season_rules)

        player_violation_ids =
          health
          |> Enum.filter(& &1.player_id)
          |> Enum.map(& &1.player_id)
          |> MapSet.new()

        team_violations = Enum.reject(health, & &1.player_id)

        %{
          team: team,
          players: players,
          team_violations: team_violations,
          player_violation_ids: player_violation_ids
        }
      end)

    %{
      real_teams: team_with_players,
      unassigned: unassigned,
      not_participating: not_participating,
      pseudo_team: pseudo_team
    }
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def render(assigns) do
    ~H"""
    <Layouts.full_bleed flash={@flash} current_user={@current_user}>
      <div class="h-full flex flex-col">
      <%!-- Page title bar --%>
      <div class="flex items-center gap-4 py-3 px-4 flex-shrink-0">
        <span class="font-bold text-lg">Roster Planner</span>
        <span :if={@context} class="text-base-content/50 text-sm">
          {@context.team_type.name} · {@context.season_year}
        </span>
        <button
          :if={@context}
          phx-click="show_season_rules"
          class="btn btn-xs btn-ghost btn-circle text-base-content/50 hover:text-base-content"
          aria-label="View season rules"
        >
          <.icon name="hero-information-circle" class="size-4" />
        </button>
      </div>

      <%!-- Context selector (shown when no context loaded) --%>
      <div :if={is_nil(@context)} class="px-4">
        <p class="text-base-content/60 text-sm mb-6">
          Select a planning session to continue, or start a new one.
        </p>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          <%!-- Existing context cards --%>
          <.link
            :for={ctx <- @planning_contexts}
            navigate={~p"/roster-planner/#{ctx.team_type_id}/#{ctx.season_year}"}
            class="card bg-base-200 hover:bg-base-300 transition-colors cursor-pointer"
          >
            <div class="card-body p-4">
              <p class="font-semibold text-sm">{ctx.team_type.name}</p>
              <p class="text-xs text-base-content/50">{ctx.season_year}</p>
            </div>
          </.link>

          <%!-- New session card — collapsed --%>
          <div
            :if={not @show_create_form}
            phx-click="show_create_form"
            class="card border-2 border-dashed border-base-300 hover:border-primary transition-colors cursor-pointer"
          >
            <div class="card-body p-4 items-center justify-center text-center">
              <span class="text-2xl text-base-content/30 leading-none">+</span>
              <p class="text-xs text-base-content/50 mt-1">New session</p>
            </div>
          </div>

          <%!-- New session card — expanded with form --%>
          <div
            :if={@show_create_form}
            class="card bg-base-200 border-2 border-primary col-span-2"
          >
            <div class="card-body p-4">
              <p class="font-semibold text-sm mb-3">New Planning Session</p>
              <form phx-submit="select_context" class="space-y-3">
                <div>
                  <label class="label py-0 mb-1">
                    <span class="label-text text-xs">Team Type</span>
                  </label>
                  <select name="team_type_id" class="select select-bordered select-sm w-full" required>
                    <option value="">Select...</option>
                    <%= for tt <- @team_types do %>
                      <option value={tt.id}>{tt.name}</option>
                    <% end %>
                  </select>
                </div>
                <div>
                  <label class="label py-0 mb-1">
                    <span class="label-text text-xs">Season Year</span>
                  </label>
                  <input
                    type="number"
                    name="season_year"
                    value={@season_year_input}
                    min="2020"
                    max="2040"
                    class="input input-bordered input-sm w-full"
                    required
                  />
                </div>
                <div class="flex gap-2 pt-1">
                  <button type="submit" class="btn btn-primary btn-sm flex-1">Open</button>
                  <button type="button" phx-click="hide_create_form" class="btn btn-ghost btn-sm">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      </div>

      <%!-- Planning board --%>
      <div :if={@board} class="flex-1 min-h-0 flex flex-col">
        <%!-- Board toolbar --%>
        <div class="flex items-center gap-6 mb-4 px-4 flex-shrink-0">
          <.link navigate={~p"/roster-planner"} class="btn btn-sm btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Change context
          </.link>
        </div>

        <%!-- Board columns --%>
        <div class="flex-1 min-h-0 flex gap-3 overflow-x-auto pb-4 px-4 items-stretch">
          <%!-- Unassigned column --%>
          <.board_column
            id="col-unassigned"
            title="Unassigned"
            count={length(@board.unassigned)}
            target_id="unassigned"
            violations={[]}
          >
            <.player_card
              :for={player <- @board.unassigned}
              player={player}
              has_violation={false}
              selected={@selected_player_id == player.id}
            />
          </.board_column>

          <%!-- Real team columns --%>
          <%= for %{team: team, players: players, team_violations: violations, player_violation_ids: violation_ids} <- @board.real_teams do %>
            <.board_column
              id={"col-#{team.id}"}
              title={team.name}
              count={length(players)}
              target_id={team.id}
              violations={violations}
            >
              <:header_actions>
                <button
                  :if={is_nil(@team_modal)}
                  phx-click="open_team_modal"
                  phx-value-mode="edit"
                  phx-value-team_id={team.id}
                  class="btn btn-xs btn-ghost opacity-50 hover:opacity-100 ml-auto"
                  aria-label="Rename team"
                >
                  <.icon name="hero-pencil-square" class="size-3.5" />
                  <span class="sr-only">Rename team</span>
                </button>
                <button
                  :if={is_nil(@team_modal)}
                  phx-click="open_team_modal"
                  phx-value-mode="delete"
                  phx-value-team_id={team.id}
                  class="btn btn-xs btn-ghost opacity-50 hover:opacity-100"
                  aria-label="Delete team"
                >
                  <.icon name="hero-trash" class="size-3.5" />
                  <span class="sr-only">Delete team</span>
                </button>
              </:header_actions>
              <.player_card
                :for={player <- players}
                player={player}
                has_violation={MapSet.member?(violation_ids, player.id)}
                selected={@selected_player_id == player.id}
              />
            </.board_column>
          <% end %>

          <%!-- Not Participating column --%>
          <.board_column
            id={"col-#{@board.pseudo_team.id}"}
            title="Not Participating"
            count={length(@board.not_participating)}
            target_id={@board.pseudo_team.id}
            violations={[]}
          >
            <.player_card
              :for={player <- @board.not_participating}
              player={player}
              has_violation={false}
              selected={@selected_player_id == player.id}
            />
          </.board_column>

          <%!-- New Team button --%>
          <div
            id="col-new-team"
            phx-click="open_team_modal"
            phx-value-mode="create"
            class="flex-shrink-0 w-56 border-2 border-dashed border-base-300 hover:border-primary transition-colors cursor-pointer rounded-lg"
          >
            <div class="flex flex-col items-center justify-center text-center h-20">
              <span class="text-2xl text-base-content/30 leading-none">+</span>
              <p class="text-xs text-base-content/50 mt-1">New team</p>
            </div>
          </div>
        </div>

        <%!-- Mobile: destination picker modal --%>
        <.player_detail_modal :if={@selected_player_id} player={@selected_player}>
          <:actions>
            <button
              phx-click="move_player"
              phx-value-player_id={@selected_player_id}
              phx-value-target_id="unassigned"
              class="btn btn-outline btn-sm w-full"
            >
              Unassigned
            </button>
            <button
              :for={%{team: team} <- @board.real_teams}
              phx-click="move_player"
              phx-value-player_id={@selected_player_id}
              phx-value-target_id={team.id}
              class="btn btn-primary btn-sm w-full"
            >
              {team.name}
            </button>
            <button
              phx-click="move_player"
              phx-value-player_id={@selected_player_id}
              phx-value-target_id={@board.pseudo_team.id}
              class="btn btn-outline btn-secondary btn-sm w-full"
            >
              Not Participating
            </button>
          </:actions>
        </.player_detail_modal>

        <%!-- Team modal (create / edit / delete) --%>
        <div
          :if={@team_modal}
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
        >
          <div
            class="bg-base-100 rounded-2xl w-full max-w-sm p-6 shadow-xl"
            phx-click-away="close_team_modal"
          >
            <%= cond do %>
              <% @team_modal.mode == :create -> %>
                <h3 class="font-semibold text-lg mb-4">New Team</h3>
                <.form
                  for={@team_modal.form}
                  phx-change="validate_team_form"
                  phx-submit="submit_team_form"
                >
                  <div class="mb-4">
                    <label class="label py-0 mb-1">
                      <span class="label-text">Team Name</span>
                    </label>
                    <input
                      type="text"
                      name={@team_modal.form[:name].name}
                      value={Phoenix.HTML.Form.input_value(@team_modal.form, :name)}
                      placeholder="e.g. Team Alpha"
                      autofocus
                      class={[
                        "input input-bordered w-full",
                        @team_modal.form[:name].errors != [] && "input-error"
                      ]}
                    />
                    <p
                      :for={error <- @team_modal.form[:name].errors}
                      class="text-error text-xs mt-1"
                    >
                      {elem(error, 0)}
                    </p>
                  </div>
                  <div class="flex gap-2">
                    <button type="submit" class="btn btn-primary flex-1">Create</button>
                    <button
                      type="button"
                      phx-click="close_team_modal"
                      class="btn btn-ghost"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              <% @team_modal.mode == :edit -> %>
                <h3 class="font-semibold text-lg mb-4">Rename Team</h3>
                <.form
                  for={@team_modal.form}
                  phx-change="validate_team_form"
                  phx-submit="submit_team_form"
                >
                  <div class="mb-4">
                    <label class="label py-0 mb-1">
                      <span class="label-text">Team Name</span>
                    </label>
                    <input
                      type="text"
                      name={@team_modal.form[:name].name}
                      value={Phoenix.HTML.Form.input_value(@team_modal.form, :name)}
                      autofocus
                      class={[
                        "input input-bordered w-full",
                        @team_modal.form[:name].errors != [] && "input-error"
                      ]}
                    />
                    <p
                      :for={error <- @team_modal.form[:name].errors}
                      class="text-error text-xs mt-1"
                    >
                      {elem(error, 0)}
                    </p>
                  </div>
                  <div class="flex gap-2">
                    <button type="submit" class="btn btn-primary flex-1">Save</button>
                    <button
                      type="button"
                      phx-click="close_team_modal"
                      class="btn btn-ghost"
                    >
                      Cancel
                    </button>
                  </div>
                </.form>
              <% @team_modal.mode == :delete -> %>
                <h3 class="font-semibold text-lg mb-2">Delete Team</h3>
                <p class="text-sm text-base-content/70 mb-6">
                  Delete <strong>{@team_modal.team.name}</strong>? All player assignments will be removed and those players will return to Unassigned. This cannot be undone.
                </p>
                <div class="flex gap-2">
                  <button
                    phx-click="confirm_delete_team"
                    phx-value-team_id={@team_modal.team.id}
                    class="btn btn-error flex-1"
                  >
                    Delete
                  </button>
                  <button
                    phx-click="close_team_modal"
                    class="btn btn-ghost"
                  >
                    Cancel
                  </button>
                </div>
            <% end %>
          </div>
        </div>
        <%!-- Season rules info modal --%>
        <div
          :if={@show_season_rules}
          class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
          phx-click="hide_season_rules"
        >
          <div
            class="bg-base-100 rounded-2xl w-full max-w-xs p-6 shadow-xl"
            phx-click-away="hide_season_rules"
          >
            <div class="flex items-center justify-between mb-4">
              <h3 class="font-semibold text-lg">Season Rules</h3>
              <button phx-click="hide_season_rules" class="btn btn-xs btn-ghost btn-circle">
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
            <dl class="space-y-3 text-sm">
              <div class="flex justify-between">
                <dt class="text-base-content/60">NTRP range</dt>
                <dd class="font-medium">
                  <%= cond do %>
                    <% @context.team_type.allowed_ntrp_levels == [] -> %>
                      N/A
                    <% true -> %>
                      {Enum.min(@context.team_type.allowed_ntrp_levels)} – {Enum.max(@context.team_type.allowed_ntrp_levels)}
                  <% end %>
                </dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-base-content/60">On-level minimum</dt>
                <dd class="font-medium">
                  <%= if @context.season_rules && @context.season_rules.on_level_min_pct do %>
                    {Decimal.mult(@context.season_rules.on_level_min_pct, 100) |> Decimal.round(0)}%
                  <% else %>
                    N/A
                  <% end %>
                </dd>
              </div>
              <div class="flex justify-between">
                <dt class="text-base-content/60">Roster size</dt>
                <dd class="font-medium">
                  <%= cond do %>
                    <% @context.season_rules &&
                        @context.season_rules.min_roster &&
                        @context.season_rules.max_roster -> %>
                      {@context.season_rules.min_roster} – {@context.season_rules.max_roster}
                    <% @context.season_rules && @context.season_rules.min_roster -> %>
                      {@context.season_rules.min_roster}+ players
                    <% @context.season_rules && @context.season_rules.max_roster -> %>
                      Up to {@context.season_rules.max_roster} players
                    <% true -> %>
                      N/A
                  <% end %>
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
      </div>
    </Layouts.full_bleed>
    """
  end
end
