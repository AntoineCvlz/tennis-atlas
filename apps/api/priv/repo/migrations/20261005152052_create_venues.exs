defmodule TennisAtlasApi.Repo.Migrations.CreateVenues do
  use Ecto.Migration

  def change do
    create table(:venues) do
      add :name, :string, null: false
      add :city, :string, null: false
      add :country_code, :string, null: false
      add :latitude, :float
      add :longitude, :float

      timestamps()
    end
  end
end
