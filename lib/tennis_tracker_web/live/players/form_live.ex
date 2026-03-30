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
    |> assign(:tag_categories, [])
    |> assign(:selected_tag_ids, [])
    |> ok()
  end

  def handle_params(params, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    tag_categories =
      Tennis.list_tag_categories!(load: [:tags], tenant: group_id, actor: current_user)

    {form, player_id, selected_tag_ids} =
      case socket.assigns.live_action do
        :new ->
          form =
            AshPhoenix.Form.for_create(Player, :create,
              domain: Tennis,
              actor: current_user,
              tenant: group_id
            )
            |> to_form()

          {form, nil, []}

        :edit ->
          player =
            Tennis.get_player!(params["id"],
              tenant: group_id,
              actor: current_user,
              load: [:tags]
            )

          form =
            AshPhoenix.Form.for_update(player, :update,
              domain: Tennis,
              actor: current_user,
              tenant: group_id
            )
            |> to_form()

          {form, player.id, Enum.map(player.tags, & &1.id)}
      end

    socket
    |> assign(:form, form)
    |> assign(:player_id, player_id)
    |> assign(:tag_categories, tag_categories)
    |> assign(:selected_tag_ids, selected_tag_ids)
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

        <%!-- Tag checkboxes grouped by category --%>
        <div :if={@tag_categories != []} class="mt-4 space-y-3">
          <p class="text-sm font-medium">Tags</p>
          <%= for category <- @tag_categories do %>
            <div>
              <p class="text-xs text-base-content/60 mb-1">{category.name}</p>
              <div class="flex flex-wrap gap-2">
                <%= for tag <- category.tags do %>
                  <label class="flex items-center gap-1.5 cursor-pointer">
                    <input
                      type="checkbox"
                      name="tag_ids[]"
                      value={tag.id}
                      checked={tag.id in @selected_tag_ids}
                      class="checkbox checkbox-sm"
                    />
                    <span class="text-sm">{tag.name}</span>
                  </label>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

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

  def handle_event("save", params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    group_slug = socket.assigns.current_group.slug
    form_params = params["form"] || %{}
    submitted_tag_ids = params["tag_ids"] || []

    submitted_tag_ids =
      if is_list(submitted_tag_ids), do: submitted_tag_ids, else: [submitted_tag_ids]

    case AshPhoenix.Form.submit(socket.assigns.form, params: form_params) do
      {:ok, player} ->
        current_tag_ids = socket.assigns.selected_tag_ids
        added = submitted_tag_ids -- current_tag_ids
        removed = current_tag_ids -- submitted_tag_ids

        tag_errors =
          (Enum.map(
             added,
             &Tennis.add_player_tag(player.id, &1, tenant: group_id, actor: current_user)
           ) ++
             Enum.map(
               removed,
               &Tennis.remove_player_tag(player.id, &1, tenant: group_id, actor: current_user)
             ))
          |> Enum.filter(&match?({:error, _}, &1))

        socket =
          if tag_errors == [] do
            put_flash(socket, :info, "Player saved.")
          else
            put_flash(socket, :error, "Player saved, but some tag changes could not be applied.")
          end

        socket
        |> push_navigate(to: ~p"/g/#{group_slug}/players/#{player.id}")
        |> noreply()

      {:error, form} ->
        socket
        |> assign(:form, form)
        |> noreply()
    end
  end
end
