defmodule TennisTrackerWeb.RosterPlannerLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.BoardComponents

  alias AshPhoenix.Form
  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{RosterHealth, Team}

  # ---------------------------------------------------------------------------
  # Mount / Params
  # ---------------------------------------------------------------------------

  def mount(_params, _session, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    team_types = Tennis.list_team_types!(tenant: group_id, actor: current_user)
    planning_contexts = Tennis.list_planning_contexts(tenant: group_id, actor: current_user)

    tag_categories =
      Tennis.list_tag_categories!(load: [:tags], tenant: group_id, actor: current_user)

    socket
    |> assign(:page_title, "Roster Planner")
    |> assign(:team_types, team_types)
    |> assign(:planning_contexts, planning_contexts)
    |> assign(:tag_categories, tag_categories)
    |> assign(:tag_filter, %{include: %{}, show_untagged: []})
    |> assign(:show_create_form, false)
    |> assign(:context, nil)
    |> assign(:board, nil)
    |> assign(:season_year_input, "2026")
    |> assign(:selection, nil)
    |> assign(:team_modal, nil)
    |> assign(:show_season_rules, false)
    |> ok()
  end

  def handle_params(
        %{"team_type_id" => team_type_id, "season_year" => season_year_str},
        _url,
        socket
      ) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Integer.parse(season_year_str) do
      {season_year, ""} ->
        team_type = Tennis.get_team_type!(team_type_id, tenant: group_id, actor: current_user)

        {:ok, pseudo_team} =
          Tennis.ensure_pseudo_team(team_type_id, season_year,
            tenant: group_id,
            actor: current_user
          )

        topic = topic(group_id, team_type_id, season_year)

        if connected?(socket) do
          Phoenix.PubSub.subscribe(TennisTracker.PubSub, topic)
        end

        {:ok, season_rules} =
          Tennis.get_season_rules_for_context(team_type_id, season_year,
            tenant: group_id,
            actor: current_user
          )

        season_rules_with_tags =
          if season_rules do
            case Ash.load(season_rules, [default_tags: [:tag_category]],
                   domain: Tennis,
                   tenant: group_id,
                   actor: current_user
                 ) do
              {:ok, loaded} -> loaded
              _ -> season_rules
            end
          end

        # Initialize tag_filter include facets from season_rules.default_tags
        initial_tag_filter =
          if season_rules_with_tags && season_rules_with_tags.default_tags != [] do
            include =
              season_rules_with_tags.default_tags
              |> Enum.group_by(& &1.tag_category_id, & &1.id)

            %{include: include, show_untagged: []}
          else
            %{include: %{}, show_untagged: []}
          end

        board =
          load_board(
            team_type_id,
            season_year,
            pseudo_team,
            season_rules,
            initial_tag_filter,
            team_type.allowed_ntrp_levels,
            group_id,
            current_user
          )

        socket
        |> assign(:context, %{
          team_type: team_type,
          team_type_id: team_type_id,
          season_year: season_year,
          pseudo_team: pseudo_team,
          season_rules: season_rules_with_tags || season_rules
        })
        |> assign(:tag_filter, initial_tag_filter)
        |> assign(:board, board)
        |> noreply()

      _ ->
        socket
        |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}/roster-planner")
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
    group_slug = socket.assigns.current_group.slug

    socket
    |> push_navigate(to: ~p"/g/#{group_slug}/roster-planner/#{ttid}/#{year}")
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
    {player, team} = find_player_with_team(socket.assigns.board, player_id)

    socket
    |> assign(:selection, %{player: player, team: team})
    |> noreply()
  end

  def handle_event("deselect_player", _params, socket) do
    socket
    |> assign(:selection, nil)
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
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    Tennis.unassign_player(player_id, ctx.team_type_id, ctx.season_year,
      tenant: group_id,
      actor: current_user
    )

    # Board reload is driven by the PubSub notification from the Ash action
    socket
    |> assign(:selection, nil)
    |> noreply()
  end

  def handle_event(
        "move_player",
        %{"player_id" => player_id, "target_id" => target_id},
        socket
      ) do
    ctx = socket.assigns.context
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    Tennis.assign_player(player_id, target_id, ctx.team_type_id, ctx.season_year,
      tenant: group_id,
      actor: current_user
    )

    # Board reload is driven by the PubSub notification from the Ash action
    socket
    |> assign(:selection, nil)
    |> noreply()
  end

  # ---------------------------------------------------------------------------
  # Events — team modal
  # ---------------------------------------------------------------------------

  def handle_event("open_team_modal", %{"mode" => "create"}, socket) do
    ctx = socket.assigns.context
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    form =
      Form.for_create(Team, :create,
        domain: Tennis,
        actor: current_user,
        tenant: group_id,
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
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    if entry do
      form =
        Form.for_update(entry.team, :update,
          domain: Tennis,
          actor: current_user,
          tenant: group_id,
          as: "team"
        )
        |> to_form()

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
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    params =
      if modal.mode == :create do
        Map.merge(params, %{
          "team_type_id" => ctx.team_type_id,
          "season_year" => ctx.season_year,
          "is_pseudo" => false
        })
      else
        params
      end

    case Form.submit(modal.form.source, params: params) do
      {:ok, _team} ->
        socket
        |> assign(:team_modal, nil)
        |> reload_board(ctx, group_id, current_user)
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:team_modal, %{modal | form: to_form(form)})
        |> noreply()
    end
  end

  def handle_event(
        "toggle_planner_tag",
        %{"category_id" => category_id, "tag_id" => tag_id},
        socket
      ) do
    tag_filter = socket.assigns.tag_filter

    updated_include =
      tag_filter.include
      |> Map.update(category_id, [tag_id], fn tags ->
        if tag_id in tags, do: List.delete(tags, tag_id), else: [tag_id | tags]
      end)
      |> Map.reject(fn {_, v} -> v == [] end)

    new_filter = %{tag_filter | include: updated_include}
    update_tag_filter(socket, new_filter)
  end

  def handle_event("toggle_planner_show_untagged", %{"category_id" => category_id}, socket) do
    tag_filter = socket.assigns.tag_filter

    updated_show =
      if category_id in tag_filter.show_untagged,
        do: List.delete(tag_filter.show_untagged, category_id),
        else: [category_id | tag_filter.show_untagged]

    new_filter = %{tag_filter | show_untagged: updated_show}
    update_tag_filter(socket, new_filter)
  end

  def handle_event("confirm_delete_team", %{"team_id" => team_id}, socket) do
    ctx = socket.assigns.context
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    team =
      case Enum.find(socket.assigns.board.real_teams, &(&1.team.id == team_id)) do
        nil -> nil
        entry -> entry.team
      end

    if team, do: Tennis.delete_team(team, tenant: group_id, actor: current_user)

    socket
    |> assign(:team_modal, nil)
    |> reload_board(ctx, group_id, current_user)
    |> noreply()
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  def handle_info(%Ash.Notifier.Notification{}, socket) do
    ctx = socket.assigns.context
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    if ctx do
      socket
      |> reload_board(ctx, group_id, current_user)
      |> noreply()
    else
      socket |> noreply()
    end
  end

  # ---------------------------------------------------------------------------
  # Board helpers
  # ---------------------------------------------------------------------------

  defp update_tag_filter(socket, new_filter) do
    ctx = socket.assigns.context
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    board =
      load_board(
        ctx.team_type_id,
        ctx.season_year,
        ctx.pseudo_team,
        ctx.season_rules,
        new_filter,
        ctx.team_type.allowed_ntrp_levels,
        group_id,
        current_user
      )

    socket
    |> assign(:tag_filter, new_filter)
    |> assign(:board, board)
    |> noreply()
  end

  defp topic(group_id, team_type_id, season_year),
    do: "roster:#{group_id}:#{team_type_id}:#{season_year}"

  defp find_player_with_team(board, player_id) do
    cond do
      player = Enum.find(board.unassigned, &(&1.id == player_id)) ->
        {player, "Unassigned"}

      player = Enum.find(board.not_participating, &(&1.id == player_id)) ->
        {player, "Not Participating"}

      true ->
        case Enum.find(board.real_teams, fn %{players: players} ->
               Enum.any?(players, &(&1.id == player_id))
             end) do
          %{team: team, players: players} ->
            {Enum.find(players, &(&1.id == player_id)), team.name}

          nil ->
            {nil, nil}
        end
    end
  end

  defp reload_board(socket, ctx, group_id, current_user) do
    board =
      load_board(
        ctx.team_type_id,
        ctx.season_year,
        ctx.pseudo_team,
        ctx.season_rules,
        socket.assigns.tag_filter,
        ctx.team_type.allowed_ntrp_levels,
        group_id,
        current_user
      )

    assign(socket, :board, board)
  end

  defp load_board(
         team_type_id,
         season_year,
         pseudo_team,
         season_rules,
         tag_filter,
         allowed_ntrp_levels,
         group_id,
         current_user
       ) do
    {:ok, all_teams} =
      Tennis.list_teams_for_context(team_type_id, season_year,
        tenant: group_id,
        actor: current_user
      )

    {:ok, all_memberships} =
      Tennis.list_memberships_for_context(team_type_id, season_year,
        tenant: group_id,
        actor: current_user
      )

    real_teams = Enum.reject(all_teams, & &1.is_pseudo)

    unassigned =
      Tennis.list_unassigned_players(team_type_id, season_year,
        tenant: group_id,
        actor: current_user,
        tag_filter: tag_filter,
        allowed_ntrp_levels: allowed_ntrp_levels
      )

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

        health = RosterHealth.check(team, players, season_rules)

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
  # Private components
  # ---------------------------------------------------------------------------

  attr :form, :map, required: true
  attr :submit_label, :string, required: true
  attr :placeholder, :string, default: nil

  defp team_name_form(assigns) do
    ~H"""
    <.form for={@form} phx-change="validate_team_form" phx-submit="submit_team_form">
      <div class="mb-4">
        <label class="label py-0 mb-1">
          <span class="label-text">Team Name</span>
        </label>
        <input
          type="text"
          name={@form[:name].name}
          value={Phoenix.HTML.Form.input_value(@form, :name)}
          placeholder={@placeholder}
          autofocus
          class={["input input-bordered w-full", @form[:name].errors != [] && "input-error"]}
        />
        <p :for={error <- @form[:name].errors} class="text-error text-xs mt-1">
          {elem(error, 0)}
        </p>
      </div>
      <div class="flex gap-2">
        <button type="submit" class="btn btn-primary flex-1">{@submit_label}</button>
        <button type="button" phx-click="close_team_modal" class="btn btn-ghost">Cancel</button>
      </div>
    </.form>
    """
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
      <%!-- Outer wrapper fills exactly the available space in main so main doesn't scroll.
           Desktop: 100dvh - main py-8 (4rem).
           Mobile: 100dvh - mobile top bar (4rem) - main py-8 (4rem) = 100dvh - 8rem. --%>
      <div class="flex flex-col h-[calc(100dvh-8rem)] lg:h-[calc(100dvh-4rem)] -mx-6 -my-8">
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
              navigate={
                ~p"/g/#{@current_group.slug}/roster-planner/#{ctx.team_type_id}/#{ctx.season_year}"
              }
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
                    <select
                      name="team_type_id"
                      class="select select-bordered select-sm w-full"
                      required
                    >
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
          <div class="mb-4 px-4 flex-shrink-0 space-y-2">
            <div class="flex items-center gap-6">
              <.link
                navigate={~p"/g/#{@current_group.slug}/roster-planner"}
                class="btn btn-sm btn-ghost"
              >
                <.icon name="hero-arrow-left" class="size-4" /> Change context
              </.link>
            </div>

            <%!-- Tag filter facets --%>
            <.tag_filter_facets
              tag_categories={@tag_categories}
              tag_filter={@tag_filter}
              on_toggle_tag="toggle_planner_tag"
              on_toggle_untagged="toggle_planner_show_untagged"
            />
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
                selected={@selection != nil && @selection.player.id == player.id}
                readonly={@current_group_role == :member}
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
                  <div class="dropdown dropdown-end">
                    <button
                      tabindex="0"
                      class="btn btn-xs btn-ghost opacity-50 hover:opacity-100"
                      aria-label="Team actions"
                    >
                      <.icon name="hero-ellipsis-vertical" class="size-3.5" />
                    </button>
                    <ul
                      tabindex="0"
                      class="dropdown-content menu menu-xs bg-base-100 rounded-box shadow-md z-10 w-36 p-1"
                    >
                      <li>
                        <.link navigate={~p"/g/#{@current_group.slug}/teams/#{team.id}"}>
                          <.icon name="hero-arrow-top-right-on-square" class="size-3.5" /> View team
                        </.link>
                      </li>
                      <li :if={@current_group_role in [:owner, :admin]}>
                        <button
                          phx-click="open_team_modal"
                          phx-value-mode="edit"
                          phx-value-team_id={team.id}
                        >
                          <.icon name="hero-pencil-square" class="size-3.5" /> Rename
                        </button>
                      </li>
                      <li :if={@current_group_role in [:owner, :admin]}>
                        <button
                          phx-click="open_team_modal"
                          phx-value-mode="delete"
                          phx-value-team_id={team.id}
                          class="text-error"
                        >
                          <.icon name="hero-trash" class="size-3.5" /> Delete
                        </button>
                      </li>
                    </ul>
                  </div>
                </:header_actions>
                <.player_card
                  :for={player <- players}
                  player={player}
                  has_violation={MapSet.member?(violation_ids, player.id)}
                  selected={@selection != nil && @selection.player.id == player.id}
                  readonly={@current_group_role == :member}
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
                selected={@selection != nil && @selection.player.id == player.id}
                readonly={@current_group_role == :member}
              />
            </.board_column>

            <%!-- New Team button (owners/admins only) --%>
            <div
              :if={@current_group_role in [:owner, :admin]}
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
          <.player_detail_modal
            :if={@selection}
            player={@selection.player}
            current_team={@selection.team}
            group_slug={@current_group.slug}
            on_close="deselect_player"
          >
            <:actions>
              <button
                phx-click="move_player"
                phx-value-player_id={@selection.player.id}
                phx-value-target_id="unassigned"
                class="btn btn-outline btn-sm w-full"
              >
                Unassigned
              </button>
              <button
                :for={%{team: team} <- @board.real_teams}
                phx-click="move_player"
                phx-value-player_id={@selection.player.id}
                phx-value-target_id={team.id}
                class="btn btn-primary btn-sm w-full"
              >
                {team.name}
              </button>
              <button
                phx-click="move_player"
                phx-value-player_id={@selection.player.id}
                phx-value-target_id={@board.pseudo_team.id}
                class="btn btn-outline btn-secondary btn-sm w-full"
              >
                Not Participating
              </button>
            </:actions>
          </.player_detail_modal>

          <%!-- Team modal (create / edit / delete) --%>
          <.modal
            :if={@team_modal}
            title={
              case @team_modal.mode do
                :create -> "New Team"
                :edit -> "Rename Team"
                :delete -> "Delete Team"
              end
            }
            on_close="close_team_modal"
          >
            <%= cond do %>
              <% @team_modal.mode == :create -> %>
                <.team_name_form
                  form={@team_modal.form}
                  submit_label="Create"
                  placeholder="e.g. Team Alpha"
                />
              <% @team_modal.mode == :edit -> %>
                <.team_name_form form={@team_modal.form} submit_label="Save" />
              <% @team_modal.mode == :delete -> %>
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
                  <button phx-click="close_team_modal" class="btn btn-ghost">Cancel</button>
                </div>
            <% end %>
          </.modal>

          <%!-- Season rules info modal --%>
          <.modal
            :if={@show_season_rules}
            title="Season Rules"
            on_close="hide_season_rules"
            max_width="max-w-xs"
          >
            <dl class="space-y-3 text-sm">
              <div class="flex justify-between">
                <dt class="text-base-content/60">NTRP range</dt>
                <dd class="font-medium">
                  <%= cond do %>
                    <% @context.team_type.allowed_ntrp_levels == [] -> %>
                      N/A
                    <% true -> %>
                      {Enum.min(@context.team_type.allowed_ntrp_levels)} – {Enum.max(
                        @context.team_type.allowed_ntrp_levels
                      )}
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
          </.modal>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
