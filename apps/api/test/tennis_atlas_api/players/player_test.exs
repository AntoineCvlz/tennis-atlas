defmodule TennisAtlasApi.Players.PlayerTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Players.Player
  alias TennisAtlasApi.Repo

  @valid_attrs %{
    first_name: "Mateo",
    last_name: "Rivera",
    slug: "mateo-rivera",
    country_code: "ESP"
  }

  test "changeset with valid attributes is valid" do
    changeset = Player.changeset(%Player{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset requires first_name, last_name, slug, country_code" do
    changeset = Player.changeset(%Player{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.first_name == ["can't be blank"]
    assert errors.last_name == ["can't be blank"]
    assert errors.slug == ["can't be blank"]
    assert errors.country_code == ["can't be blank"]
  end

  test "slug must be unique" do
    {:ok, _player} = Player.changeset(%Player{}, @valid_attrs) |> Repo.insert()

    {:error, changeset} = Player.changeset(%Player{}, @valid_attrs) |> Repo.insert()

    assert %{slug: ["has already been taken"]} = errors_on(changeset)
  end

  test "rejects an invalid hand value" do
    changeset = Player.changeset(%Player{}, Map.put(@valid_attrs, :hand, :ambidextrous))

    refute changeset.valid?
    assert %{hand: ["is invalid"]} = errors_on(changeset)
  end
end
