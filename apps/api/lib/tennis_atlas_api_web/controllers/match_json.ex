defmodule TennisAtlasApiWeb.MatchJSON do
  alias TennisAtlasApi.Matches.Match

  def index(%{matches: matches, meta: meta}) do
    %{data: for(m <- matches, do: summary(m)), meta: meta}
  end

  def show(%{match: match}) do
    %{data: detail(match)}
  end

  defp summary(%Match{} = m) do
    %{
      id: m.id,
      tour: m.tour,
      round: m.round,
      status: m.status,
      scheduled_at: m.scheduled_at,
      started_at: m.started_at,
      finished_at: m.finished_at,
      best_of: m.best_of,
      winner_id: m.winner_id,
      player_a: player_ref(m.player_a),
      player_b: player_ref(m.player_b),
      court: court_ref(m.court),
      sets: for(s <- m.sets, do: set_ref(s))
    }
  end

  defp detail(%Match{} = m) do
    Map.merge(summary(m), %{
      tournament: tournament_ref(m.tournament_edition)
    })
  end

  defp player_ref(nil), do: nil

  defp player_ref(player),
    do: %{
      id: player.id,
      first_name: player.first_name,
      last_name: player.last_name,
      slug: player.slug
    }

  defp court_ref(nil), do: nil
  defp court_ref(court), do: %{id: court.id, name: court.name, surface: court.surface}

  defp tournament_ref(edition) do
    %{
      edition_id: edition.id,
      year: edition.year,
      tournament_id: edition.tournament.id,
      tournament_name: edition.tournament.name,
      tournament_slug: edition.tournament.slug
    }
  end

  defp set_ref(s) do
    %{
      set_number: s.set_number,
      player_a_games: s.player_a_games,
      player_b_games: s.player_b_games,
      tiebreak_a: s.tiebreak_a,
      tiebreak_b: s.tiebreak_b
    }
  end
end
