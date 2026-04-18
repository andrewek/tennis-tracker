defmodule TennisTrackerWeb.AccountComponents do
  @moduledoc false

  use TennisTrackerWeb, :html

  @doc """
  Renders the settings layout with sub-navigation for Profile, Security, and Preferences.
  """
  attr :current_page, :atom,
    required: true,
    doc: "The current settings sub-page (:profile, :security, or :preferences)"

  slot :inner_block, required: true

  def settings_layout(assigns) do
    ~H"""
    <div class="max-w-2xl">
      <div class="tabs tabs-border mb-6">
        <.link
          navigate={~p"/account/settings/profile"}
          class={["tab", @current_page == :profile && "tab-active"]}
        >
          Profile
        </.link>
        <.link
          navigate={~p"/account/settings/security"}
          class={["tab", @current_page == :security && "tab-active"]}
        >
          Security
        </.link>
        <.link
          navigate={~p"/account/settings/preferences"}
          class={["tab", @current_page == :preferences && "tab-active"]}
        >
          Preferences
        </.link>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
