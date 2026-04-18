defmodule TennisTrackerWeb.Settings.SeasonRules.IndexLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.SeasonRules

  require Ash.Query

  def mount(_params, _session, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    if socket.assigns.current_group_role in [:owner, :admin] do
      season_rules =
        SeasonRules
        |> Ash.Query.for_read(:read, %{}, actor: current_user)
        |> Ash.Query.load([:team_type, :default_tags])
        |> Ash.Query.sort(season_year: :desc)
        |> Ash.read!(domain: Tennis, tenant: group_id)

      socket
      |> assign(:season_rules, season_rules)
      |> ok()
    else
      socket
      |> put_flash(:error, "You don't have permission to access group settings.")
      |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}")
      |> ok()
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
      <.page_header title="Season Rules">
        <:actions>
          <.button navigate={~p"/g/#{@current_group.slug}/settings/season-rules/new"}>
            New Season Rules
          </.button>
        </:actions>
      </.page_header>

      <div class="max-w-2xl">
        <%= if @season_rules == [] do %>
          <p class="text-base-content/60 text-sm">No season rules configured yet.</p>
        <% else %>
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Team Type</th>
                <th>Season Year</th>
                <th>Default Tags</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for sr <- @season_rules do %>
                <tr>
                  <td>{(sr.team_type && sr.team_type.name) || "—"}</td>
                  <td>{sr.season_year}</td>
                  <td>
                    <span class="inline-flex gap-1 flex-wrap">
                      <span :for={tag <- sr.default_tags} class="badge badge-sm badge-ghost">
                        {tag.name}
                      </span>
                    </span>
                  </td>
                  <td>
                    <.link
                      navigate={~p"/g/#{@current_group.slug}/settings/season-rules/#{sr.id}/edit"}
                      class="btn btn-xs btn-ghost"
                    >
                      Edit
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
