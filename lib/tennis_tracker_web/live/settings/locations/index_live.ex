defmodule TennisTrackerWeb.Settings.Locations.IndexLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.Location

  def mount(_params, _session, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    if Ash.can?({Location, :create, %{group_id: group_id}}, current_user,
         domain: Tennis,
         tenant: group_id
       ) do
      active =
        Tennis.list_locations!(tenant: group_id, actor: current_user, load: [:formatted_address])

      archived =
        Tennis.list_archived_locations!(
          tenant: group_id,
          actor: current_user,
          load: [:formatted_address]
        )

      socket =
        socket
        |> assign(:active_locations, active)
        |> assign(:archived_locations, archived)
        |> assign(:tab, :active)
        |> assign(:confirm_action, nil)
        |> assign(:confirm_location_id, nil)
        |> assign(:confirm_location_name, nil)

      socket |> ok()
    else
      socket
      |> put_flash(:error, "You don't have permission to access group settings.")
      |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}")
      |> ok()
    end
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  def handle_event("request_archive", %{"id" => id, "name" => name}, socket) do
    socket
    |> assign(:confirm_action, :archive)
    |> assign(:confirm_location_id, id)
    |> assign(:confirm_location_name, name)
    |> noreply()
  end

  def handle_event("request_restore", %{"id" => id, "name" => name}, socket) do
    socket
    |> assign(:confirm_action, :restore)
    |> assign(:confirm_location_id, id)
    |> assign(:confirm_location_name, name)
    |> noreply()
  end

  def handle_event("confirm_action", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    location_id = socket.assigns.confirm_location_id

    socket =
      case socket.assigns.confirm_action do
        :archive ->
          location = Tennis.get_location!(location_id, tenant: group_id, actor: current_user)
          Tennis.archive_location!(location, tenant: group_id, actor: current_user)

          archived =
            Tennis.list_archived_locations!(
              tenant: group_id,
              actor: current_user,
              load: [:formatted_address]
            )

          active =
            Tennis.list_locations!(
              tenant: group_id,
              actor: current_user,
              load: [:formatted_address]
            )

          socket
          |> assign(:active_locations, active)
          |> assign(:archived_locations, archived)
          |> put_flash(:info, "Location archived.")

        :restore ->
          location =
            Tennis.get_archived_location!(location_id, tenant: group_id, actor: current_user)

          Tennis.unarchive_location!(location, tenant: group_id, actor: current_user)

          active =
            Tennis.list_locations!(
              tenant: group_id,
              actor: current_user,
              load: [:formatted_address]
            )

          archived =
            Tennis.list_archived_locations!(
              tenant: group_id,
              actor: current_user,
              load: [:formatted_address]
            )

          socket
          |> assign(:active_locations, active)
          |> assign(:archived_locations, archived)
          |> put_flash(:info, "Location restored.")
      end

    socket
    |> assign(:confirm_action, nil)
    |> assign(:confirm_location_id, nil)
    |> assign(:confirm_location_name, nil)
    |> noreply()
  end

  def handle_event("cancel_action", _params, socket) do
    socket
    |> assign(:confirm_action, nil)
    |> assign(:confirm_location_id, nil)
    |> assign(:confirm_location_name, nil)
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
      <.page_header title="Locations">
        <:actions>
          <.link navigate={~p"/g/#{@current_group.slug}/settings/locations/new"}>
            <.button>Add Location</.button>
          </.link>
        </:actions>
      </.page_header>

      <div role="tablist" class="tabs tabs-bordered mb-6">
        <button
          role="tab"
          class={["tab", @tab == :active && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="active"
        >
          Active
        </button>
        <button
          role="tab"
          class={["tab", @tab == :archived && "tab-active"]}
          phx-click="switch_tab"
          phx-value-tab="archived"
        >
          Archived
        </button>
      </div>

      <div class={[@tab != :active && "hidden"]}>
        <div>
          <div
            :for={location <- @active_locations}
            id={location.id}
            class="flex items-center justify-between py-3 border-b border-base-300 last:border-0"
          >
            <div>
              <p class="font-medium">{location.name}</p>
              <p :if={location.formatted_address} class="text-sm text-base-content/60">
                {location.formatted_address}
              </p>
            </div>
            <div class="flex gap-2">
              <.link
                navigate={~p"/g/#{@current_group.slug}/settings/locations/#{location.id}/edit"}
                class="btn btn-ghost btn-sm"
              >
                Edit
              </.link>
              <button
                class="btn btn-ghost btn-sm text-warning"
                phx-click="request_archive"
                phx-value-id={location.id}
                phx-value-name={location.name}
              >
                Archive
              </button>
            </div>
          </div>
        </div>
        <p
          :if={@active_locations == []}
          class="text-base-content/60 text-sm py-4"
        >
          No locations yet.
          <.link
            navigate={~p"/g/#{@current_group.slug}/settings/locations/new"}
            class="link link-primary"
          >
            Add the first one.
          </.link>
        </p>
      </div>

      <div class={[@tab != :archived && "hidden"]}>
        <div>
          <div
            :for={location <- @archived_locations}
            id={location.id}
            class="flex items-center justify-between py-3 border-b border-base-300 last:border-0 opacity-60"
          >
            <div>
              <p class="font-medium">{location.name}</p>
              <p :if={location.formatted_address} class="text-sm text-base-content/60">
                {location.formatted_address}
              </p>
            </div>
            <button
              class="btn btn-ghost btn-sm"
              phx-click="request_restore"
              phx-value-id={location.id}
              phx-value-name={location.name}
            >
              Restore
            </button>
          </div>
        </div>
        <p :if={@archived_locations == []} class="text-base-content/60 text-sm py-4">
          No archived locations.
        </p>
      </div>

      <.modal
        :if={@confirm_action != nil}
        title={if @confirm_action == :archive, do: "Archive Location", else: "Restore Location"}
        on_close={JS.push("cancel_action")}
      >
        <p class="text-sm text-base-content/70 mb-6">
          <%= if @confirm_action == :archive do %>
            Archive <strong>{@confirm_location_name}</strong>? It will no longer appear in the
            location dropdown when creating or editing matches.
          <% else %>
            Restore <strong>{@confirm_location_name}</strong>? It will become available in the
            location dropdown again.
          <% end %>
        </p>
        <div class="flex gap-2">
          <button phx-click="confirm_action" class="btn btn-primary flex-1">
            {if @confirm_action == :archive, do: "Archive", else: "Restore"}
          </button>
          <button phx-click="cancel_action" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end
end
