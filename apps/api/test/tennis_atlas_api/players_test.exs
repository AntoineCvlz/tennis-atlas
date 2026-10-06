defmodule TennisAtlasApi.PlayersTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Players
  import TennisAtlasApi.PlayersFixtures

  describe "list_players/3" do
    test "returns all players" do
      player_fixture(%{first_name: "A"})
      player_fixture(%{first_name: "B"})

      result = Players.list_players()

      assert length(result.entries) == 2
    end

    test "filters by country_code" do
      player_fixture(%{first_name: "French", country_code: "FRA"})
      player_fixture(%{first_name: "Spanish", country_code: "ESP"})

      result = Players.list_players(%{country_code: "ESP"})

      assert [%{first_name: "Spanish"}] = result.entries
    end

    test "paginates results" do
      for n <- 1..3, do: player_fixture(%{first_name: "P#{n}"})

      result = Players.list_players(%{}, 1, 2)

      assert length(result.entries) == 2
      assert result.total_count == 3
    end
  end

  describe "get_player_by_slug!/1" do
    test "returns the player" do
      player = player_fixture(%{slug: "known-slug"})

      assert Players.get_player_by_slug!("known-slug").id == player.id
    end

    test "raises Ecto.NoResultsError for an unknown slug" do
      assert_raise Ecto.NoResultsError, fn -> Players.get_player_by_slug!("nope") end
    end
  end
end
