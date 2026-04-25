defmodule TennisTrackerWeb.Players.ShowLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    socket
    |> assign(:player, nil)
    |> assign(:memberships, [])
    |> assign(:show_delete_modal, false)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    player =
      Tennis.get_player!(id,
        tenant: group_id,
        actor: current_user,
        load: [tags: [:tag_category]]
      )

    memberships =
      Tennis.list_real_memberships_for_player!(id,
        tenant: group_id,
        actor: current_user,
        load: [:display_label, :team]
      )

    socket
    |> assign(:player, player)
    |> assign(:memberships, memberships)
    |> noreply()
  end

  def handle_event("show_delete_modal", _params, socket) do
    socket |> assign(:show_delete_modal, true) |> noreply()
  end

  def handle_event("hide_delete_modal", _params, socket) do
    socket |> assign(:show_delete_modal, false) |> noreply()
  end

  def handle_event("delete", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    group_slug = socket.assigns.current_group.slug
    Tennis.destroy_player!(socket.assigns.player, tenant: group_id, actor: current_user)

    socket
    |> put_flash(:info, "Player deleted.")
    |> push_navigate(to: ~p"/g/#{group_slug}/players")
    |> noreply()
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
        title={@player.name}
        back_href={~p"/g/#{@current_group.slug}/players"}
        back_label="Players"
      >
        <:subtitle>
          {if @player.ntrp_rating, do: @player.ntrp_rating, else: "No NTRP rating"}
        </:subtitle>
        <:actions>
          <div class="flex gap-2">
            <.button navigate={~p"/g/#{@current_group.slug}/players/#{@player.id}/edit"}>
              Edit
            </.button>
            <button phx-click="show_delete_modal" class="btn btn-error btn-soft">Delete</button>
          </div>
        </:actions>
      </.page_header>

      <.modal
        :if={@show_delete_modal}
        title="Delete Player"
        on_close="hide_delete_modal"
      >
        <p class="text-sm text-base-content/70 mb-6">
          Delete <strong>{@player.name}</strong>? This cannot be undone.
        </p>
        <div class="flex gap-2">
          <button phx-click="delete" class="btn btn-error flex-1">Delete</button>
          <button phx-click="hide_delete_modal" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>

      <.list>
        <:item title="Email">{@player.email || "—"}</:item>
        <:item title="Phone">{@player.phone_number || "—"}</:item>
      </.list>

      <%!-- Tags grouped by category --%>
      <% tag_groups = Enum.group_by(@player.tags, & &1.tag_category) %>
      <div :if={tag_groups != %{}} class="mt-6">
        <h2 class="text-lg font-semibold mb-2">Tags</h2>
        <div class="space-y-2">
          <%= for {category, tags} <- tag_groups do %>
            <div class="flex items-start gap-2">
              <span class="text-sm text-base-content/60 w-24 shrink-0">{category.name}</span>
              <div class="flex gap-1 flex-wrap">
                <span :for={tag <- tags} class="badge badge-sm badge-ghost">{tag.name}</span>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <div class="mt-6">
        <h2 class="text-lg font-semibold mb-2">Team Memberships</h2>
        <%= if @memberships == [] do %>
          <p class="text-base-content/60 text-sm">No team memberships.</p>
        <% else %>
          <ul class="space-y-1">
            <%= for membership <- @memberships do %>
              <li class="text-sm">
                <.link
                  navigate={~p"/g/#{@current_group.slug}/teams/#{membership.team.id}"}
                  class="hover:underline"
                >
                  {membership.display_label}
                </.link>
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
