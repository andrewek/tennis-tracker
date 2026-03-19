defmodule TennisTrackerWeb.Players.FormLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.Player

  @ntrp_options [
    {"2.5", "2.5"},
    {"3.0", "3.0"},
    {"3.5", "3.5"},
    {"4.0", "4.0"},
    {"4.5", "4.5"},
    {"5.0", "5.0"}
  ]

  def mount(_params, _session, socket) do
    socket
    |> assign(:ntrp_options, @ntrp_options)
    |> assign(:player_id, nil)
    |> ok()
  end

  def handle_params(params, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    {form, player_id} =
      case socket.assigns.live_action do
        :new ->
          form =
            AshPhoenix.Form.for_create(Player, :create,
              domain: Tennis,
              actor: current_user,
              tenant: group_id
            )
            |> to_form()

          {form, nil}

        :edit ->
          player = Tennis.get_player!(params["id"], tenant: group_id, actor: current_user)

          form =
            AshPhoenix.Form.for_update(player, :update,
              domain: Tennis,
              actor: current_user,
              tenant: group_id
            )
            |> to_form()

          {form, player.id}
      end

    socket
    |> assign(:form, form)
    |> assign(:player_id, player_id)
    |> noreply()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_group={@current_group}>
      <%= if @live_action == :new do %>
        <.page_header
          title="New Player"
          back_href={~p"/g/#{@current_group.slug}/players"}
          back_label="Players"
        />
      <% else %>
        <.page_header
          title="Edit Player"
          back_href={~p"/g/#{@current_group.slug}/players/#{@player_id}"}
          back_label="Player"
        />
      <% end %>

      <.form
        for={@form}
        id="player-form"
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:email]} type="email" label="Email" />
        <.input field={@form[:phone_number]} type="tel" label="Phone Number" />
        <.input
          field={@form[:ntrp_rating]}
          type="select"
          label="NTRP Rating"
          options={@ntrp_options}
          prompt="Select a rating"
        />
        <.input field={@form[:eligible_18_plus]} type="checkbox" label="18+ Eligible?" />
        <.input field={@form[:eligible_40_plus]} type="checkbox" label="40+ Eligible?" />
        <.input field={@form[:eligible_55_plus]} type="checkbox" label="55+ Eligible?" />

        <div class="mt-6 flex gap-4">
          <.button type="submit" variant="primary">
            {if @live_action == :new, do: "Create Player", else: "Save Changes"}
          </.button>
          <.button navigate={~p"/g/#{@current_group.slug}/players"}>Cancel</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    socket
    |> assign(:form, form)
    |> noreply()
  end

  def handle_event("save", %{"form" => params}, socket) do
    group_slug = socket.assigns.current_group.slug

    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, player} ->
        socket
        |> put_flash(:info, "Player saved.")
        |> push_navigate(to: ~p"/g/#{group_slug}/players/#{player.id}")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, form)
        |> noreply()
    end
  end
end
