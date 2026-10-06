defmodule TennisAtlasApi.Venues.Venue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "venues" do
    field :name, :string
    field :city, :string
    field :country_code, :string
    field :latitude, :float
    field :longitude, :float

    has_many :courts, TennisAtlasApi.Venues.Court

    timestamps()
  end

  @required_fields [:name, :city, :country_code]
  @optional_fields [:latitude, :longitude]

  def changeset(venue, attrs) do
    venue
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
