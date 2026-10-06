defmodule TennisAtlasApi.Repo.Migrations.CreateMatches do
  use Ecto.Migration

  def change do
    create table(:matches) do
      add :tournament_edition_id, references(:tournament_editions, on_delete: :delete_all), null: false
      add :tour, :string, null: false
      add :round, :string, null: false
      add :player_a_id, references(:players, on_delete: :nilify_all)
      add :player_b_id, references(:players, on_delete: :nilify_all)
      add :court_id, references(:courts, on_delete: :nilify_all)
      add :scheduled_at, :utc_datetime
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :status, :string, null: false, default: "scheduled"
      add :winner_id, references(:players, on_delete: :nilify_all)
      add :best_of, :integer, null: false, default: 3

      timestamps()
    end

    create index(:matches, [:tournament_edition_id])
    create index(:matches, [:player_a_id])
    create index(:matches, [:player_b_id])
    create index(:matches, [:status])
  end
end
