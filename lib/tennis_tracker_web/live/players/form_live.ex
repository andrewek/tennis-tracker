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
    |> ok()
  end

  def handle_params(params, _url, socket) do
    form =
      case socket.assigns.live_action do
        :new ->
          AshPhoenix.Form.for_create(Player, :create, domain: Tennis) |> to_form()

        :edit ->
          player = Tennis.get_player!(params["id"])
          AshPhoenix.Form.for_update(player, :update, domain: Tennis) |> to_form()
      end

    socket
    |> assign(:form, form)
    |> noreply()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {if @live_action == :new, do: "New Player", else: "Edit Player"}
      </.header>

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
          <.button navigate={~p"/players"}>Cancel</.button>
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
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, player} ->
        socket
        |> put_flash(:info, "Player saved.")
        |> push_navigate(to: ~p"/players/#{player.id}")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, form)
        |> noreply()
    end
  end
end
