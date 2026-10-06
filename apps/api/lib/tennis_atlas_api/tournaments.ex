defmodule TennisAtlasApi.Tournaments do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}

  def list_tournaments(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Tournament
    |> apply_filter(:surface, filters[:surface])
    |> apply_filter(:category, filters[:category])
    |> preload(:venue)
    |> order_by(asc: :name)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_tournament_by_slug!(slug) do
    Tournament
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:venue, editions: from(e in TournamentEdition, order_by: [desc: e.year])])
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
