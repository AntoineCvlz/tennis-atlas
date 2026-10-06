defmodule TennisAtlasApiWeb.PlayerController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Players
  alias TennisAtlasApiWeb.QueryParams

  @filter_types %{country_code: :string}

  def index(conn, params) do
    with {:ok, query} <- QueryParams.cast(params, @filter_types) do
      %{page: page, page_size: page_size} = query
      filters = Map.drop(query, [:page, :page_size])
      result = Players.list_players(filters, page, page_size)

      render(conn, :index,
        players: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end

  def show(conn, %{"slug" => slug}) do
    player = Players.get_player_by_slug!(slug)
    render(conn, :show, player: player)
  end
end
