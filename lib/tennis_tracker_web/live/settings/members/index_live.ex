defmodule TennisTrackerWeb.Settings.Members.IndexLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Groups
  alias TennisTracker.Groups.GroupMembership

  def mount(_params, _session, socket) do
    if socket.assigns.current_group_role in [:owner, :admin] do
      group_id = socket.assigns.current_group_id
      current_user = socket.assigns.current_user

      memberships =
        Groups.list_group_memberships_for_group!(group_id,
          actor: current_user,
          tenant: group_id
        )

      socket
      |> stream(:memberships, memberships)
      |> assign(:confirm_remove_membership, nil)
      |> ok()
    else
      socket
      |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}")
      |> ok()
    end
  end

  def handle_event("change_role", %{"membership_id" => id, "role" => role}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    membership = get_membership!(id, group_id, current_user)
    role_atom = String.to_existing_atom(role)

    with {:ok, updated} <-
           Groups.update_group_membership_role(membership, %{role: role_atom},
             actor: current_user,
             tenant: group_id
           ),
         {:ok, updated} <- Ash.load(updated, :user, domain: Groups, authorize?: false) do
      socket
      |> stream_insert(:memberships, updated)
      |> noreply()
    else
      {:error, _} ->
        socket
        |> put_flash(:error, "Could not update role.")
        |> noreply()
    end
  end

  def handle_event("request_remove", %{"id" => id}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    membership = get_membership!(id, group_id, current_user)

    socket
    |> assign(:confirm_remove_membership, membership)
    |> noreply()
  end

  def handle_event("cancel_remove", _params, socket) do
    socket
    |> assign(:confirm_remove_membership, nil)
    |> noreply()
  end

  def handle_event("close_remove_modal", _params, socket) do
    socket
    |> assign(:confirm_remove_membership, nil)
    |> noreply()
  end

  def handle_event("confirm_remove", _params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    membership = socket.assigns.confirm_remove_membership

    case Ash.destroy(membership, actor: current_user, tenant: group_id, domain: Groups) do
      :ok ->
        socket
        |> stream_delete(:memberships, membership)
        |> assign(:confirm_remove_membership, nil)
        |> put_flash(:info, "#{membership.user.email} has been removed from the group.")
        |> noreply()

      {:error, _} ->
        socket
        |> assign(:confirm_remove_membership, nil)
        |> put_flash(:error, "Could not remove member.")
        |> noreply()
    end
  end

  defp get_membership!(id, group_id, current_user) do
    Ash.get!(GroupMembership, id,
      actor: current_user,
      tenant: group_id,
      domain: Groups,
      load: [:user]
    )
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <.page_header title="Members">
        <:actions>
          <.link
            navigate={~p"/g/#{@current_group.slug}/settings/members/new"}
            class="btn btn-primary btn-sm"
          >
            Add Member
          </.link>
        </:actions>
      </.page_header>

      <%!-- Members list --%>
      <div class="max-w-2xl">
        <table class="table w-full">
          <thead>
            <tr>
              <th>Name / Email</th>
              <th>Role</th>
              <th></th>
            </tr>
          </thead>
          <tbody id="memberships" phx-update="stream">
            <tr :for={{dom_id, m} <- @streams.memberships} id={dom_id}>
              <td>
                <p class="font-medium">{m.user.name || to_string(m.user.email)}</p>
                <p :if={m.user.name} class="text-sm text-base-content/60">
                  {to_string(m.user.email)}
                </p>
              </td>
              <td>
                <%= if m.user_id == @current_user.id do %>
                  <span class="badge badge-ghost">{m.role}</span>
                <% else %>
                  <form phx-change="change_role" phx-value-membership_id={m.id}>
                    <select name="role" class="select select-bordered select-sm">
                      <option value="member" selected={m.role == :member}>Member</option>
                      <option value="owner" selected={m.role == :owner}>Owner</option>
                    </select>
                  </form>
                <% end %>
              </td>
              <td>
                <button
                  :if={m.user_id != @current_user.id}
                  phx-click="request_remove"
                  phx-value-id={m.id}
                  class="btn btn-xs btn-ghost text-error"
                >
                  Remove
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.modal
        :if={@confirm_remove_membership != nil}
        title="Remove Member"
        on_close="close_remove_modal"
      >
        <p class="text-sm text-base-content/70 mb-6">
          Remove <strong>{@confirm_remove_membership.user.email}</strong> from this group?
          Their account will not be deleted.
        </p>
        <div class="flex gap-2">
          <button phx-click="confirm_remove" class="btn btn-error flex-1">Remove</button>
          <button phx-click="cancel_remove" class="btn btn-ghost">Cancel</button>
        </div>
      </.modal>
    </Layouts.app>
    """
  end
end
