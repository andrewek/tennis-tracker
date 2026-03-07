defmodule TennisTrackerWeb.PageController do
  use TennisTrackerWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
