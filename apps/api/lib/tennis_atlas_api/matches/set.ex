defmodule TennisAtlasApi.Matches.Set do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sets" do
    field :set_number, :integer
    field :player_a_games, :integer
    field :player_b_games, :integer
    field :tiebreak_a, :integer
    field :tiebreak_b, :integer

    belongs_to :match, TennisAtlasApi.Matches.Match

    timestamps()
  end

  @required_fields [:match_id, :set_number, :player_a_games, :player_b_games]
  @optional_fields [:tiebreak_a, :tiebreak_b]

  def changeset(set, attrs) do
    set
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:match_id)
    |> unique_constraint([:match_id, :set_number])
  end
end
