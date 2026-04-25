defmodule TennisTrackerWeb.Settings.Members.NewLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Groups

  def mount(_params, _session, socket) do
    if socket.assigns.current_group_role in [:owner, :admin] do
      socket
      |> assign(:form, to_form(%{"email" => "", "role" => "member"}, as: :member))
      |> assign(:error, nil)
      |> assign(:new_user_password, nil)
      |> ok()
    else
      socket
      |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}")
      |> ok()
    end
  end

  def handle_event("add_member", %{"member" => %{"email" => email, "role" => role}}, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    slug = socket.assigns.current_group.slug
    role_atom = String.to_existing_atom(role)

    case Groups.add_member_by_email(email, role_atom, actor: current_user, tenant: group_id) do
      {:ok, %{new_user?: false}} ->
        socket
        |> put_flash(:info, "#{email} has been added to the group.")
        |> push_navigate(to: ~p"/g/#{slug}/settings/members")
        |> noreply()

      {:ok, %{temp_password: temp_password}} ->
        socket
        |> assign(:new_user_password, temp_password)
        |> assign(:form, to_form(%{"email" => "", "role" => "member"}, as: :member))
        |> assign(:error, nil)
        |> noreply()

      {:error, reason} ->
        socket
        |> assign(:error, format_error(reason))
        |> assign(:form, to_form(%{"email" => email, "role" => role}, as: :member))
        |> noreply()
    end
  end

  def handle_event("dismiss_password_card", _params, socket) do
    slug = socket.assigns.current_group.slug

    socket
    |> push_navigate(to: ~p"/g/#{slug}/settings/members")
    |> noreply()
  end

  defp format_error(%Ash.Error.Invalid{errors: [%{message: msg} | _]}) when is_binary(msg),
    do: msg

  defp format_error(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(& &1.message)
    |> Enum.reject(&is_nil/1)
    |> case do
      [msg | _] -> msg
      [] -> "An error occurred."
    end
  end

  defp format_error(_), do: "An error occurred."

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <.page_header title="Add Member">
        <:actions>
          <.link
            navigate={~p"/g/#{@current_group.slug}/settings/members"}
            class="btn btn-ghost btn-sm"
          >
            Cancel
          </.link>
        </:actions>
      </.page_header>

      <div
        :if={@new_user_password}
        class="alert alert-info mb-6 max-w-lg flex flex-col items-start gap-2"
      >
        <p class="font-semibold">New account created</p>
        <p class="text-sm">Share this temporary password with the new member:</p>
        <code class="bg-base-100 px-3 py-1 rounded font-mono text-sm">{@new_user_password}</code>
        <button phx-click="dismiss_password_card" class="btn btn-sm btn-ghost">
          Dismiss
        </button>
      </div>

      <div :if={!@new_user_password} class="max-w-lg">
        <p :if={@error} class="text-error text-sm mb-2">{@error}</p>
        <.form
          id="add-member-form"
          for={@form}
          phx-submit="add_member"
          class="flex flex-col gap-1"
        >
          <.input
            field={@form[:email]}
            type="email"
            label="Email"
            placeholder="member@example.com"
            required
          />
          <.input
            field={@form[:role]}
            type="select"
            label="Role"
            options={[{"Member", "member"}, {"Owner", "owner"}]}
          />
          <div class="mt-2">
            <.button type="submit">Add Member</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end
end
