defmodule TennisAtlasApi.Tournaments.TournamentEntryTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition, TournamentEntry}
  alias TennisAtlasApi.Players.Player
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

  defp player_fixture do
    %Player{}
    |> Player.changeset(%{
      first_name: "Test",
      last_name: "Player",
      slug: "test-player-#{System.unique_integer([:positive])}",
      country_code: "FRA"
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    edition = edition_fixture()
    player = player_fixture()

    changeset =
      TournamentEntry.changeset(%TournamentEntry{}, %{
        tournament_edition_id: edition.id,
        player_id: player.id,
        tour: :atp,
        seed: 1
      })

    assert changeset.valid?
  end

  test "changeset requires tournament_edition_id, player_id, tour" do
    changeset = TournamentEntry.changeset(%TournamentEntry{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.tournament_edition_id == ["can't be blank"]
    assert errors.player_id == ["can't be blank"]
    assert errors.tour == ["can't be blank"]
  end

  test "(tournament_edition_id, player_id) must be unique" do
    edition = edition_fixture()
    player = player_fixture()
    attrs = %{tournament_edition_id: edition.id, player_id: player.id, tour: :atp}

    {:ok, _entry} = TournamentEntry.changeset(%TournamentEntry{}, attrs) |> Repo.insert()
    {:error, changeset} = TournamentEntry.changeset(%TournamentEntry{}, attrs) |> Repo.insert()

    assert %{tournament_edition_id: ["has already been taken"]} = errors_on(changeset)
  end

  test "defaults entry_type to :direct and status to :active" do
    edition = edition_fixture()
    player = player_fixture()

    {:ok, entry} =
      %TournamentEntry{}
      |> TournamentEntry.changeset(%{
        tournament_edition_id: edition.id,
        player_id: player.id,
        tour: :wta
      })
      |> Repo.insert()

    assert entry.entry_type == :direct
    assert entry.status == :active
  end
end
