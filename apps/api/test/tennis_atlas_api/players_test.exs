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

  describe "list_rankings/3" do
    test "returns only the latest snapshot per player for the given type" do
      player = player_fixture(%{})

      ranking_fixture(%{
        player_id: player.id,
        ranking_type: :atp,
        as_of_date: ~D[2025-01-01],
        position: 5
      })

      ranking_fixture(%{
        player_id: player.id,
        ranking_type: :atp,
        as_of_date: ~D[2025-09-01],
        position: 3
      })

      result = Players.list_rankings(%{ranking_type: :atp})

      assert [%{position: 3, as_of_date: ~D[2025-09-01]}] = result.entries
    end

    test "excludes the other ranking type" do
      player_a = player_fixture(%{})
      player_b = player_fixture(%{})
      ranking_fixture(%{player_id: player_a.id, ranking_type: :atp, position: 1})
      ranking_fixture(%{player_id: player_b.id, ranking_type: :wta, position: 1})

      result = Players.list_rankings(%{ranking_type: :atp})

      assert [%{player_id: player_id}] = result.entries
      assert player_id == player_a.id
    end

    test "orders by position ascending" do
      player_a = player_fixture(%{})
      player_b = player_fixture(%{})
      ranking_fixture(%{player_id: player_a.id, ranking_type: :atp, position: 2})
      ranking_fixture(%{player_id: player_b.id, ranking_type: :atp, position: 1})

      result = Players.list_rankings(%{ranking_type: :atp})

      assert [%{position: 1}, %{position: 2}] = result.entries
    end

    test "excludes a same-as_of_date row for the other ranking type (not just a different player's row)" do
      player = player_fixture(%{})
      same_date = ~D[2025-09-01]

      ranking_fixture(%{
        player_id: player.id,
        ranking_type: :atp,
        as_of_date: same_date,
        position: 1
      })

      ranking_fixture(%{
        player_id: player.id,
        ranking_type: :wta,
        as_of_date: same_date,
        position: 1
      })

      result = Players.list_rankings(%{ranking_type: :atp})

      assert [%{ranking_type: :atp}] = result.entries
    end
  end
end
