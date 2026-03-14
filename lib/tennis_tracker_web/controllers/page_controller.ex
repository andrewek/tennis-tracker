defmodule TennisTrackerWeb.PageController do
  use TennisTrackerWeb, :controller

  plug :ensure_authenticated

  def home(conn, _params) do
    render(conn, :home, current_user: conn.assigns[:current_user])
  end

  defp ensure_authenticated(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> redirect(to: ~p"/sign-in")
      |> halt()
    end
  end
end
