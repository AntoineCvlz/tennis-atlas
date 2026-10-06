defmodule TennisAtlasApi.TournamentsFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}

  def tournament_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])

    defaults = %{
      name: "Test Tournament #{n}",
      slug: "test-tournament-#{n}",
      category: :atp_500,
      surface: :hard
    }

    {:ok, tournament} =
      defaults
      |> Map.merge(attrs)
      |> then(&Tournament.changeset(%Tournament{}, &1))
      |> Repo.insert()

    tournament
  end

  def tournament_edition_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    tournament_id = Map.get_lazy(attrs, :tournament_id, fn -> tournament_fixture(%{}).id end)

    defaults = %{
      year: 2025,
      start_date: ~D[2025-01-01],
      end_date: ~D[2025-01-14],
      status: :completed
    }

    {:ok, edition} =
      defaults
      |> Map.merge(attrs)
      |> Map.put(:tournament_id, tournament_id)
      |> then(&TournamentEdition.changeset(%TournamentEdition{}, &1))
      |> Repo.insert()

    edition
  end
end
