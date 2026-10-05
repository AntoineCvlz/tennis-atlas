defmodule TennisAtlasApi.Repo.Migrations.CreateRankings do
  use Ecto.Migration

  def change do
    create table(:rankings) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :ranking_type, :string, null: false
      add :position, :integer, null: false
      add :points, :integer, null: false
      add :as_of_date, :date, null: false

      timestamps()
    end

    create unique_index(:rankings, [:player_id, :ranking_type, :as_of_date])
  end
end
