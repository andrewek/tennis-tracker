defmodule TennisTrackerWeb.Settings.Locations.FormLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.Location

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :form, nil)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    if Ash.can?({Location, :create, %{group_id: group_id}}, current_user,
         domain: Tennis,
         tenant: group_id
       ) do
      form =
        AshPhoenix.Form.for_create(Location, :create,
          domain: Tennis,
          actor: current_user,
          tenant: group_id
        )
        |> to_form()

      assign(socket, :form, form)
    else
      socket
      |> put_flash(:error, "You don't have permission to access group settings.")
      |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}")
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    location = Tennis.get_location!(id, tenant: group_id, actor: current_user)

    changeset =
      Ash.Changeset.for_update(location, :update, %{},
        actor: current_user,
        tenant: group_id,
        domain: Tennis
      )

    if Ash.can?(changeset, current_user, domain: Tennis) do
      form =
        AshPhoenix.Form.for_update(location, :update,
          domain: Tennis,
          actor: current_user,
          tenant: group_id
        )
        |> to_form()

      assign(socket, :form, form)
    else
      socket
      |> put_flash(:error, "You don't have permission to access group settings.")
      |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}")
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    group_id = socket.assigns.current_group_id
    group_slug = socket.assigns.current_group.slug
    params = Map.put(params, "group_id", group_id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _location} ->
        socket
        |> put_flash(:info, "Location saved.")
        |> push_navigate(to: ~p"/g/#{group_slug}/settings/locations")
        |> noreply()

      {:error, form} ->
        socket |> assign(:form, form) |> noreply()
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
      <.page_header
        title={if @live_action == :new, do: "Add Location", else: "Edit Location"}
        back_href={~p"/g/#{@current_group.slug}/settings/locations"}
        back_label="Locations"
      />

      <div class="max-w-lg">
        <.form :if={@form} for={@form} phx-change="validate" phx-submit="save">
          <.input field={@form[:name]} type="text" label="Name" />
          <.input field={@form[:street_address]} type="text" label="Street Address (optional)" />
          <.input field={@form[:city]} type="text" label="City (optional)" />
          <.input field={@form[:state]} type="text" label="State (optional)" />
          <.input field={@form[:postal_code]} type="text" label="Postal Code (optional)" />
          <.input field={@form[:google_maps_url]} type="text" label="Google Maps URL (optional)" />
          <div class="mt-4">
            <.button type="submit">
              {if @live_action == :new, do: "Add Location", else: "Save Changes"}
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
