defmodule TennisAtlasApiWeb.PlayerJSON do
  alias TennisAtlasApi.Players.Player

  def index(%{players: players, meta: meta}) do
    %{data: for(p <- players, do: summary(p)), meta: meta}
  end

  def show(%{player: player}) do
    %{data: detail(player)}
  end

  defp summary(%Player{} = p) do
    %{
      id: p.id,
      first_name: p.first_name,
      last_name: p.last_name,
      slug: p.slug,
      country_code: p.country_code,
      current_ranking: p.current_ranking,
      current_ranking_points: p.current_ranking_points
    }
  end

  defp detail(%Player{} = p) do
    Map.merge(summary(p), %{birth_date: p.birth_date, hand: p.hand, height_cm: p.height_cm})
  end
end
