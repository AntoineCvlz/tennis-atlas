defmodule TennisAtlasApi.MatchesTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Matches
  import TennisAtlasApi.MatchesFixtures

  describe "get_match!/1" do
    test "returns the match with sets, players, court and tournament preloaded" do
      match = match_fixture(%{})
      set_fixture(%{match_id: match.id, set_number: 1})

      result = Matches.get_match!(match.id)

      assert result.id == match.id
      assert length(result.sets) == 1
      assert result.tournament_edition.tournament.id != nil
    end

    test "raises Ecto.NoResultsError for an unknown id" do
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(999_999) end
    end
  end
end
