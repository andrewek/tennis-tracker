defmodule TennisTrackerWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TennisTrackerWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint TennisTrackerWeb.Endpoint

      use TennisTrackerWeb, :verified_routes

      alias TennisTracker.Factory

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TennisTrackerWeb.ConnCase
      import TennisTracker.Factory, only: [setup_group: 1, setup_group_with_owner: 1]
    end
  end

  setup tags do
    TennisTracker.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Logs in a user, returning the authenticated connection.

  Accepts either an existing `%TennisTracker.Accounts.User{}` struct or
  a map of attributes used to create a new user (legacy usage).
  """
  def log_in_user(conn, user_or_attrs \\ %{})

  def log_in_user(conn, %TennisTracker.Accounts.User{} = user) do
    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end

  def log_in_user(conn, attrs) when is_map(attrs) do
    defaults = %{
      email: "test_#{System.unique_integer()}@example.com",
      password: "Password1!",
      password_confirmation: "Password1!"
    }

    {:ok, user} =
      Ash.create(
        TennisTracker.Accounts.User,
        Map.merge(defaults, attrs),
        action: :register_with_password,
        domain: TennisTracker.Accounts,
        authorize?: false
      )

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
