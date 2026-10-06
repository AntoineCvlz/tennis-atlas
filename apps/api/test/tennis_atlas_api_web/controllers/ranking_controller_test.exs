defmodule TennisAtlasApiWeb.RankingControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.PlayersFixtures

  describe "GET /api/rankings" do
    test "lists rankings for the given type", %{conn: conn} do
      player = player_fixture(%{})
      ranking_fixture(%{player_id: player.id, ranking_type: :atp, position: 1})

      conn = get(conn, ~p"/api/rankings?ranking_type=atp")

      assert %{"data" => [entry]} = json_response(conn, 200)
      assert entry["ranking_type"] == "atp"
      assert entry["player"]["id"] == player.id
    end

    test "returns 422 when ranking_type is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/rankings")

      assert %{"errors" => %{"ranking_type" => ["can't be blank"]}} = json_response(conn, 422)
    end
  end
end
