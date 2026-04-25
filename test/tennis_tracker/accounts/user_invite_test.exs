defmodule TennisTracker.Accounts.UserInviteTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Accounts
  alias TennisTracker.Accounts.User

  describe ":invite action" do
    test "is denied when called with a real actor and authorize?: true" do
      actor =
        Ash.create!(
          User,
          %{email: "actor#{System.unique_integer()}@example.com", password: "S3cure!Password123"},
          action: :invite,
          domain: Accounts,
          authorize?: false
        )

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(
                 User,
                 %{
                   email: "target#{System.unique_integer()}@example.com",
                   password: "S3cure!Password123"
                 },
                 action: :invite,
                 domain: Accounts,
                 actor: actor
               )
    end

    test "creates user with hashed password" do
      email = "invite#{System.unique_integer()}@example.com"
      password = "S3cure!Password123"

      {:ok, user} =
        Ash.create(User, %{email: email, password: password},
          action: :invite,
          domain: Accounts,
          authorize?: false
        )

      assert to_string(user.email) == email
      assert user.hashed_password != nil
      refute user.hashed_password == password
    end

    test "sets role to :member" do
      email = "invite#{System.unique_integer()}@example.com"

      {:ok, user} =
        Ash.create(User, %{email: email, password: "S3cure!Password123"},
          action: :invite,
          domain: Accounts,
          authorize?: false
        )

      assert user.role == :member
    end

    test "fails on duplicate email" do
      email = "invite#{System.unique_integer()}@example.com"

      {:ok, _} =
        Ash.create(User, %{email: email, password: "S3cure!Password123"},
          action: :invite,
          domain: Accounts,
          authorize?: false
        )

      assert {:error, _} =
               Ash.create(User, %{email: email, password: "AnotherPass1!"},
                 action: :invite,
                 domain: Accounts,
                 authorize?: false
               )
    end
  end
end
