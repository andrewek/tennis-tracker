defmodule TennisTrackerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TennisTrackerWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout with a sidebar-based design using daisyUI drawer.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :current_user, :map, default: nil, doc: "the currently authenticated user"
  attr :current_group, :map, default: nil, doc: "the current group"
  attr :current_group_role, :atom, default: nil, doc: "the current user's role in the group"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="h-dvh overflow-hidden drawer lg:drawer-open">
      <input id="sidebar-drawer" type="checkbox" class="drawer-toggle" />

      <%!-- Drawer content (main area) --%>
      <div class="drawer-content flex flex-col h-dvh min-h-0">
        <%!-- Mobile top bar (hidden on lg+) --%>
        <div class="navbar bg-base-100 lg:hidden flex-shrink-0 sticky top-0 z-10 border-b border-base-300">
          <div class="flex-none">
            <label for="sidebar-drawer" class="btn btn-square btn-ghost" aria-label="Open sidebar">
              <.icon name="hero-bars-3" class="size-6" />
            </label>
          </div>
          <div class="flex-1 px-2 font-semibold">
            <%= if @current_group do %>
              {@current_group.name}
            <% else %>
              Tennis Tracker
            <% end %>
          </div>
        </div>

        <%!-- Page content --%>
        <main class="flex-1 min-h-0 overflow-y-auto px-6 py-8">
          {render_slot(@inner_block)}
        </main>
      </div>

      <%!-- Sidebar --%>
      <div class="drawer-side z-20">
        <label for="sidebar-drawer" aria-label="Close sidebar" class="drawer-overlay"></label>
        <.sidebar
          current_group={@current_group}
          current_user={@current_user}
          current_group_role={@current_group_role}
        />
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :current_group, :map, default: nil
  attr :current_user, :map, default: nil
  attr :current_group_role, :atom, default: nil

  defp sidebar(assigns) do
    ~H"""
    <aside class="w-64 bg-base-200 flex flex-col h-full">
      <%!-- App name / logo --%>
      <div class="p-4 border-b border-base-300">
        <.link navigate={~p"/"} class="text-lg font-bold block">Tennis Tracker</.link>
        <div :if={@current_group} class="flex items-baseline justify-between mt-1">
          <p class="text-sm text-base-content/60">{@current_group.name}</p>
          <.link
            navigate={~p"/groups"}
            class="text-xs text-primary hover:text-primary-focus font-medium px-2 py-1"
          >
            Switch Organization
          </.link>
        </div>
      </div>

      <%!-- Nav links (only when in a group) --%>
      <nav :if={@current_group} class="flex-1 p-2">
        <ul class="menu menu-sm w-full">
          <li>
            <.link navigate={~p"/g/#{@current_group.slug}"}>Home</.link>
          </li>
          <li>
            <.link navigate={~p"/g/#{@current_group.slug}/players"}>Players</.link>
          </li>
          <li>
            <.link navigate={~p"/g/#{@current_group.slug}/teams"}>Teams</.link>
          </li>
          <li>
            <.link navigate={~p"/g/#{@current_group.slug}/roster-planner"}>Roster Planning</.link>
          </li>
          <li :if={@current_group_role in [:owner, :admin]}>
            <details>
              <summary>Group Settings</summary>
              <ul>
                <li>
                  <.link navigate={~p"/g/#{@current_group.slug}/settings/locations"}>
                    Locations
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/g/#{@current_group.slug}/settings/tags"}>
                    Tags
                  </.link>
                </li>
                <li>
                  <.link navigate={~p"/g/#{@current_group.slug}/settings/season-rules"}>
                    Season Rules
                  </.link>
                </li>
              </ul>
            </details>
          </li>
        </ul>
      </nav>

      <%!-- Spacer when no group nav --%>
      <div :if={is_nil(@current_group)} class="flex-1"></div>

      <%!-- Utility section --%>
      <div :if={@current_user} class="p-2">
        <hr class="border-base-300 mb-2" />
        <ul class="menu menu-sm w-full">
          <li :if={@current_user.role == :admin}>
            <.link navigate={~p"/admin"}>Admin</.link>
          </li>
          <li>
            <.link navigate={~p"/account/settings/profile"}>Account Settings</.link>
          </li>
          <li>
            <.link href={~p"/sign-out"}>Sign out</.link>
          </li>
        </ul>
      </div>
    </aside>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
