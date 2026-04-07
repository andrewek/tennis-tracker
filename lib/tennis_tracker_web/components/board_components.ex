defmodule TennisTrackerWeb.BoardComponents do
  @moduledoc """
  Shared drag-and-drop board UI primitives for use across any LiveView that
  moves players between columns (Roster Planner, Lineup Setter, etc.).
  """

  use TennisTrackerWeb, :html

  attr :id, :string, required: true
  attr :title, :any, required: true
  attr :count, :integer, required: true
  attr :target_id, :string, required: true
  attr :violations, :list, default: []
  attr :drop_event, :string, default: nil
  slot :header_actions
  slot :inner_block, required: true

  def board_column(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex-shrink-0 w-56 bg-base-200 rounded-lg p-2 flex flex-col"
      phx-hook="DropZone"
      data-target-id={@target_id}
      data-drop-event={@drop_event}
    >
      <%!-- Column header --%>
      <div class="flex items-center justify-between mb-2 px-1">
        <div class="flex-1 min-w-0 flex items-center gap-1">
          <span class="font-semibold text-sm truncate">{@title}</span>
          <span class="badge badge-xs badge-ghost">{@count}</span>
        </div>
        <div :if={@header_actions != []} class="flex-shrink-0">
          {render_slot(@header_actions)}
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
      <div class="flex-1 overflow-y-auto min-h-0 space-y-1">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Grouped column layout components (task 4.1/4.2)
  # ---------------------------------------------------------------------------

  attr :id, :string, required: true
  attr :column_name, :string, required: true
  slot :inner_block, required: true

  def lineup_column_group(assigns) do
    ~H"""
    <div id={@id} class="flex-shrink-0 w-56 bg-base-200 rounded-lg p-2 flex flex-col">
      <div class="font-semibold text-sm px-1 mb-2">{@column_name}</div>
      <div class="flex flex-col gap-2 flex-1 overflow-y-auto min-h-0">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :target_id, :string, required: true
  attr :violations, :list, default: []
  attr :drop_event, :string, default: nil
  attr :assign_event, :string, default: nil
  slot :inner_block, required: true

  def lineup_slot_zone(assigns) do
    ~H"""
    <div
      id={@id}
      class="bg-base-100/60 rounded p-1 min-h-[2.5rem]"
      phx-hook="DropZone"
      data-target-id={@target_id}
      data-drop-event={@drop_event}
      phx-click={@assign_event}
      phx-value-slot_id={@target_id}
    >
      <div class="flex items-center justify-between px-1 mb-1">
        <span class="text-xs font-medium text-base-content/70">{@title}</span>
        <span class="badge badge-xs badge-ghost">{@count}</span>
      </div>
      <div :if={@violations != []} class="mb-1 space-y-0.5">
        <div
          :for={v <- @violations}
          class={[
            "text-xs px-1.5 py-0.5 rounded border-l-2 text-base-content",
            v.level == :warning && "bg-warning/15 border-warning",
            v.level == :caution && "bg-info/15 border-info"
          ]}
        >
          {v.message}
        </div>
      </div>
      <div class="space-y-1">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Player card
  # ---------------------------------------------------------------------------

  attr :player, :map, required: true
  attr :has_violation, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :readonly, :boolean, default: false
  attr :on_click, :any, default: "select_player"
  attr :column_badges, :list, default: []

  def player_card(assigns) do
    ~H"""
    <div
      id={"player-#{@player.id}"}
      class={[
        "flex items-center justify-between px-2 py-1.5 rounded text-sm cursor-pointer select-none",
        "bg-base-100 hover:bg-base-300 transition-colors",
        @selected && "ring-2 ring-primary",
        !@readonly && @has_violation && "border border-warning"
      ]}
      draggable={if @readonly, do: nil, else: "true"}
      phx-hook={if @readonly, do: nil, else: "DraggableCard"}
      data-player-id={if @readonly, do: nil, else: @player.id}
      phx-click={@on_click}
      phx-value-player_id={@player.id}
    >
      <span class="truncate">{@player.name}</span>
      <div class="flex items-center gap-1 ml-1 flex-shrink-0">
        <span :for={badge <- @column_badges} class="badge badge-xs badge-outline opacity-60">
          {badge}
        </span>
        <span :if={@player.ntrp_rating} class="text-xs text-base-content/50">
          {@player.ntrp_rating}
        </span>
        <span :if={is_nil(@player.ntrp_rating)} class="text-xs text-info" title="No rating">
          ?
        </span>
        <span :if={!@readonly && @has_violation} class="text-warning">
          <.icon name="hero-exclamation-triangle" class="size-3.5" />
          <span class="sr-only">Rating issue</span>
        </span>
      </div>
    </div>
    """
  end

  attr :player, :map, required: true
  attr :current_team, :string, default: nil
  attr :group_slug, :string, required: true
  attr :on_close, :any, required: true
  slot :actions

  def player_detail_modal(assigns) do
    ~H"""
    <.modal
      title={@player.name}
      on_close={@on_close}
      max_width="sm:max-w-sm"
      position={:bottom}
    >
      <:subtitle :if={@player.ntrp_rating}>NTRP: {@player.ntrp_rating}</:subtitle>
      <p :if={@current_team} class="text-xs text-base-content/50 mb-3">
        Currently: {@current_team}
      </p>
      <div class="mb-3">
        <.link
          navigate={~p"/g/#{@group_slug}/players/#{@player.id}"}
          class="btn btn-ghost btn-sm w-full"
        >
          View profile
        </.link>
      </div>
      <div :if={@actions != []} class="space-y-2">
        {render_slot(@actions)}
      </div>
    </.modal>
    """
  end
end
