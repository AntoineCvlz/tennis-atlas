defmodule TennisAtlasApi.Matches.MatchTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Matches.Match
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Repo

  defp edition_fixture do
    tournament =
      %Tournament{}
      |> Tournament.changeset(%{
        name: "Test Tournament",
        slug: "test-tournament-#{System.unique_integer([:positive])}",
        category: :atp_250,
        surface: :hard
      })
      |> Repo.insert!()

    %TournamentEdition{}
    |> TournamentEdition.changeset(%{
      tournament_id: tournament.id,
      year: 2025,
      start_date: ~D[2025-01-01],
      end_date: ~D[2025-01-08]
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    edition = edition_fixture()

    changeset = Match.changeset(%Match{}, %{tournament_edition_id: edition.id, tour: :atp, round: :f})

    assert changeset.valid?
  end

  test "changeset requires tournament_edition_id, tour, round" do
    changeset = Match.changeset(%Match{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.tournament_edition_id == ["can't be blank"]
    assert errors.tour == ["can't be blank"]
    assert errors.round == ["can't be blank"]
  end

  test "defaults status to :scheduled and best_of to 3" do
    edition = edition_fixture()

    {:ok, match} =
      %Match{}
      |> Match.changeset(%{tournament_edition_id: edition.id, tour: :atp, round: :qf})
      |> Repo.insert()

    assert match.status == :scheduled
    assert match.best_of == 3
  end

  test "rejects an invalid round value" do
    edition = edition_fixture()

    changeset =
      Match.changeset(%Match{}, %{tournament_edition_id: edition.id, tour: :atp, round: :round_of_64})

    refute changeset.valid?
    assert %{round: ["is invalid"]} = errors_on(changeset)
  end
end
