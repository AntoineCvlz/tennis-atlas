defmodule TennisAtlasApi.MatchesFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Matches.{Match, Set}
  import TennisAtlasApi.TournamentsFixtures, only: [tournament_edition_fixture: 1]
  import TennisAtlasApi.PlayersFixtures, only: [player_fixture: 1]

  def match_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    tournament_edition_id = Map.get_lazy(attrs, :tournament_edition_id, fn -> tournament_edition_fixture(%{}).id end)
    player_a_id = Map.get_lazy(attrs, :player_a_id, fn -> player_fixture(%{}).id end)
    player_b_id = Map.get_lazy(attrs, :player_b_id, fn -> player_fixture(%{}).id end)

    defaults = %{tour: :atp, round: :qf, status: :scheduled, best_of: 3}

    {:ok, match} =
      defaults
      |> Map.merge(attrs)
      |> Map.merge(%{
        tournament_edition_id: tournament_edition_id,
        player_a_id: player_a_id,
        player_b_id: player_b_id
      })
      |> then(&Match.changeset(%Match{}, &1))
      |> Repo.insert()

    match
  end

  def set_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    match_id = Map.get_lazy(attrs, :match_id, fn -> match_fixture(%{}).id end)

    defaults = %{set_number: 1, player_a_games: 6, player_b_games: 4}

    {:ok, set} =
      defaults
      |> Map.merge(attrs)
      |> Map.put(:match_id, match_id)
      |> then(&Set.changeset(%Set{}, &1))
      |> Repo.insert()

    set
  end
end
