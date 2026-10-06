defmodule TennisAtlasApi.Repo.Migrations.CreateSets do
  use Ecto.Migration

  def change do
    create table(:sets) do
      add :match_id, references(:matches, on_delete: :delete_all), null: false
      add :set_number, :integer, null: false
      add :player_a_games, :integer, null: false
      add :player_b_games, :integer, null: false
      add :tiebreak_a, :integer
      add :tiebreak_b, :integer

      timestamps()
    end

    create unique_index(:sets, [:match_id, :set_number])
  end
end
