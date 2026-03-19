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
      class="flex-shrink-0 w-56 bg-base-200 rounded-lg p-2 flex flex-col"
      phx-hook="DropZone"
      data-target-id={@target_id}
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

  attr :player, :map, required: true
  attr :has_violation, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :readonly, :boolean, default: false
  attr :on_click, :string, default: "select_player"

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
