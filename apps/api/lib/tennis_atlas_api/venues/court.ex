defmodule TennisAtlasApi.Venues.Court do
  use Ecto.Schema
  import Ecto.Changeset

  schema "courts" do
    field :name, :string
    field :surface, Ecto.Enum, values: [:clay, :grass, :hard, :indoor]
    field :capacity, :integer
    field :indoor, :boolean, default: false

    belongs_to :venue, TennisAtlasApi.Venues.Venue

    timestamps()
  end

  @required_fields [:venue_id, :name, :surface]
  @optional_fields [:capacity, :indoor]

  def changeset(court, attrs) do
    court
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:venue_id)
  end
end
