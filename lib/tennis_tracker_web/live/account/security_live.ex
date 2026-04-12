defmodule TennisTrackerWeb.Account.SecurityLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Accounts
  alias TennisTrackerWeb.AccountComponents

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    form =
      AshPhoenix.Form.for_update(user, :change_password,
        as: "password_form",
        actor: user,
        domain: Accounts
      )

    socket
    |> assign(:page_title, "Security Settings")
    |> assign(:form, to_form(form))
    |> ok()
  end

  def handle_event("save_password", %{"password_form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _user} ->
        socket
        |> redirect(to: ~p"/sign-out")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, to_form(form))
        |> noreply()
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
      <.page_header title="Account Settings" />
      <AccountComponents.settings_layout current_page={:security}>
        <div class="space-y-6">
          <div role="alert" class="alert alert-warning">
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <span>Saving a new password will sign you out of all sessions immediately.</span>
          </div>

          <.form for={@form} id="security-form" phx-submit="save_password" class="space-y-4">
            <.input
              field={@form[:current_password]}
              label="Current Password"
              type="password"
            />
            <.input
              field={@form[:password]}
              label="New Password"
              type="password"
            />
            <.input
              field={@form[:password_confirmation]}
              label="Confirm New Password"
              type="password"
            />
            <.button type="submit" class="btn-warning">Change Password</.button>
          </.form>
        </div>
      </AccountComponents.settings_layout>
    </Layouts.app>
    """
  end
end
