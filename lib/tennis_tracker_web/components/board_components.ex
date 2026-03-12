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
  slot :header_actions
  slot :inner_block, required: true

  def board_column(assigns) do
    ~H"""
    <div
      id={@id}
      class="flex-shrink-0 w-56 bg-base-200 rounded-lg p-2"
      phx-hook="DropZone"
      data-target-id={@target_id}
    >
      <%!-- Column header --%>
      <div class="flex items-center justify-between mb-2 px-1">
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-1">
            <span class="font-semibold text-sm truncate">{@title}</span>
            <span class="badge badge-xs badge-ghost">{@count}</span>
            {render_slot(@header_actions)}
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

  def player_card(assigns) do
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
      phx-hook="DraggableCard"
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

  attr :player, :map, required: true
  slot :actions

  def player_detail_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/40"
      phx-click="deselect_player"
      data-player-modal
    >
      <div
        class="bg-base-100 rounded-t-2xl sm:rounded-2xl w-full sm:max-w-sm p-4 shadow-xl"
        phx-click-away="deselect_player"
      >
        <div class="flex items-center justify-between mb-4">
          <div>
            <p class="font-semibold">{@player.name}</p>
            <p :if={@player.ntrp_rating} class="text-sm text-base-content/60">
              NTRP: {@player.ntrp_rating}
            </p>
          </div>
          <button
            phx-click="deselect_player"
            class="btn btn-ghost btn-xs btn-circle"
            aria-label="Close"
          >
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>
        <div class="mb-3">
          <.link navigate={~p"/players/#{@player.id}"} class="btn btn-ghost btn-sm w-full">
            View profile
          </.link>
        </div>
        <div :if={@actions != []} class="space-y-2">
          {render_slot(@actions)}
        </div>
        <div class="divider my-2"></div>
        <button phx-click="deselect_player" class="btn btn-ghost btn-sm w-full">
          Cancel
        </button>
      </div>
    </div>
    """
  end
end
