defmodule TennisAtlasApi.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matches" do
    field :tour, Ecto.Enum, values: [:atp, :wta]
    field :round, Ecto.Enum, values: [:r128, :r64, :r32, :r16, :qf, :sf, :f]
    field :scheduled_at, :utc_datetime
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    field :status, Ecto.Enum,
      values: [:scheduled, :live, :finished, :retired, :walkover, :cancelled],
      default: :scheduled

    field :best_of, :integer, default: 3

    belongs_to :tournament_edition, TennisAtlasApi.Tournaments.TournamentEdition
    belongs_to :player_a, TennisAtlasApi.Players.Player
    belongs_to :player_b, TennisAtlasApi.Players.Player
    belongs_to :winner, TennisAtlasApi.Players.Player
    belongs_to :court, TennisAtlasApi.Venues.Court

    has_many :sets, TennisAtlasApi.Matches.Set

    timestamps()
  end

  @required_fields [:tournament_edition_id, :tour, :round]
  @optional_fields [
    :player_a_id,
    :player_b_id,
    :court_id,
    :scheduled_at,
    :started_at,
    :finished_at,
    :status,
    :winner_id,
    :best_of
  ]

  def changeset(match, attrs) do
    match
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:tournament_edition_id)
    |> foreign_key_constraint(:player_a_id)
    |> foreign_key_constraint(:player_b_id)
    |> foreign_key_constraint(:court_id)
    |> foreign_key_constraint(:winner_id)
  end
end
