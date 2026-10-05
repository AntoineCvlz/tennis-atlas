defmodule TennisAtlasApi.Matches.SetTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Matches.{Match, Set}
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Repo

  defp match_fixture do
    tournament =
      %Tournament{}
      |> Tournament.changeset(%{
        name: "Test Tournament",
        slug: "test-tournament-#{System.unique_integer([:positive])}",
        category: :atp_250,
        surface: :hard
      })
      |> Repo.insert!()

    edition =
      %TournamentEdition{}
      |> TournamentEdition.changeset(%{
        tournament_id: tournament.id,
        year: 2025,
        start_date: ~D[2025-01-01],
        end_date: ~D[2025-01-08]
      })
      |> Repo.insert!()

    %Match{}
    |> Match.changeset(%{tournament_edition_id: edition.id, tour: :atp, round: :f})
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    match = match_fixture()

    changeset =
      Set.changeset(%Set{}, %{match_id: match.id, set_number: 1, player_a_games: 6, player_b_games: 4})

    assert changeset.valid?
  end

  test "changeset requires match_id, set_number, player_a_games, player_b_games" do
    changeset = Set.changeset(%Set{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.match_id == ["can't be blank"]
    assert errors.set_number == ["can't be blank"]
    assert errors.player_a_games == ["can't be blank"]
    assert errors.player_b_games == ["can't be blank"]
  end

  test "(match_id, set_number) must be unique" do
    match = match_fixture()
    attrs = %{match_id: match.id, set_number: 1, player_a_games: 6, player_b_games: 4}

    {:ok, _set} = Set.changeset(%Set{}, attrs) |> Repo.insert()
    {:error, changeset} = Set.changeset(%Set{}, attrs) |> Repo.insert()

    assert %{match_id: ["has already been taken"]} = errors_on(changeset)
  end
end
