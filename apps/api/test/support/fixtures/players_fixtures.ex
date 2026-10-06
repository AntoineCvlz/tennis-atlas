defmodule TennisAtlasApi.PlayersFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Players.{Player, Ranking}

  def player_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])

    defaults = %{
      first_name: "Test",
      last_name: "Player#{n}",
      slug: "test-player-#{n}",
      country_code: "FRA"
    }

    {:ok, player} =
      defaults
      |> Map.merge(attrs)
      |> then(&Player.changeset(%Player{}, &1))
      |> Repo.insert()

    player
  end

  def ranking_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    player_id = Map.get_lazy(attrs, :player_id, fn -> player_fixture(%{}).id end)

    defaults = %{ranking_type: :atp, position: 1, points: 5000, as_of_date: ~D[2025-09-01]}

    {:ok, ranking} =
      defaults
      |> Map.merge(attrs)
      |> Map.put(:player_id, player_id)
      |> then(&Ranking.changeset(%Ranking{}, &1))
      |> Repo.insert()

    ranking
  end
end
