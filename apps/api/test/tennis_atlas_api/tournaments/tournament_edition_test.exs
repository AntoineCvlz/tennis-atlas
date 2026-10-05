defmodule TennisAtlasApi.Tournaments.TournamentEditionTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Repo

  defp tournament_fixture do
    %Tournament{}
    |> Tournament.changeset(%{
      name: "Test Tournament",
      slug: "test-tournament-#{System.unique_integer([:positive])}",
      category: :atp_250,
      surface: :hard
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    tournament = tournament_fixture()

    changeset =
      TournamentEdition.changeset(%TournamentEdition{}, %{
        tournament_id: tournament.id,
        year: 2025,
        start_date: ~D[2025-05-25],
        end_date: ~D[2025-06-08]
      })

    assert changeset.valid?
  end

  test "changeset requires tournament_id, year, start_date, end_date" do
    changeset = TournamentEdition.changeset(%TournamentEdition{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.tournament_id == ["can't be blank"]
    assert errors.year == ["can't be blank"]
    assert errors.start_date == ["can't be blank"]
    assert errors.end_date == ["can't be blank"]
  end

  test "defaults status to :upcoming" do
    tournament = tournament_fixture()

    {:ok, edition} =
      %TournamentEdition{}
      |> TournamentEdition.changeset(%{
        tournament_id: tournament.id,
        year: 2025,
        start_date: ~D[2025-05-25],
        end_date: ~D[2025-06-08]
      })
      |> Repo.insert()

    assert edition.status == :upcoming
  end

  test "(tournament_id, year) must be unique" do
    tournament = tournament_fixture()

    attrs = %{
      tournament_id: tournament.id,
      year: 2025,
      start_date: ~D[2025-05-25],
      end_date: ~D[2025-06-08]
    }

    {:ok, _edition} = TournamentEdition.changeset(%TournamentEdition{}, attrs) |> Repo.insert()
    {:error, changeset} = TournamentEdition.changeset(%TournamentEdition{}, attrs) |> Repo.insert()

    assert %{tournament_id: ["has already been taken"]} = errors_on(changeset)
  end
end
