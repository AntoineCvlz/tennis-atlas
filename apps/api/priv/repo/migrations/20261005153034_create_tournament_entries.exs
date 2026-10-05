defmodule TennisAtlasApi.Repo.Migrations.CreateTournamentEntries do
  use Ecto.Migration

  def change do
    create table(:tournament_entries) do
      add :tournament_edition_id, references(:tournament_editions, on_delete: :delete_all), null: false
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :tour, :string, null: false
      add :seed, :integer
      add :entry_type, :string, null: false, default: "direct"
      add :status, :string, null: false, default: "active"

      timestamps()
    end

    create unique_index(:tournament_entries, [:tournament_edition_id, :player_id])
    create index(:tournament_entries, [:player_id])
  end
end
