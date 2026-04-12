defmodule TennisTrackerWeb.RedirectController do
  use TennisTrackerWeb, :controller

  def account_settings(conn, _params) do
    redirect(conn, to: ~p"/account/settings/profile")
  end
end
