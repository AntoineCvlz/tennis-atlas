defmodule TennisAtlasApiWeb.PlayerControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.PlayersFixtures

  describe "GET /api/players" do
    test "lists players with pagination meta", %{conn: conn} do
      player_fixture(%{first_name: "A"})
      player_fixture(%{first_name: "B"})

      conn = get(conn, ~p"/api/players")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta == %{"page" => 1, "page_size" => 20, "total_count" => 2, "total_pages" => 1}
    end

    test "filters by country_code", %{conn: conn} do
      player_fixture(%{first_name: "French", country_code: "FRA"})
      player_fixture(%{first_name: "Spanish", country_code: "ESP"})

      conn = get(conn, ~p"/api/players?country_code=ESP")

      assert %{"data" => [%{"first_name" => "Spanish"}]} = json_response(conn, 200)
    end
  end

  describe "GET /api/players/:slug" do
    test "shows a player", %{conn: conn} do
      player_fixture(%{slug: "known-slug", first_name: "Known"})

      conn = get(conn, ~p"/api/players/known-slug")

      assert %{"data" => %{"first_name" => "Known"}} = json_response(conn, 200)
    end

    test "returns 404 for an unknown slug", %{conn: conn} do
      # `get_player_by_slug!/1` raises `Ecto.NoResultsError`, which Phoenix
      # renders as a 404 response and then re-raises (see
      # `Phoenix.Endpoint.RenderErrors.maybe_raise/3`) so production logs still
      # show the error. `assert_error_sent/2` is the documented way to assert
      # on that response without the re-raise failing the test.
      {404, _headers, body} =
        assert_error_sent(404, fn -> get(conn, ~p"/api/players/does-not-exist") end)

      assert Jason.decode!(body) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
