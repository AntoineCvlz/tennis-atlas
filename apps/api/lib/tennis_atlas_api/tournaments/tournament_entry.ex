defmodule TennisAtlasApi.Tournaments.TournamentEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournament_entries" do
    field :tour, Ecto.Enum, values: [:atp, :wta]
    field :seed, :integer

    field :entry_type, Ecto.Enum,
      values: [:direct, :qualifier, :wildcard, :lucky_loser],
      default: :direct

    field :status, Ecto.Enum, values: [:active, :withdrawn], default: :active

    belongs_to :tournament_edition, TennisAtlasApi.Tournaments.TournamentEdition
    belongs_to :player, TennisAtlasApi.Players.Player

    timestamps()
  end

  @required_fields [:tournament_edition_id, :player_id, :tour]
  @optional_fields [:seed, :entry_type, :status]

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:tournament_edition_id)
    |> foreign_key_constraint(:player_id)
    |> unique_constraint([:tournament_edition_id, :player_id])
  end
end
