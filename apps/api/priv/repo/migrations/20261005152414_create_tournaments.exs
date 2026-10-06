defmodule TennisAtlasApi.Repo.Migrations.CreateTournaments do
  use Ecto.Migration

  def change do
    create table(:tournaments) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :category, :string, null: false
      add :surface, :string, null: false
      add :venue_id, references(:venues, on_delete: :nilify_all)
      add :description, :text
      add :logo_url, :string
      add :hero_image_url, :string

      timestamps()
    end

    create unique_index(:tournaments, [:slug])
    create index(:tournaments, [:venue_id])
  end
end
