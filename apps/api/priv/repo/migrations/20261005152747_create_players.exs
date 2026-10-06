defmodule TennisAtlasApi.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :slug, :string, null: false
      add :country_code, :string, null: false
      add :birth_date, :date
      add :hand, :string
      add :height_cm, :integer
      add :current_ranking, :integer
      add :current_ranking_points, :integer

      timestamps()
    end

    create unique_index(:players, [:slug])
  end
end
