defmodule TennisTrackerWeb.RosterPlannerLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{RosterHealth, Team}
  alias AshPhoenix.Form

  # ---------------------------------------------------------------------------
  # Mount / Params
  # ---------------------------------------------------------------------------

  def mount(_params, _session, socket) do
    team_types = Tennis.list_team_types!()
    planning_contexts = Tennis.list_planning_contexts()

    {:ok,
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
     |> assign(:team_modal, nil)}
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

        {:noreply,
         socket
         |> assign(:context, %{
           team_type: team_type,
           team_type_id: team_type_id,
           season_year: season_year,
           pseudo_team: pseudo_team,
           season_rules: season_rules
         })
         |> assign(:board, board)}

      _ ->
        {:noreply, push_navigate(socket, to: ~p"/roster-planner")}
    end
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Events — context selector
  # ---------------------------------------------------------------------------

  def handle_event("select_context", %{"team_type_id" => ttid, "season_year" => year}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/roster-planner/#{ttid}/#{year}")}
  end

  def handle_event("update_season_year", %{"value" => val}, socket) do
    {:noreply, assign(socket, :season_year_input, val)}
  end

  def handle_event("show_create_form", _params, socket) do
    {:noreply, assign(socket, :show_create_form, true)}
  end

  def handle_event("hide_create_form", _params, socket) do
    {:noreply, assign(socket, :show_create_form, false)}
  end

  # ---------------------------------------------------------------------------
  # Events — player selection (mobile tap-to-assign)
  # ---------------------------------------------------------------------------

  def handle_event("select_player", %{"player_id" => player_id}, socket) do
    {:noreply, assign(socket, :selected_player_id, player_id)}
  end

  def handle_event("deselect_player", _params, socket) do
    {:noreply, assign(socket, :selected_player_id, nil)}
  end

  # ---------------------------------------------------------------------------
  # Events — move player (drag-and-drop + tap-to-assign)
  # ---------------------------------------------------------------------------

  def handle_event("move_player", %{"player_id" => player_id, "team_id" => "unassigned"}, socket) do
    ctx = socket.assigns.context
    Tennis.unassign_player(player_id, ctx.team_type_id, ctx.season_year)
    {:noreply, socket |> assign(:selected_player_id, nil) |> reload_board(ctx)}
  end

  def handle_event("move_player", %{"player_id" => player_id, "team_id" => team_id}, socket) do
    ctx = socket.assigns.context
    Tennis.assign_player(player_id, team_id, ctx.team_type_id, ctx.season_year)
    {:noreply, socket |> assign(:selected_player_id, nil) |> reload_board(ctx)}
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

    {:noreply, assign(socket, :team_modal, %{mode: :create, form: form, team: nil})}
  end

  def handle_event("open_team_modal", %{"mode" => "edit", "team_id" => team_id}, socket) do
    entry = Enum.find(socket.assigns.board.real_teams, &(&1.team.id == team_id))

    if entry do
      form = Form.for_update(entry.team, :update, domain: Tennis, as: "team") |> to_form()
      {:noreply, assign(socket, :team_modal, %{mode: :edit, form: form, team: entry.team})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("open_team_modal", %{"mode" => "delete", "team_id" => team_id}, socket) do
    entry = Enum.find(socket.assigns.board.real_teams, &(&1.team.id == team_id))

    if entry do
      {:noreply, assign(socket, :team_modal, %{mode: :delete, form: nil, team: entry.team})}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_team_modal", _params, socket) do
    {:noreply, assign(socket, :team_modal, nil)}
  end

  def handle_event("validate_team_form", %{"team" => params}, socket) do
    modal = socket.assigns.team_modal
    form = Form.validate(modal.form.source, params) |> to_form()
    {:noreply, assign(socket, :team_modal, %{modal | form: form})}
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
        {:noreply, socket |> assign(:team_modal, nil) |> reload_board(ctx)}

      {:error, form} ->
        {:noreply, assign(socket, :team_modal, %{modal | form: to_form(form)})}
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

    {:noreply, socket |> assign(:team_modal, nil) |> reload_board(ctx)}
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  def handle_info(%Ash.Notifier.Notification{}, socket) do
    ctx = socket.assigns.context

    if ctx do
      {:noreply, reload_board(socket, ctx)}
    else
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Board helpers
  # ---------------------------------------------------------------------------

  defp topic(team_type_id, season_year), do: "roster:#{team_type_id}:#{season_year}"

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
    <Layouts.app flash={@flash} fluid={true}>
      <.header>
        Roster Planner
        <:subtitle :if={@context}>
          {@context.team_type.name} · {@context.season_year}
        </:subtitle>
      </.header>

      <%!-- Context selector (shown when no context loaded) --%>
      <div :if={is_nil(@context)} class="mt-6">
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
      <div :if={@board} class="mt-4">
        <%!-- Board toolbar --%>
        <div class="flex items-center gap-6 mb-4">
          <.link navigate={~p"/roster-planner"} class="btn btn-sm btn-ghost">
            <.icon name="hero-arrow-left" class="size-4" /> Change context
          </.link>
        </div>

        <%!-- Board columns --%>
        <div class="flex gap-3 overflow-x-auto pb-4 items-start">
          <%!-- Unassigned column --%>
          <.board_column
            id="col-unassigned"
            title="Unassigned"
            count={length(@board.unassigned)}
            team_id="unassigned"
            violations={[]}
            selected_player_id={@selected_player_id}
          >
            <.player_card
              :for={player <- @board.unassigned}
              player={player}
              has_violation={false}
              selected={@selected_player_id == player.id}
              column_id="unassigned"
            />
          </.board_column>

          <%!-- Real team columns --%>
          <%= for %{team: team, players: players, team_violations: violations, player_violation_ids: violation_ids} <- @board.real_teams do %>
            <.board_column
              id={"col-#{team.id}"}
              title={team.name}
              count={length(players)}
              team_id={team.id}
              violations={violations}
              selected_player_id={@selected_player_id}
              team={team}
              deletable={true}
              modal_open={not is_nil(@team_modal)}
            >
              <.player_card
                :for={player <- players}
                player={player}
                has_violation={MapSet.member?(violation_ids, player.id)}
                selected={@selected_player_id == player.id}
                column_id={team.id}
              />
            </.board_column>
          <% end %>

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

          <%!-- Not Participating column --%>
          <.board_column
            id={"col-#{@board.pseudo_team.id}"}
            title="Not Participating"
            count={length(@board.not_participating)}
            team_id={@board.pseudo_team.id}
            violations={[]}
            selected_player_id={@selected_player_id}
          >
            <.player_card
              :for={player <- @board.not_participating}
              player={player}
              has_violation={false}
              selected={@selected_player_id == player.id}
              column_id={@board.pseudo_team.id}
            />
          </.board_column>
        </div>

        <%!-- Mobile: destination picker modal --%>
        <div
          :if={@selected_player_id}
          class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40"
          phx-click="deselect_player"
        >
          <div
            class="bg-base-100 rounded-t-2xl sm:rounded-2xl w-full sm:max-w-sm p-4 shadow-xl"
            phx-click-away="deselect_player"
          >
            <div class="flex items-center justify-between mb-4">
              <p class="font-semibold">Move to...</p>
              <button
                phx-click="deselect_player"
                class="btn btn-ghost btn-xs btn-circle"
                aria-label="Close"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>
            <div class="space-y-2">
              <button
                phx-click="move_player"
                phx-value-player_id={@selected_player_id}
                phx-value-team_id="unassigned"
                class="btn btn-outline btn-sm w-full"
              >
                Unassigned
              </button>
              <button
                :for={%{team: team} <- @board.real_teams}
                phx-click="move_player"
                phx-value-player_id={@selected_player_id}
                phx-value-team_id={team.id}
                class="btn btn-primary btn-sm w-full"
              >
                {team.name}
              </button>
              <button
                phx-click="move_player"
                phx-value-player_id={@selected_player_id}
                phx-value-team_id={@board.pseudo_team.id}
                class="btn btn-outline btn-secondary btn-sm w-full"
              >
                Not Participating
              </button>
            </div>
            <div class="divider my-2"></div>
            <button phx-click="deselect_player" class="btn btn-ghost btn-sm w-full">
              Cancel
            </button>
          </div>
        </div>

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
      </div>
    </Layouts.app>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".RosterDrag">
      export default {
        mounted() {
          this.el.addEventListener("dragstart", (e) => {
            const playerId = this.el.dataset.playerId
            e.dataTransfer.setData("text/plain", playerId)
            e.dataTransfer.effectAllowed = "move"
          })
        }
      }
    </script>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".RosterDrop">
      export default {
        mounted() {
          this.el.addEventListener("dragover", (e) => {
            e.preventDefault()
            e.dataTransfer.dropEffect = "move"
            this.el.classList.add("ring-2", "ring-primary")
          })
          this.el.addEventListener("dragleave", (e) => {
            if (!this.el.contains(e.relatedTarget)) {
              this.el.classList.remove("ring-2", "ring-primary")
            }
          })
          this.el.addEventListener("drop", (e) => {
            e.preventDefault()
            this.el.classList.remove("ring-2", "ring-primary")
            const playerId = e.dataTransfer.getData("text/plain")
            const teamId = this.el.dataset.teamId
            if (playerId && teamId) {
              this.pushEvent("move_player", { player_id: playerId, team_id: teamId })
            }
          })
        }
      }
    </script>
    """
  end

  # ---------------------------------------------------------------------------
  # Components
  # ---------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :title, :any, required: true
  attr :count, :integer, required: true
  attr :team_id, :string, required: true
  attr :violations, :list, default: []
  attr :selected_player_id, :string, default: nil
  attr :team, :map, default: nil
  attr :deletable, :boolean, default: false
  attr :modal_open, :boolean, default: false
  slot :inner_block, required: true

  defp board_column(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex-shrink-0 w-56 bg-base-200 rounded-lg p-2"
      phx-hook=".RosterDrop"
      data-team-id={@team_id}
    >
      <%!-- Column header --%>
      <div class="flex items-center justify-between mb-2 px-1">
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-1">
            <span class="font-semibold text-sm truncate">{@title}</span>
            <span class="badge badge-xs badge-ghost">{@count}</span>
            <button
              :if={@team && not @modal_open}
              phx-click="open_team_modal"
              phx-value-mode="edit"
              phx-value-team_id={@team.id}
              class="btn btn-xs btn-ghost opacity-50 hover:opacity-100 ml-auto"
              aria-label="Rename team"
            >
              <.icon name="hero-pencil-square" class="size-3.5" />
              <span class="sr-only">Rename team</span>
            </button>
            <button
              :if={@deletable && not @modal_open}
              phx-click="open_team_modal"
              phx-value-mode="delete"
              phx-value-team_id={@team.id}
              class="btn btn-xs btn-ghost opacity-50 hover:opacity-100"
              aria-label="Delete team"
            >
              <.icon name="hero-trash" class="size-3.5" />
              <span class="sr-only">Delete team</span>
            </button>
          </div>
        </div>
      </div>

      <%!-- Health violations --%>
      <div :if={@violations != []} class="mb-2 space-y-1">
        <div
          :for={v <- @violations}
          class={[
            "text-xs px-2 py-1 rounded border-l-2 text-base-content",
            v.level == :warning && "bg-warning/15 border-warning",
            v.level == :caution && "bg-info/15 border-info"
          ]}
        >
          {v.message}
        </div>
      </div>

      <%!-- Player cards drop zone --%>
      <div class="space-y-1 min-h-8">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :has_violation, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :column_id, :string, required: true

  defp player_card(assigns) do
    ~H"""
    <div
      id={"player-#{@player.id}"}
      class={[
        "flex items-center justify-between px-2 py-1.5 rounded text-sm cursor-pointer select-none",
        "bg-base-100 hover:bg-base-300 transition-colors",
        @selected && "ring-2 ring-primary",
        @has_violation && "border border-warning"
      ]}
      draggable="true"
      phx-hook=".RosterDrag"
      data-player-id={@player.id}
      phx-click="select_player"
      phx-value-player_id={@player.id}
    >
      <span class="truncate">{@player.name}</span>
      <div class="flex items-center gap-1 ml-1 flex-shrink-0">
        <span :if={@player.ntrp_rating} class="text-xs text-base-content/50">
          {@player.ntrp_rating}
        </span>
        <span :if={is_nil(@player.ntrp_rating)} class="text-xs text-info" title="No rating">
          ?
        </span>
        <span :if={@has_violation} class="text-warning text-xs" title="Rating issue">⚠</span>
      </div>
    </div>
    """
  end
end
