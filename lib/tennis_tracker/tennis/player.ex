defmodule TennisTracker.Tennis.Player do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("players")
    repo(TennisTracker.Repo)
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :email, :string do
      public?(true)
    end

    attribute :phone_number, :string do
      public?(true)
    end

    attribute :ntrp_rating, :decimal do
      public?(true)
    end

    attribute :birth_year, :integer do
      public?(true)
    end

    timestamps()
  end

  validations do
    validate attribute_in(:ntrp_rating, [
               Decimal.new("2.5"),
               Decimal.new("3.0"),
               Decimal.new("3.5"),
               Decimal.new("4.0"),
               Decimal.new("4.5"),
               Decimal.new("5.0")
             ]) do
      where([present(:ntrp_rating)])
      message("must be a valid NTRP rating (2.5, 3.0, 3.5, 4.0, 4.5, or 5.0)")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :email, :phone_number, :ntrp_rating, :birth_year])
    end

    update :update do
      accept([:name, :email, :phone_number, :ntrp_rating, :birth_year])
    end
  end
end
