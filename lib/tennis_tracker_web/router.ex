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

  scope "/", TennisTrackerWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes do
      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {TennisTrackerWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {TennisTrackerWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {TennisTrackerWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", TennisTrackerWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/players", Players.IndexLive, :index
    live "/players/new", Players.FormLive, :new
    live "/players/import", Players.ImportLive, :import
    get "/players/export.csv", PlayerCSVController, :export
    live "/players/:id", Players.ShowLive, :show
    live "/players/:id/edit", Players.FormLive, :edit

    live "/roster-planner", RosterPlannerLive, :index
    live "/roster-planner/:team_type_id/:season_year", RosterPlannerLive, :board
    auth_routes AuthController, TennisTracker.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route auth_routes_prefix: "/auth",
                  on_mount: [{TennisTrackerWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    TennisTrackerWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]
  end

  # Other scopes may use custom stacks.
  # scope "/api", TennisTrackerWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tennis_tracker, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TennisTrackerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:tennis_tracker, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
