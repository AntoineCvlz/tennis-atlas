defmodule TennisAtlasApi.Tournaments.Tournament do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournaments" do
    field :name, :string
    field :slug, :string

    field :category, Ecto.Enum,
      values: [:grand_slam, :masters_1000, :atp_500, :atp_250, :wta_1000, :wta_500, :wta_250]

    field :surface, Ecto.Enum, values: [:clay, :grass, :hard, :indoor]
    field :description, :string
    field :logo_url, :string
    field :hero_image_url, :string

    belongs_to :venue, TennisAtlasApi.Venues.Venue
    has_many :editions, TennisAtlasApi.Tournaments.TournamentEdition

    timestamps()
  end

  @required_fields [:name, :slug, :category, :surface]
  @optional_fields [:venue_id, :description, :logo_url, :hero_image_url]

  def changeset(tournament, attrs) do
    tournament
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:venue_id)
  end
end
