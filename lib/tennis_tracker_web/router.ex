defmodule TennisTrackerWeb.Router do
  use TennisTrackerWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TennisTrackerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  pipeline :group_member do
    plug TennisTrackerWeb.Plugs.RequireGroupMember
  end

  scope "/", TennisTrackerWeb do
    pipe_through :browser

    # NOTE: /groups must be defined BEFORE /g/:group_slug to avoid slug conflict
    ash_authentication_live_session :groups_routes,
      on_mount: [{TennisTrackerWeb.LiveUserAuth, :live_user_required}] do
      live "/", HomeLive, :index
      live "/groups", GroupsLive.Index, :index
    end

    scope "/g/:group_slug", as: :group do
      pipe_through :group_member

      get "/players/export.csv", PlayerCSVController, :export
      get "/teams/:team_id/calendar.ics", TeamCalendarController, :export
    end

    ash_authentication_live_session :group_scoped_routes,
      on_mount: [
        {TennisTrackerWeb.LiveUserAuth, :live_user_required},
        {TennisTrackerWeb.GroupMountHook, :require_group_member}
      ] do
      live "/g/:group_slug", GroupHomeLive, :index
      live "/g/:group_slug/teams", Teams.IndexLive, :index
      live "/g/:group_slug/teams/:id", Teams.ShowLive, :show
      live "/g/:group_slug/teams/:id/edit", Teams.EditLive, :edit

      live "/g/:group_slug/players", Players.IndexLive, :index
      live "/g/:group_slug/players/new", Players.FormLive, :new
      live "/g/:group_slug/players/import", Players.ImportLive, :import
      live "/g/:group_slug/players/:id", Players.ShowLive, :show
      live "/g/:group_slug/players/:id/edit", Players.FormLive, :edit

      live "/g/:group_slug/matches/:id", Matches.ShowLive, :show
      live "/g/:group_slug/matches/:id/edit", Matches.EditLive, :edit
      live "/g/:group_slug/matches/:id/lineup-edit", Matches.LineupEditLive, :edit

      live "/g/:group_slug/roster-planner", RosterPlannerLive, :index
      live "/g/:group_slug/roster-planner/:team_type_id/:season_year", RosterPlannerLive, :board

      live "/g/:group_slug/settings/locations", Settings.Locations.IndexLive, :index
      live "/g/:group_slug/settings/locations/new", Settings.Locations.FormLive, :new
      live "/g/:group_slug/settings/locations/:id/edit", Settings.Locations.FormLive, :edit

      live "/g/:group_slug/settings/tags", Settings.TagsLive, :index

      live "/g/:group_slug/settings/season-rules", Settings.SeasonRules.IndexLive, :index
      live "/g/:group_slug/settings/season-rules/new", Settings.SeasonRules.FormLive, :new
      live "/g/:group_slug/settings/season-rules/:id/edit", Settings.SeasonRules.FormLive, :edit
    end

    auth_routes AuthController, TennisTracker.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route auth_routes_prefix: "/auth",
                  on_mount: [{TennisTrackerWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    TennisTrackerWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tennis_tracker, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TennisTrackerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  import AshAdmin.Router

  scope "/admin" do
    pipe_through :browser

    ash_admin "/", on_mount: [{TennisTrackerWeb.LiveUserAuth, :admin_only}]
  end
end
