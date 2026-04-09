defmodule TennisTracker.Accounts.UserNameTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Accounts

  # ---------------------------------------------------------------------------
  # 8.5 User.name attribute
  # ---------------------------------------------------------------------------

  describe "User.name" do
    test "name is nil by default" do
      user = Factory.user()
      assert is_nil(user.name)
    end

    test "name can be set via update_profile" do
      user = Factory.user()

      {:ok, updated} =
        Ash.update(user, %{name: "Alice Smith"},
          action: :update_profile,
          domain: Accounts,
          authorize?: false
        )

      assert updated.name == "Alice Smith"
    end

    test "name can be updated to nil" do
      user = Factory.user()

      {:ok, named} =
        Ash.update(user, %{name: "Alice"},
          action: :update_profile,
          domain: Accounts,
          authorize?: false
        )

      {:ok, cleared} =
        Ash.update(named, %{name: nil},
          action: :update_profile,
          domain: Accounts,
          authorize?: false
        )

      assert is_nil(cleared.name)
    end
  end
end
