defmodule TennisAtlasApi.TournamentsTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments
  import TennisAtlasApi.TournamentsFixtures
  import TennisAtlasApi.VenuesFixtures

  describe "list_tournaments/3" do
    test "returns tournaments with venue preloaded" do
      venue = venue_fixture(%{name: "Venue X"})
      tournament_fixture(%{name: "A", venue_id: venue.id})

      result = Tournaments.list_tournaments()

      assert [%{venue: %{name: "Venue X"}}] = result.entries
    end

    test "filters by surface" do
      tournament_fixture(%{name: "Clay one", surface: :clay})
      tournament_fixture(%{name: "Hard one", surface: :hard})

      result = Tournaments.list_tournaments(%{surface: :clay})

      assert [%{name: "Clay one"}] = result.entries
    end

    test "filters by category" do
      tournament_fixture(%{name: "Slam", category: :grand_slam})
      tournament_fixture(%{name: "Not slam", category: :atp_250})

      result = Tournaments.list_tournaments(%{category: :grand_slam})

      assert [%{name: "Slam"}] = result.entries
    end

    test "paginates results" do
      for n <- 1..3, do: tournament_fixture(%{name: "T#{n}"})

      result = Tournaments.list_tournaments(%{}, 1, 2)

      assert length(result.entries) == 2
      assert result.total_count == 3
    end
  end

  describe "get_tournament_by_slug!/1" do
    test "returns the tournament with venue and editions preloaded, newest edition first" do
      tournament = tournament_fixture(%{slug: "test-slug"})
      tournament_edition_fixture(%{tournament_id: tournament.id, year: 2024})
      tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})

      result = Tournaments.get_tournament_by_slug!("test-slug")

      assert result.id == tournament.id
      assert [%{year: 2025}, %{year: 2024}] = result.editions
    end

    test "raises Ecto.NoResultsError for an unknown slug" do
      assert_raise Ecto.NoResultsError, fn -> Tournaments.get_tournament_by_slug!("nope") end
    end
  end
end
