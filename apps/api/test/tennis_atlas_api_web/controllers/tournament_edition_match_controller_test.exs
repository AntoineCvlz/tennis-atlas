defmodule TennisAtlasApiWeb.TournamentEditionMatchControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.TournamentsFixtures
  import TennisAtlasApi.MatchesFixtures

  describe "GET /api/tournaments/:slug/editions/:year/matches" do
    test "lists matches for the edition", %{conn: conn} do
      tournament = tournament_fixture(%{slug: "with-matches"})
      edition = tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})
      match_fixture(%{tournament_edition_id: edition.id})

      conn = get(conn, ~p"/api/tournaments/with-matches/editions/2025/matches")

      assert %{"data" => [_match]} = json_response(conn, 200)
    end

    test "returns 404 for an unknown tournament/year combination", %{conn: conn} do
      tournament_fixture(%{slug: "no-matches"})

      {404, _headers, body} =
        assert_error_sent(404, fn ->
          get(conn, ~p"/api/tournaments/no-matches/editions/1999/matches")
        end)

      assert Jason.decode!(body) == %{"errors" => %{"detail" => "Not Found"}}
    end

    test "filters by tour", %{conn: conn} do
      tournament = tournament_fixture(%{slug: "filter-tour"})
      edition = tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})
      match_fixture(%{tournament_edition_id: edition.id, tour: :atp})
      match_fixture(%{tournament_edition_id: edition.id, tour: :wta})

      conn = get(conn, ~p"/api/tournaments/filter-tour/editions/2025/matches?tour=atp")

      assert %{"data" => [match]} = json_response(conn, 200)
      assert match["tour"] == "atp"
    end

    test "returns 422 for a year far beyond Postgres's integer range", %{conn: conn} do
      tournament_fixture(%{slug: "huge-year"})

      conn = get(conn, ~p"/api/tournaments/huge-year/editions/99999999999999999999/matches")

      assert %{"errors" => %{"year" => ["is invalid"]}} = json_response(conn, 422)
    end
  end
end
