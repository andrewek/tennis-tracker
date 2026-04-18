defmodule TennisTracker.Accounts.User do
  @moduledoc false

  use Ash.Resource,
    otp_app: :tennis_tracker,
    domain: TennisTracker.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication, AshAdmin.Resource]

  postgres do
    table("users")
    repo(TennisTracker.Repo)
  end

  policies do
    bypass(AshAuthentication.Checks.AshAuthenticationInteraction) do
      authorize_if(always())
    end

    bypass actor_attribute_equals(:role, :admin) do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(actor_present())
    end

    policy action(:update_email) do
      authorize_if(expr(id == ^actor(:id)))
    end

    policy action(:update_profile) do
      authorize_if(expr(id == ^actor(:id)))
    end

    policy action(:change_password) do
      authorize_if(expr(id == ^actor(:id)))
    end
  end

  admin do
  end

  authentication do
    strategies do
      password :password do
        identity_field :email
        hashed_password_field :hashed_password
      end
    end

    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource TennisTracker.Accounts.Token
      signing_secret TennisTracker.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :email, :ci_string do
      allow_nil?(false)
      public?(true)
    end

    attribute :hashed_password, :string do
      allow_nil?(true)
      sensitive?(true)
    end

    attribute :name, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :role, :atom do
      constraints(one_of: [:admin, :member])
      default(:member)
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    defaults([:read])

    read :get_by_subject do
      description("Get a user by the subject claim in a JWT")
      argument(:subject, :string, allow_nil?: false)
      get?(true)
      prepare(AshAuthentication.Preparations.FilterBySubject)
    end

    update :update_profile do
      accept([:name])
    end

    update :update_email do
      accept([:email])
      validate(match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/))
    end

    update :change_password do
      accept([])
      require_atomic?(false)
      argument(:current_password, :string, sensitive?: true, allow_nil?: false)
      argument(:password, :string, sensitive?: true, allow_nil?: false)
      argument(:password_confirmation, :string, sensitive?: true, allow_nil?: false)

      validate(confirm(:password, :password_confirmation))

      validate(
        {AshAuthentication.Strategy.Password.PasswordValidation,
         strategy_name: :password, password_argument: :current_password}
      )

      change({AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password})
    end

    update :update_role do
      accept([:role])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_email, [:email])
  end
end
