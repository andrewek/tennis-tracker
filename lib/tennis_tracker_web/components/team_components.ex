defmodule TennisTrackerWeb.TeamComponents do
  @moduledoc false

  use TennisTrackerWeb, :html

  @doc """
  Renders the team settings layout with a five-tab navigation bar.
  """
  attr :current_page, :atom,
    required: true,
    doc: "The current settings tab (:general, :schedule, :lineup, :roster, or :members)"

  attr :team, :map, required: true
  attr :current_group, :map, required: true

  slot :inner_block, required: true

  def settings_layout(assigns) do
    ~H"""
    <div>
      <div class="tabs tabs-border mb-6">
        <.link
          navigate={~p"/g/#{@current_group.slug}/teams/#{@team.id}/settings"}
          class={["tab", @current_page == :general && "tab-active"]}
        >
          General
        </.link>
        <.link
          navigate={~p"/g/#{@current_group.slug}/teams/#{@team.id}/settings/schedule"}
          class={["tab", @current_page == :schedule && "tab-active"]}
        >
          Match Schedule
        </.link>
        <.link
          navigate={~p"/g/#{@current_group.slug}/teams/#{@team.id}/settings/lineup"}
          class={["tab", @current_page == :lineup && "tab-active"]}
        >
          Lineup Settings
        </.link>
        <.link
          navigate={~p"/g/#{@current_group.slug}/teams/#{@team.id}/settings/roster"}
          class={["tab", @current_page == :roster && "tab-active"]}
        >
          Roster
        </.link>
        <.link
          navigate={~p"/g/#{@current_group.slug}/teams/#{@team.id}/settings/members"}
          class={["tab", @current_page == :members && "tab-active"]}
        >
          Members
        </.link>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
