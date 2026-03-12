defmodule TennisTrackerWeb.LiveHelpers do
  @moduledoc """
  Lightweight pipeline helpers for constructing LiveView callback return tuples.

  Import these to avoid constructing tuples inline — build the result as a
  pipeline and pipe into the appropriate helper at the end:

      socket
      |> assign(:foo, foo)
      |> assign(:bar, bar)
      |> noreply()
  """

  @doc "Wraps a socket in `{:ok, socket}` for `mount/3` returns."
  def ok(socket), do: {:ok, socket}

  @doc "Wraps a socket in `{:noreply, socket}` for `handle_*` callback returns."
  def noreply(socket), do: {:noreply, socket}

  @doc "Wraps a value in `{:error, value}`."
  def error(value), do: {:error, value}
end
