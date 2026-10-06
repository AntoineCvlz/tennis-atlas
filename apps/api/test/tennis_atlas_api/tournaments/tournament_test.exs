defmodule TennisAtlasApi.Tournaments.TournamentTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments.Tournament
  alias TennisAtlasApi.Repo

  @valid_attrs %{
    name: "Roland Garros Fictif",
    slug: "roland-garros-fictif",
    category: :grand_slam,
    surface: :clay
  }

  test "changeset with valid attributes is valid" do
    changeset = Tournament.changeset(%Tournament{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset requires name, slug, category, surface" do
    changeset = Tournament.changeset(%Tournament{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.name == ["can't be blank"]
    assert errors.slug == ["can't be blank"]
    assert errors.category == ["can't be blank"]
    assert errors.surface == ["can't be blank"]
  end

  test "slug must be unique" do
    {:ok, _tournament} = Tournament.changeset(%Tournament{}, @valid_attrs) |> Repo.insert()

    {:error, changeset} =
      %Tournament{}
      |> Tournament.changeset(@valid_attrs)
      |> Repo.insert()

    assert %{slug: ["has already been taken"]} = errors_on(changeset)
  end
end
