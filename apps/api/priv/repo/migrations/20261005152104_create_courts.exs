defmodule TennisAtlasApi.Repo.Migrations.CreateCourts do
  use Ecto.Migration

  def change do
    create table(:courts) do
      add :venue_id, references(:venues, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :surface, :string, null: false
      add :capacity, :integer
      add :indoor, :boolean, null: false, default: false

      timestamps()
    end

    create index(:courts, [:venue_id])
  end
end
