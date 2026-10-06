defmodule TennisAtlasApi.Players.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :first_name, :string
    field :last_name, :string
    field :slug, :string
    field :country_code, :string
    field :birth_date, :date
    field :hand, Ecto.Enum, values: [:left, :right]
    field :height_cm, :integer
    field :current_ranking, :integer
    field :current_ranking_points, :integer

    timestamps()
  end

  @required_fields [:first_name, :last_name, :slug, :country_code]
  @optional_fields [:birth_date, :hand, :height_cm, :current_ranking, :current_ranking_points]

  def changeset(player, attrs) do
    player
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:slug)
  end
end
