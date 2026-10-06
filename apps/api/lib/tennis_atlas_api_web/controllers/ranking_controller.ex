defmodule TennisAtlasApiWeb.RankingController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Players
  alias TennisAtlasApiWeb.QueryParams

  @types %{ranking_type: Ecto.ParameterizedType.init(Ecto.Enum, values: [:atp, :wta])}

  def index(conn, params) do
    with {:ok, query} <- QueryParams.cast(params, @types, [:ranking_type]) do
      %{page: page, page_size: page_size} = query
      filters = Map.drop(query, [:page, :page_size])
      result = Players.list_rankings(filters, page, page_size)

      render(conn, :index,
        rankings: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end
end
