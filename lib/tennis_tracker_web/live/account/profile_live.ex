defmodule TennisTrackerWeb.Account.ProfileLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Accounts
  alias TennisTrackerWeb.AccountComponents

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    name_form =
      AshPhoenix.Form.for_update(user, :update_profile,
        as: "name_form",
        actor: user,
        domain: Accounts
      )

    email_form =
      AshPhoenix.Form.for_update(user, :update_email,
        as: "email_form",
        actor: user,
        domain: Accounts
      )

    socket
    |> assign(:page_title, "Profile Settings")
    |> assign(:name_form, to_form(name_form))
    |> assign(:email_form, to_form(email_form))
    |> ok()
  end

  def handle_event("save_name", %{"name_form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.name_form.source, params: params) do
      {:ok, user} ->
        name_form =
          AshPhoenix.Form.for_update(user, :update_profile,
            as: "name_form",
            actor: user,
            domain: Accounts
          )

        socket
        |> put_flash(:info, "Name updated successfully.")
        |> assign(:name_form, to_form(name_form))
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:name_form, to_form(form))
        |> noreply()
    end
  end

  def handle_event("save_email", %{"email_form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.email_form.source, params: params) do
      {:ok, user} ->
        email_form =
          AshPhoenix.Form.for_update(user, :update_email,
            as: "email_form",
            actor: user,
            domain: Accounts
          )

        socket
        |> put_flash(:info, "Email updated successfully.")
        |> assign(:email_form, to_form(email_form))
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:email_form, to_form(form))
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
      <AccountComponents.settings_layout current_page={:profile}>
        <div class="space-y-8">
          <section>
            <h2 class="text-lg font-semibold mb-4">Name</h2>
            <.form for={@name_form} id="name-form" phx-submit="save_name" class="space-y-4">
              <.input field={@name_form[:name]} label="Name" />
              <.button type="submit">Save Name</.button>
            </.form>
          </section>

          <div class="divider"></div>

          <section>
            <h2 class="text-lg font-semibold mb-4">Email Address</h2>
            <.form for={@email_form} id="email-form" phx-submit="save_email" class="space-y-4">
              <.input field={@email_form[:email]} label="Email" type="email" />
              <.button type="submit">Save Email</.button>
            </.form>
          </section>
        </div>
      </AccountComponents.settings_layout>
    </Layouts.app>
    """
  end
end
