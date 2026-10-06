defmodule TennisAtlasApi.Venues.VenueTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Venues.Venue

  test "changeset with valid attributes is valid" do
    changeset =
      Venue.changeset(%Venue{}, %{
        name: "Stade Fictif de Paris",
        city: "Paris",
        country_code: "FRA",
        latitude: 48.8472,
        longitude: 2.2519
      })

    assert changeset.valid?
  end

  test "changeset requires name, city, country_code" do
    changeset = Venue.changeset(%Venue{}, %{})

    refute changeset.valid?

    assert %{name: ["can't be blank"], city: ["can't be blank"], country_code: ["can't be blank"]} =
             errors_on(changeset)
  end
end
