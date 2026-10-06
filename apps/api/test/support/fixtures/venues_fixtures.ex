defmodule TennisAtlasApi.VenuesFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Venues.Venue

  def venue_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])

    defaults = %{name: "Test Venue #{n}", city: "Test City", country_code: "FRA"}

    {:ok, venue} =
      defaults
      |> Map.merge(attrs)
      |> then(&Venue.changeset(%Venue{}, &1))
      |> Repo.insert()

    venue
  end
end
