defmodule TennisAtlasApi.PlayersFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Players.Player

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
end
