defmodule TennisTrackerWeb.Router do
  use TennisTrackerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TennisTrackerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
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
end
