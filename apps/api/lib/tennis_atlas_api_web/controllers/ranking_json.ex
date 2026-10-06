defmodule TennisAtlasApiWeb.RankingJSON do
  def index(%{rankings: rankings, meta: meta}) do
    %{data: for(r <- rankings, do: entry(r)), meta: meta}
  end

  defp entry(r) do
    %{
      ranking_type: r.ranking_type,
      position: r.position,
      points: r.points,
      as_of_date: r.as_of_date,
      player: %{id: r.player.id, first_name: r.player.first_name, last_name: r.player.last_name, slug: r.player.slug}
    }
  end
end
