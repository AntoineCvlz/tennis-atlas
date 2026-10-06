defmodule TennisAtlasApi.Players.Ranking do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rankings" do
    field :ranking_type, Ecto.Enum, values: [:atp, :wta]
    field :position, :integer
    field :points, :integer
    field :as_of_date, :date

    belongs_to :player, TennisAtlasApi.Players.Player

    timestamps()
  end

  @required_fields [:player_id, :ranking_type, :position, :points, :as_of_date]

  def changeset(ranking, attrs) do
    ranking
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:player_id)
    |> unique_constraint([:player_id, :ranking_type, :as_of_date])
  end
end
