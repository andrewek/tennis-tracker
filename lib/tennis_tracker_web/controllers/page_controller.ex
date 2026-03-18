defmodule TennisTrackerWeb.PageController do
  use TennisTrackerWeb, :controller

  alias TennisTracker.Groups

  plug :ensure_authenticated

  def home(conn, _params) do
    current_user = conn.assigns[:current_user]

    case Groups.list_groups_for_user(current_user.id, actor: current_user) do
      {:ok, [single_group]} ->
        redirect(conn, to: ~p"/g/#{single_group.slug}/teams")

      _ ->
        redirect(conn, to: ~p"/groups")
    end
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
