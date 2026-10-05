defmodule TennisAtlasApi.Repo.Migrations.CreateTournamentEditions do
  use Ecto.Migration

  def change do
    create table(:tournament_editions) do
      add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
      add :year, :integer, null: false
      add :start_date, :date, null: false
      add :end_date, :date, null: false
      add :status, :string, null: false, default: "upcoming"

      timestamps()
    end

    create unique_index(:tournament_editions, [:tournament_id, :year])
  end
end
