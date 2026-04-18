defmodule TennisTrackerWeb.Teams.Settings.LineupLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{TeamLineupColumn, TeamLineupSlot}
  alias TennisTrackerWeb.TeamComponents
  alias TennisTrackerWeb.Teams.Settings.Helpers

  def mount(_params, _session, socket) do
    socket
    |> assign(:team, nil)
    |> assign(:can_update_team, false)
    |> assign(:can_manage_slots, false)
    |> assign(:can_manage_captains, false)
    |> assign(:lineup_columns, [])
    |> assign(:lineup_slots, [])
    |> assign(:slot_modal, nil)
    |> assign(:slot_form, nil)
    |> assign(:slot_to_delete, nil)
    |> assign(:column_modal, nil)
    |> assign(:column_form, nil)
    |> assign(:column_to_delete, nil)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Helpers.load_team_settings(id, group_id, current_user) do
      {:ok, assigns} ->
        team = assigns.team
        lineup_columns = Helpers.load_lineup_columns(team.id, group_id, current_user)
        lineup_slots = Helpers.load_lineup_slots(team.id, group_id, current_user)

        socket
        |> assign(assigns)
        |> assign(:lineup_columns, lineup_columns)
        |> assign(:lineup_slots, lineup_slots)
        |> assign(:page_title, "#{team.name} · Lineup Settings")
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

  # ---------------------------------------------------------------------------
  # Column modal events
  # ---------------------------------------------------------------------------

  def handle_event("open_add_column_modal", _params, socket) do
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
    |> assign(:column_modal, :add)
    |> assign(:column_form, form)
    |> noreply()
  end

  def handle_event("open_edit_column_modal", %{"column_id" => column_id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    column = Enum.find(socket.assigns.lineup_columns, &(&1.id == column_id))

    if column do
      form =
        AshPhoenix.Form.for_update(column, :update,
          domain: Tennis,
          actor: current_user,
          tenant: group_id,
          as: "column_form",
          forms: [auto?: true]
        )
        |> to_form()

      socket
      |> assign(:column_modal, {:edit, column_id})
      |> assign(:column_form, form)
      |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_event("close_column_modal", _params, socket) do
    socket
    |> assign(:column_modal, nil)
    |> assign(:column_form, nil)
    |> noreply()
  end

  def handle_event("validate_column_modal", %{"column_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.column_form, params)
    socket |> assign(:column_form, form) |> noreply()
  end

  def handle_event("save_column_modal", %{"column_form" => params}, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    params_with_ids =
      case socket.assigns.column_modal do
        :add ->
          params
          |> Map.put("team_id", team.id)
          |> Map.put("group_id", group_id)

        {:edit, _} ->
          params
      end

    case AshPhoenix.Form.submit(socket.assigns.column_form, params: params_with_ids) do
      {:ok, _column} ->
        socket
        |> assign(:column_modal, nil)
        |> assign(:column_form, nil)
        |> assign(:lineup_columns, Helpers.load_lineup_columns(team.id, group_id, current_user))
        |> put_flash(:info, "Category saved.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:column_form, form) |> noreply()
    end
  end

  def handle_event("show_delete_column_modal", %{"column_id" => column_id}, socket) do
    column = Enum.find(socket.assigns.lineup_columns, &(&1.id == column_id))

    has_slots =
      Enum.any?(socket.assigns.lineup_slots, &(&1.team_lineup_column_id == column_id))

    if column && not has_slots do
      socket |> assign(:column_to_delete, column) |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_event("hide_delete_column_modal", _params, socket) do
    socket |> assign(:column_to_delete, nil) |> noreply()
  end

  def handle_event("delete_column", _params, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    column = socket.assigns.column_to_delete

    Tennis.delete_lineup_column!(column, tenant: group_id, actor: current_user)

    socket
    |> assign(:column_to_delete, nil)
    |> assign(:lineup_columns, Helpers.load_lineup_columns(team.id, group_id, current_user))
    |> put_flash(:info, "Category deleted.")
    |> noreply()
  end

  def handle_event("move_column_up", %{"column_id" => column_id}, socket) do
    do_reorder_column(socket, column_id, :up)
  end

  def handle_event("move_column_down", %{"column_id" => column_id}, socket) do
    do_reorder_column(socket, column_id, :down)
  end

  # ---------------------------------------------------------------------------
  # Slot modal events
  # ---------------------------------------------------------------------------

  def handle_event("open_add_slot_modal", %{"column_id" => column_id}, socket) do
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
    |> assign(:slot_modal, {:add, column_id})
    |> assign(:slot_form, form)
    |> noreply()
  end

  def handle_event("open_edit_slot_modal", %{"slot_id" => slot_id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    slot = Enum.find(socket.assigns.lineup_slots, &(&1.id == slot_id))

    if slot do
      form =
        AshPhoenix.Form.for_update(slot, :update,
          domain: Tennis,
          actor: current_user,
          tenant: group_id,
          as: "slot_form",
          forms: [auto?: true]
        )
        |> to_form()

      socket
      |> assign(:slot_modal, {:edit, slot_id})
      |> assign(:slot_form, form)
      |> noreply()
    else
      socket |> noreply()
    end
  end

  def handle_event("close_slot_modal", _params, socket) do
    socket
    |> assign(:slot_modal, nil)
    |> assign(:slot_form, nil)
    |> noreply()
  end

  def handle_event("validate_slot_modal", %{"slot_form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.slot_form, params)
    socket |> assign(:slot_form, form) |> noreply()
  end

  def handle_event("save_slot_modal", %{"slot_form" => params}, socket) do
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    params_with_ids =
      case socket.assigns.slot_modal do
        {:add, column_id} ->
          col_id =
            if params["team_lineup_column_id"] in [nil, ""],
              do: column_id,
              else: params["team_lineup_column_id"]

          params
          |> Map.put("team_id", team.id)
          |> Map.put("group_id", group_id)
          |> Map.put("team_lineup_column_id", col_id)

        {:edit, _} ->
          params
      end

    case AshPhoenix.Form.submit(socket.assigns.slot_form, params: params_with_ids) do
      {:ok, _slot} ->
        socket
        |> assign(:slot_modal, nil)
        |> assign(:slot_form, nil)
        |> assign(:lineup_slots, Helpers.load_lineup_slots(team.id, group_id, current_user))
        |> put_flash(:info, "Slot saved.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:slot_form, form) |> noreply()
    end
  end

  def handle_event("show_delete_slot_modal", %{"slot_id" => slot_id}, socket) do
    slot = Enum.find(socket.assigns.lineup_slots, &(&1.id == slot_id))

    if slot && slot.participation_type == :out do
      socket |> put_flash(:error, "The out slot cannot be deleted.") |> noreply()
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
    |> assign(:lineup_slots, Helpers.load_lineup_slots(team.id, group_id, current_user))
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
        |> assign(:lineup_columns, Helpers.load_lineup_columns(team.id, group_id, current_user))
        |> noreply()
      else
        socket |> noreply()
      end
    else
      socket |> noreply()
    end
  end

  defp do_reorder_slot(socket, slot_id, direction) do
    all_slots = socket.assigns.lineup_slots
    team = socket.assigns.team
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    slot = Enum.find(all_slots, &(&1.id == slot_id))

    if slot do
      # Reorder only within the same category
      category_slots =
        all_slots
        |> Enum.filter(&(&1.team_lineup_column_id == slot.team_lineup_column_id))

      idx = Enum.find_index(category_slots, &(&1.id == slot_id))

      if idx do
        adjacent_idx = if direction == :up, do: idx - 1, else: idx + 1
        adjacent = Enum.at(category_slots, adjacent_idx)

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
          |> assign(:lineup_slots, Helpers.load_lineup_slots(team.id, group_id, current_user))
          |> noreply()
        else
          socket |> noreply()
        end
      else
        socket |> noreply()
      end
    else
      socket |> noreply()
    end
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
        current_page={:lineup}
        team={@team}
        current_group={@current_group}
      >
        <% slots_by_column = Enum.group_by(@lineup_slots, & &1.team_lineup_column_id) %>

        <div class="flex items-center justify-between mb-4">
          <h2 class="font-semibold">Categories</h2>
          <button
            :if={@can_manage_slots}
            class="btn btn-sm btn-ghost"
            phx-click="open_add_column_modal"
          >
            <.icon name="hero-plus" class="size-3 inline" /> Add category
          </button>
        </div>

        <div :if={@lineup_columns == []} class="text-sm text-base-content/50">
          No categories defined. Add a category to get started.
        </div>

        <div class="space-y-4">
          <%= for {column, col_idx} <- Enum.with_index(@lineup_columns) do %>
            <% col_slots = Map.get(slots_by_column, column.id, []) %>
            <% has_slots = col_slots != [] %>
            <div id={"column-#{column.id}"} class="bg-base-200 rounded-lg p-4">
              <%!-- Category card header --%>
              <div class="flex items-center justify-between mb-3">
                <h3 class="font-medium">{column.name}</h3>
                <div :if={@can_manage_slots} class="flex items-center gap-1">
                  <button
                    phx-click="move_column_up"
                    phx-value-column_id={column.id}
                    class="btn btn-xs btn-ghost"
                    aria-label="Move category up"
                    disabled={col_idx == 0}
                  >
                    <.icon name="hero-chevron-up" class="size-3" />
                  </button>
                  <button
                    phx-click="move_column_down"
                    phx-value-column_id={column.id}
                    class="btn btn-xs btn-ghost"
                    aria-label="Move category down"
                    disabled={col_idx == length(@lineup_columns) - 1}
                  >
                    <.icon name="hero-chevron-down" class="size-3" />
                  </button>
                  <button
                    phx-click="open_edit_column_modal"
                    phx-value-column_id={column.id}
                    class="btn btn-xs btn-ghost"
                    aria-label="Edit category"
                  >
                    <.icon name="hero-pencil-square" class="size-3" />
                  </button>
                  <button
                    phx-click="show_delete_column_modal"
                    phx-value-column_id={column.id}
                    class="btn btn-xs btn-ghost text-error"
                    aria-label="Delete category"
                    disabled={has_slots}
                  >
                    <.icon name="hero-trash" class="size-3" />
                  </button>
                </div>
              </div>

              <%!-- Slots within this category --%>
              <div :if={col_slots == []} class="text-sm text-base-content/50 mb-3">
                No slots in this category.
              </div>

              <div class="space-y-1 mb-3">
                <%= for {slot, slot_idx} <- Enum.with_index(col_slots) do %>
                  <div
                    id={"slot-#{slot.id}"}
                    class="bg-base-100 rounded px-3 py-2 text-sm flex items-center justify-between"
                  >
                    <div class="min-w-0">
                      <span class="font-medium">{slot.name}</span>
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
                    <div :if={@can_manage_slots} class="flex items-center gap-1 flex-shrink-0">
                      <button
                        phx-click="move_slot_up"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Move slot up"
                        disabled={slot_idx == 0}
                      >
                        <.icon name="hero-chevron-up" class="size-3" />
                      </button>
                      <button
                        phx-click="move_slot_down"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Move slot down"
                        disabled={slot_idx == length(col_slots) - 1}
                      >
                        <.icon name="hero-chevron-down" class="size-3" />
                      </button>
                      <button
                        phx-click="open_edit_slot_modal"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost"
                        aria-label="Edit slot"
                      >
                        <.icon name="hero-pencil-square" class="size-3" />
                      </button>
                      <button
                        :if={slot.participation_type != :out}
                        phx-click="show_delete_slot_modal"
                        phx-value-slot_id={slot.id}
                        class="btn btn-xs btn-ghost text-error"
                        aria-label="Delete slot"
                      >
                        <.icon name="hero-trash" class="size-3" />
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>

              <button
                :if={@can_manage_slots}
                phx-click="open_add_slot_modal"
                phx-value-column_id={column.id}
                class="btn btn-xs btn-ghost"
              >
                <.icon name="hero-plus" class="size-3 inline" /> Add slot
              </button>
            </div>
          <% end %>
        </div>
      </TeamComponents.settings_layout>

      <%!-- Column modal (add or edit) --%>
      <.modal
        :if={@column_modal != nil}
        title={if @column_modal == :add, do: "Add Category", else: "Edit Category"}
        on_close={JS.push("close_column_modal")}
      >
        <.form
          for={@column_form}
          phx-change="validate_column_modal"
          phx-submit="save_column_modal"
          class="space-y-4"
        >
          <.input field={@column_form[:name]} type="text" label="Name" placeholder="e.g. Singles" />
          <div class="flex gap-2 justify-end mt-4">
            <button type="button" class="btn btn-ghost btn-sm" phx-click="close_column_modal">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary btn-sm">Save</button>
          </div>
        </.form>
      </.modal>

      <%!-- Delete column confirmation modal --%>
      <.modal
        :if={@column_to_delete != nil}
        title="Delete Category"
        on_close={JS.push("hide_delete_column_modal")}
      >
        <p class="text-sm text-base-content/70 mb-6">
          Delete category <strong>{@column_to_delete.name}</strong>? This cannot be undone.
        </p>
        <div class="flex gap-2">
          <button phx-click="delete_column" class="btn btn-error flex-1">Delete</button>
          <button phx-click="hide_delete_column_modal" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>

      <%!-- Slot modal (add or edit) --%>
      <% slot_modal_title =
        case @slot_modal do
          {:add, _} -> "Add Slot"
          {:edit, _} -> "Edit Slot"
          _ -> ""
        end %>
      <.modal
        :if={@slot_modal != nil}
        title={slot_modal_title}
        on_close={JS.push("close_slot_modal")}
      >
        <.form
          for={@slot_form}
          phx-change="validate_slot_modal"
          phx-submit="save_slot_modal"
          class="space-y-4"
        >
          <.input field={@slot_form[:name]} type="text" label="Name" placeholder="e.g. #1 Singles" />
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
          <% col_id_value =
            case @slot_modal do
              {:add, col_id} -> col_id
              _ -> @slot_form[:team_lineup_column_id].value
            end %>
          <.input
            field={@slot_form[:team_lineup_column_id]}
            type="select"
            label="Category"
            options={Enum.map(@lineup_columns, &{&1.name, &1.id})}
            prompt="Select category..."
            value={col_id_value}
          />
          <% out_slot_taken = Enum.any?(@lineup_slots, &(&1.participation_type == :out)) %>
          <% out_disabled =
            case @slot_modal do
              {:edit, slot_id} ->
                editing = Enum.find(@lineup_slots, &(&1.id == slot_id))
                out_slot_taken && (editing == nil || editing.participation_type != :out)

              _ ->
                out_slot_taken
            end %>
          <.input
            field={@slot_form[:participation_type]}
            type="select"
            label="Type"
            options={[
              [key: "Playing", value: "playing"],
              [key: "Out", value: "out", disabled: out_disabled],
              [key: "Neutral", value: "neutral"]
            ]}
            prompt="Select type..."
          />
          <div class="flex gap-2 justify-end mt-4">
            <button type="button" class="btn btn-ghost btn-sm" phx-click="close_slot_modal">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary btn-sm">Save</button>
          </div>
        </.form>
      </.modal>

      <%!-- Delete slot confirmation modal --%>
      <.modal
        :if={@slot_to_delete != nil}
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
