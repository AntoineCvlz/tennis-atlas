defmodule TennisAtlasApi.Venues.CourtTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Venues.{Court, Venue}
  alias TennisAtlasApi.Repo

  defp venue_fixture do
    %Venue{}
    |> Venue.changeset(%{name: "Test Venue", city: "Test City", country_code: "FRA"})
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    venue = venue_fixture()

    changeset =
      Court.changeset(%Court{}, %{
        venue_id: venue.id,
        name: "Court Central",
        surface: :clay,
        capacity: 15_000,
        indoor: false
      })

    assert changeset.valid?
  end

  test "changeset requires venue_id, name, surface" do
    changeset = Court.changeset(%Court{}, %{})

    refute changeset.valid?

    assert %{venue_id: ["can't be blank"], name: ["can't be blank"], surface: ["can't be blank"]} =
             errors_on(changeset)
  end

  test "changeset rejects an invalid surface value" do
    venue = venue_fixture()

    changeset =
      Court.changeset(%Court{}, %{venue_id: venue.id, name: "Court 1", surface: :clay_tennis})

    refute changeset.valid?
    assert %{surface: ["is invalid"]} = errors_on(changeset)
  end
end
