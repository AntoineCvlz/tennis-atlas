defmodule TennisAtlasApi.Matches do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Matches.Match

  def get_match!(id) do
    Match
    |> Repo.get!(id)
    |> Repo.preload([:sets, :player_a, :player_b, :court, tournament_edition: :tournament])
  end
end
