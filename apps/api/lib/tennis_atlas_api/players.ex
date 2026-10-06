defmodule TennisAtlasApi.Players do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Players.Player

  def list_players(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Player
    |> apply_filter(:country_code, filters[:country_code])
    |> order_by(asc: :last_name, asc: :first_name)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_player_by_slug!(slug), do: Repo.get_by!(Player, slug: slug)

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
