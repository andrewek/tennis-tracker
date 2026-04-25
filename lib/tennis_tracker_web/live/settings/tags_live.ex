defmodule TennisTrackerWeb.Settings.TagsLive do
  use TennisTrackerWeb, :live_view

  require Ash.Query

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    tag_categories = load_categories(group_id, current_user)
    is_owner = socket.assigns.current_group_role in [:owner, :admin]

    socket
    |> assign(:tag_categories, tag_categories)
    |> assign(:is_owner, is_owner)
    |> assign(:new_category_name, "")
    |> assign(:editing_category_id, nil)
    |> assign(:editing_category_name, "")
    |> assign(:new_tag_names, %{})
    |> assign(:editing_tag_id, nil)
    |> assign(:editing_tag_name, "")
    |> assign(:confirm_delete_category, nil)
    |> assign(:confirm_delete_tag, nil)
    |> ok()
  end

  defp load_categories(group_id, current_user) do
    Tennis.list_tag_categories!(load: [:tags], tenant: group_id, actor: current_user)
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <.page_header title="Tags" />

      <div class="max-w-2xl space-y-8">
        <%!-- Existing categories --%>
        <%= for category <- @tag_categories do %>
          <div class="border border-base-300 rounded-lg p-4">
            <%!-- Category header --%>
            <div class="flex items-center gap-2 mb-3">
              <%= if @is_owner && @editing_category_id == category.id do %>
                <form phx-submit="save_category_name" class="flex items-center gap-2 flex-1">
                  <input type="hidden" name="category_id" value={category.id} />
                  <input
                    type="text"
                    name="name"
                    value={@editing_category_name}
                    class="input input-sm flex-1"
                    autofocus
                    phx-keydown="cancel_edit_category"
                    phx-key="Escape"
                  />
                  <button type="submit" class="btn btn-xs btn-primary">Save</button>
                  <button
                    type="button"
                    phx-click="cancel_edit_category"
                    class="btn btn-xs btn-ghost"
                  >
                    Cancel
                  </button>
                </form>
              <% else %>
                <h2 class="font-semibold flex-1">{category.name}</h2>
                <%= if @is_owner do %>
                  <button
                    phx-click="edit_category"
                    phx-value-category_id={category.id}
                    phx-value-name={category.name}
                    class="btn btn-xs btn-ghost"
                  >
                    Rename
                  </button>
                  <button
                    phx-click="confirm_delete_category"
                    phx-value-category_id={category.id}
                    class="btn btn-xs btn-ghost text-error"
                  >
                    Delete
                  </button>
                <% end %>
              <% end %>
            </div>

            <%!-- Tags --%>
            <div class="flex flex-wrap gap-2 mb-3">
              <%= for tag <- category.tags do %>
                <div class="flex items-center gap-1">
                  <%= if @is_owner && @editing_tag_id == tag.id do %>
                    <form phx-submit="save_tag_name" class="flex items-center gap-1">
                      <input type="hidden" name="tag_id" value={tag.id} />
                      <input
                        type="text"
                        name="name"
                        value={@editing_tag_name}
                        class="input input-xs w-32"
                        autofocus
                        phx-keydown="cancel_edit_tag"
                        phx-key="Escape"
                      />
                      <button type="submit" class="btn btn-xs btn-primary">Save</button>
                      <button
                        type="button"
                        phx-click="cancel_edit_tag"
                        class="btn btn-xs btn-ghost"
                      >
                        Cancel
                      </button>
                    </form>
                  <% else %>
                    <span class="badge badge-sm badge-ghost">{tag.name}</span>
                    <%= if @is_owner do %>
                      <button
                        phx-click="edit_tag"
                        phx-value-tag_id={tag.id}
                        phx-value-name={tag.name}
                        class="btn btn-xs btn-ghost p-0.5"
                        title="Rename"
                      >
                        <.icon name="hero-pencil-square" class="size-3.5" />
                      </button>
                      <button
                        phx-click="confirm_delete_tag"
                        phx-value-tag_id={tag.id}
                        phx-value-tag_name={tag.name}
                        class="btn btn-xs btn-ghost p-0.5 text-error"
                        title="Delete"
                      >
                        <.icon name="hero-trash" class="size-3.5" />
                      </button>
                    <% end %>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%!-- Add tag form --%>
            <form :if={@is_owner} phx-submit="create_tag" class="flex items-center gap-2">
              <input type="hidden" name="category_id" value={category.id} />
              <input
                type="text"
                name="tag_name"
                value={Map.get(@new_tag_names, category.id, "")}
                placeholder="New tag name…"
                class="input input-xs flex-1 max-w-xs"
              />
              <button type="submit" class="btn btn-xs btn-ghost">Add</button>
            </form>
          </div>
        <% end %>

        <%!-- Create category form (owners only) --%>
        <form :if={@is_owner} phx-submit="create_category" class="flex items-center gap-2">
          <input
            type="text"
            name="name"
            value={@new_category_name}
            placeholder="New category name…"
            class="input input-sm max-w-xs"
          />
          <button type="submit" class="btn btn-sm btn-primary">Add Category</button>
        </form>
      </div>

      <%!-- Confirm delete category modal --%>
      <.modal
        :if={@confirm_delete_category}
        title="Delete Tag Category"
        on_close="cancel_delete_category"
      >
        <% category = @confirm_delete_category %>
        <p class="text-sm text-base-content/70 mb-2">
          Delete category <strong>{category.name}</strong>? This cannot be undone.
        </p>
        <%= if length(category.tags) > 0 do %>
          <p class="text-sm text-error mb-4">
            This will also delete <strong>{length(category.tags)}</strong>
            {if length(category.tags) == 1, do: "tag", else: "tags"} and remove them from all players.
          </p>
        <% end %>
        <div class="flex gap-2">
          <button
            phx-click="delete_category"
            phx-value-category_id={category.id}
            class="btn btn-error flex-1"
          >
            Delete
          </button>
          <button phx-click="cancel_delete_category" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>

      <%!-- Confirm delete tag modal --%>
      <.modal
        :if={@confirm_delete_tag}
        title="Delete Tag"
        on_close="cancel_delete_tag"
      >
        <p class="text-sm text-base-content/70 mb-6">
          Delete tag <strong>{@confirm_delete_tag.name}</strong>? This cannot be undone.
        </p>
        <div class="flex gap-2">
          <button
            phx-click="delete_tag"
            phx-value-tag_id={@confirm_delete_tag.id}
            class="btn btn-error flex-1"
          >
            Delete
          </button>
          <button phx-click="cancel_delete_tag" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  # --- Category events ---

  def handle_event("create_category", %{"name" => name}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Tennis.create_tag_category(%{name: name, group_id: group_id},
           actor: current_user,
           tenant: group_id
         ) do
      {:ok, _} ->
        socket
        |> assign(:new_category_name, "")
        |> reload_categories()
        |> noreply()

      {:error, error} ->
        socket
        |> put_flash(:error, format_error(error))
        |> noreply()
    end
  end

  def handle_event("edit_category", %{"category_id" => id, "name" => name}, socket) do
    socket
    |> assign(:editing_category_id, id)
    |> assign(:editing_category_name, name)
    |> noreply()
  end

  def handle_event("cancel_edit_category", _params, socket) do
    socket
    |> assign(:editing_category_id, nil)
    |> assign(:editing_category_name, "")
    |> noreply()
  end

  def handle_event("save_category_name", %{"category_id" => id, "name" => name}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    category = Tennis.get_tag_category!(id, tenant: group_id, actor: current_user)

    case Tennis.update_tag_category(category, %{name: name},
           actor: current_user,
           tenant: group_id
         ) do
      {:ok, _} ->
        socket
        |> assign(:editing_category_id, nil)
        |> assign(:editing_category_name, "")
        |> reload_categories()
        |> noreply()

      {:error, error} ->
        socket
        |> put_flash(:error, format_error(error))
        |> noreply()
    end
  end

  def handle_event("confirm_delete_category", %{"category_id" => id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    category =
      Tennis.get_tag_category!(id,
        tenant: group_id,
        actor: current_user,
        load: [:tags]
      )

    socket
    |> assign(:confirm_delete_category, category)
    |> noreply()
  end

  def handle_event("cancel_delete_category", _params, socket) do
    socket |> assign(:confirm_delete_category, nil) |> noreply()
  end

  def handle_event("delete_category", %{"category_id" => id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    category = Tennis.get_tag_category!(id, tenant: group_id, actor: current_user)

    case Tennis.destroy_tag_category(category, actor: current_user, tenant: group_id) do
      :ok ->
        socket
        |> assign(:confirm_delete_category, nil)
        |> put_flash(:info, "Category deleted.")
        |> reload_categories()
        |> noreply()

      {:error, error} ->
        socket
        |> assign(:confirm_delete_category, nil)
        |> put_flash(:error, format_error(error))
        |> noreply()
    end
  end

  # --- Tag events ---

  def handle_event("create_tag", %{"category_id" => category_id, "tag_name" => name}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case Tennis.create_tag(%{name: name, group_id: group_id, tag_category_id: category_id},
           actor: current_user,
           tenant: group_id
         ) do
      {:ok, _} ->
        new_tag_names = Map.delete(socket.assigns.new_tag_names, category_id)

        socket
        |> assign(:new_tag_names, new_tag_names)
        |> reload_categories()
        |> noreply()

      {:error, error} ->
        socket
        |> put_flash(:error, format_error(error))
        |> noreply()
    end
  end

  def handle_event("edit_tag", %{"tag_id" => id, "name" => name}, socket) do
    socket
    |> assign(:editing_tag_id, id)
    |> assign(:editing_tag_name, name)
    |> noreply()
  end

  def handle_event("cancel_edit_tag", _params, socket) do
    socket
    |> assign(:editing_tag_id, nil)
    |> assign(:editing_tag_name, "")
    |> noreply()
  end

  def handle_event("save_tag_name", %{"tag_id" => id, "name" => name}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    tag = Tennis.get_tag!(id, tenant: group_id, actor: current_user)

    case Tennis.update_tag(tag, %{name: name},
           actor: current_user,
           tenant: group_id
         ) do
      {:ok, _} ->
        socket
        |> assign(:editing_tag_id, nil)
        |> assign(:editing_tag_name, "")
        |> reload_categories()
        |> noreply()

      {:error, error} ->
        socket
        |> put_flash(:error, format_error(error))
        |> noreply()
    end
  end

  def handle_event("confirm_delete_tag", %{"tag_id" => id, "tag_name" => name}, socket) do
    socket
    |> assign(:confirm_delete_tag, %{id: id, name: name})
    |> noreply()
  end

  def handle_event("cancel_delete_tag", _params, socket) do
    socket |> assign(:confirm_delete_tag, nil) |> noreply()
  end

  def handle_event("delete_tag", %{"tag_id" => id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    tag = Tennis.get_tag!(id, tenant: group_id, actor: current_user)

    case Tennis.destroy_tag(tag, actor: current_user, tenant: group_id) do
      :ok ->
        socket
        |> assign(:confirm_delete_tag, nil)
        |> put_flash(:info, "Tag deleted.")
        |> reload_categories()
        |> noreply()

      {:error, error} ->
        socket
        |> assign(:confirm_delete_tag, nil)
        |> put_flash(:error, format_error(error))
        |> noreply()
    end
  end

  defp reload_categories(socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    assign(socket, :tag_categories, load_categories(group_id, current_user))
  end

  defp format_error(%Ash.Error.Invalid{errors: [%{message: msg} | _]}), do: msg
  defp format_error(%{message: msg}), do: msg
  defp format_error(_), do: "An error occurred."
end
