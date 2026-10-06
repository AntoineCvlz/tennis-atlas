defmodule TennisAtlasApi.Tournaments.TournamentEdition do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournament_editions" do
    field :year, :integer
    field :start_date, :date
    field :end_date, :date

    field :status, Ecto.Enum,
      values: [:upcoming, :ongoing, :completed, :cancelled],
      default: :upcoming

    belongs_to :tournament, TennisAtlasApi.Tournaments.Tournament

    timestamps()
  end

  @required_fields [:tournament_id, :year, :start_date, :end_date]
  @optional_fields [:status]

  def changeset(tournament_edition, attrs) do
    tournament_edition
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:tournament_id)
    |> unique_constraint([:tournament_id, :year])
  end
end
