defmodule TennisTrackerWeb.Settings.SeasonRules.FormLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.SeasonRules

  def mount(_params, _session, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    if socket.assigns.current_group_role in [:owner, :admin] do
      tag_categories =
        Tennis.list_tag_categories!(load: [:tags], tenant: group_id, actor: current_user)

      socket
      |> assign(:form, nil)
      |> assign(:season_rules_id, nil)
      |> assign(:tag_categories, tag_categories)
      |> assign(:selected_tag_ids, [])
      |> assign(:team_types, [])
      |> ok()
    else
      socket
      |> put_flash(:error, "You don't have permission to access group settings.")
      |> push_navigate(to: ~p"/g/#{socket.assigns.current_group.slug}")
      |> ok()
    end
  end

  def handle_params(params, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    case socket.assigns.live_action do
      :new ->
        team_types = Tennis.list_team_types!(tenant: group_id, actor: current_user)

        form =
          AshPhoenix.Form.for_create(SeasonRules, :create,
            domain: Tennis,
            actor: current_user,
            tenant: group_id
          )
          |> to_form()

        socket
        |> assign(:form, form)
        |> assign(:season_rules_id, nil)
        |> assign(:selected_tag_ids, [])
        |> assign(:team_types, team_types)
        |> noreply()

      :edit ->
        sr =
          Tennis.get_season_rules!(params["id"],
            tenant: group_id,
            actor: current_user,
            load: [:default_tags]
          )

        form =
          AshPhoenix.Form.for_update(sr, :update,
            domain: Tennis,
            actor: current_user,
            tenant: group_id
          )
          |> to_form()

        socket
        |> assign(:form, form)
        |> assign(:season_rules_id, sr.id)
        |> assign(:selected_tag_ids, Enum.map(sr.default_tags, & &1.id))
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
      <.page_header
        title={if @live_action == :new, do: "New Season Rules", else: "Edit Season Rules"}
        back_href={~p"/g/#{@current_group.slug}/settings/season-rules"}
        back_label="Season Rules"
      />

      <div class="max-w-lg">
        <.form :if={@form} for={@form} phx-change="validate" phx-submit="save">
          <%= if @live_action == :new do %>
            <.input
              field={@form[:team_type_id]}
              type="select"
              label="Team Type"
              options={Enum.map(@team_types, &{&1.name, &1.id})}
              prompt="Select a team type"
              required
            />
            <.input field={@form[:season_year]} type="number" label="Season Year" required />
          <% end %>
          <.input field={@form[:min_roster]} type="number" label="Minimum Roster Size (optional)" />
          <.input field={@form[:max_roster]} type="number" label="Maximum Roster Size (optional)" />
          <.input
            field={@form[:on_level_min_pct]}
            type="number"
            label="On-Level Minimum % (optional)"
          />

          <%!-- Default tag picker grouped by category --%>
          <div :if={@tag_categories != []} class="mt-4 space-y-3">
            <p class="text-sm font-medium">Default Tags for Roster Planner</p>
            <p class="text-xs text-base-content/60">
              These tags will be pre-selected when opening the roster planner for this context.
            </p>
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

          <div class="mt-6">
            <.button type="submit">
              {if @live_action == :new, do: "Create Season Rules", else: "Save Changes"}
            </.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    socket |> assign(:form, form) |> noreply()
  end

  def handle_event("save", params, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    group_slug = socket.assigns.current_group.slug
    form_params = params["form"] || %{}
    submitted_tag_ids = params["tag_ids"] || []

    submitted_tag_ids =
      if is_list(submitted_tag_ids), do: submitted_tag_ids, else: [submitted_tag_ids]

    form_params =
      if socket.assigns.live_action == :new do
        Map.put(form_params, "group_id", group_id)
      else
        form_params
      end

    case AshPhoenix.Form.submit(socket.assigns.form, params: form_params) do
      {:ok, season_rules} ->
        flash =
          case Tennis.sync_season_rules_default_tags(season_rules.id, submitted_tag_ids,
                 tenant: group_id,
                 actor: current_user
               ) do
            :ok -> {:info, "Season rules saved."}
            {:error, _} -> {:error, "Season rules saved, but default tags could not be updated."}
          end

        socket
        |> put_flash(elem(flash, 0), elem(flash, 1))
        |> push_navigate(to: ~p"/g/#{group_slug}/settings/season-rules")
        |> noreply()

      {:error, form} ->
        socket |> assign(:form, form) |> noreply()
    end
  end
end
