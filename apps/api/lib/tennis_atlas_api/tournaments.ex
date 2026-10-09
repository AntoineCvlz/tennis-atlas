defmodule TennisAtlasApi.Tournaments do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Matches.Match

  def list_tournaments(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Tournament
    |> apply_filter(:surface, filters[:surface])
    |> apply_filter(:category, filters[:category])
    |> preload(:venue)
    |> order_by(asc: :name, asc: :id)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_tournament_by_slug!(slug) do
    Tournament
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:venue, editions: from(e in TournamentEdition, order_by: [desc: e.year])])
  end

  def get_edition!(tournament_slug, year) do
    TournamentEdition
    |> join(:inner, [e], t in assoc(e, :tournament))
    |> where([e, t], t.slug == ^tournament_slug and e.year == ^year)
    |> preload(:tournament)
    |> Repo.one!()
  end

  def list_matches_for_edition(edition_id, filters \\ %{}, page \\ 1, page_size \\ 20) do
    Match
    |> where([m], m.tournament_edition_id == ^edition_id)
    |> apply_filter(:tour, filters[:tour])
    |> apply_filter(:status, filters[:status])
    |> preload([:player_a, :player_b, :court, :sets])
    |> order_by(asc: :id)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
