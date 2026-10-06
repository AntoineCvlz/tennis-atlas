defmodule TennisAtlasApiWeb.TournamentControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.TournamentsFixtures
  import TennisAtlasApi.VenuesFixtures

  describe "GET /api/tournaments" do
    test "lists tournaments with pagination meta", %{conn: conn} do
      tournament_fixture(%{name: "A"})
      tournament_fixture(%{name: "B"})

      conn = get(conn, ~p"/api/tournaments")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta == %{"page" => 1, "page_size" => 20, "total_count" => 2, "total_pages" => 1}
    end

    test "filters by surface", %{conn: conn} do
      tournament_fixture(%{name: "Clay one", surface: :clay})
      tournament_fixture(%{name: "Hard one", surface: :hard})

      conn = get(conn, ~p"/api/tournaments?surface=clay")

      assert %{"data" => [%{"name" => "Clay one"}]} = json_response(conn, 200)
    end

    test "returns 422 for an invalid surface filter", %{conn: conn} do
      conn = get(conn, ~p"/api/tournaments?surface=nope")

      assert %{"errors" => %{"surface" => ["is invalid"]}} = json_response(conn, 422)
    end
  end

  describe "GET /api/tournaments/:slug" do
    test "shows a tournament with venue and editions", %{conn: conn} do
      venue = venue_fixture(%{name: "Venue X"})
      tournament = tournament_fixture(%{slug: "test-slug", venue_id: venue.id})
      tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})

      conn = get(conn, ~p"/api/tournaments/test-slug")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["slug"] == "test-slug"
      assert data["venue"]["name"] == "Venue X"
      assert [%{"year" => 2025}] = data["editions"]
    end

    test "returns 404 for an unknown slug", %{conn: conn} do
      # `get_tournament_by_slug!/1` raises `Ecto.NoResultsError`, which Phoenix
      # renders as a 404 response and then re-raises (see
      # `Phoenix.Endpoint.RenderErrors.maybe_raise/3`) so production logs still
      # show the error. `assert_error_sent/2` is the documented way to assert
      # on that response without the re-raise failing the test.
      {404, _headers, body} =
        assert_error_sent(404, fn -> get(conn, ~p"/api/tournaments/does-not-exist") end)

      assert Jason.decode!(body) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
