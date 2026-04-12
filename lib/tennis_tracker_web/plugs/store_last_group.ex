defmodule TennisTrackerWeb.Plugs.StoreLastGroup do
  @moduledoc """
  Stores the current group slug in the session so it can be recalled by
  pages that lack a group URL parameter (e.g. account settings).
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%{params: %{"group_slug" => slug}} = conn, _opts) do
    put_session(conn, "last_group_slug", slug)
  end

  def call(conn, _opts), do: conn
end
