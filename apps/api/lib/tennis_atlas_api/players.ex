defmodule TennisAtlasApi.Players do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Players.{Player, Ranking}

  def list_players(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Player
    |> apply_filter(:country_code, filters[:country_code])
    |> order_by(asc: :last_name, asc: :first_name)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_player_by_slug!(slug), do: Repo.get_by!(Player, slug: slug)

  def list_rankings(filters, page \\ 1, page_size \\ 20) do
    ranking_type = filters.ranking_type

    latest =
      from(r in Ranking,
        where: r.ranking_type == ^ranking_type,
        group_by: r.player_id,
        select: %{player_id: r.player_id, as_of_date: max(r.as_of_date)}
      )

    from(r in Ranking,
      join: l in subquery(latest),
      on: r.player_id == l.player_id and r.as_of_date == l.as_of_date,
      where: r.ranking_type == ^ranking_type,
      order_by: [asc: r.position],
      preload: [:player]
    )
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
