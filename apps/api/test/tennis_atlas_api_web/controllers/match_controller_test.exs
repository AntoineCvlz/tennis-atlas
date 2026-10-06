defmodule TennisAtlasApiWeb.MatchControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.MatchesFixtures

  describe "GET /api/matches/:id" do
    test "shows a match with sets and tournament context", %{conn: conn} do
      match = match_fixture(%{})
      set_fixture(%{match_id: match.id, set_number: 1})

      conn = get(conn, ~p"/api/matches/#{match.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == match.id
      assert length(data["sets"]) == 1
      assert data["tournament"]["tournament_id"] != nil
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      {404, _headers, body} =
        assert_error_sent(404, fn -> get(conn, ~p"/api/matches/999999") end)

      assert Jason.decode!(body) == %{"errors" => %{"detail" => "Not Found"}}
    end

    test "returns 404 for a non-numeric id instead of crashing", %{conn: conn} do
      conn = get(conn, ~p"/api/matches/not-a-number")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end

    test "returns 404 for an id beyond Postgres's bigint range instead of crashing", %{conn: conn} do
      conn = get(conn, ~p"/api/matches/99999999999999999999")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
