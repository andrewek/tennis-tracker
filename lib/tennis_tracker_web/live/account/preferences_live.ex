defmodule TennisTrackerWeb.Account.PreferencesLive do
  use TennisTrackerWeb, :live_view

  alias TennisTrackerWeb.AccountComponents

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Preferences Settings")
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <.page_header title="Account Settings" />
      <AccountComponents.settings_layout current_page={:preferences}>
        <div class="space-y-6">
          <section>
            <h2 class="text-lg font-semibold mb-4">Theme</h2>
            <p class="text-base-content/60 mb-4 text-sm">
              Choose your preferred color theme. Your selection is saved in your browser.
            </p>
            <div class="form-control w-full max-w-xs">
              <label class="label">
                <span class="label-text font-medium">Color Theme</span>
              </label>
              <select
                phx-hook="ThemeSelect"
                id="theme-select"
                class="select select-bordered w-full max-w-xs"
                onchange="this.dataset.phxTheme = this.value; this.dispatchEvent(new Event('phx:set-theme', {bubbles: true}))"
              >
                <option value="system">System (follow OS setting)</option>
                <option value="light">Light</option>
                <option value="dark">Dark</option>
              </select>
            </div>
          </section>
        </div>
      </AccountComponents.settings_layout>
    </Layouts.app>
    """
  end
end
