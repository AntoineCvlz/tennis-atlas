defmodule TennisAtlasApiWeb.TournamentController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Tournaments
  alias TennisAtlasApiWeb.QueryParams

  @filter_types %{
    surface: Ecto.ParameterizedType.init(Ecto.Enum, values: [:clay, :grass, :hard, :indoor]),
    category:
      Ecto.ParameterizedType.init(Ecto.Enum,
        values: [:grand_slam, :masters_1000, :atp_500, :atp_250, :wta_1000, :wta_500, :wta_250]
      )
  }

  def index(conn, params) do
    with {:ok, query} <- QueryParams.cast(params, @filter_types) do
      %{page: page, page_size: page_size} = query
      filters = Map.drop(query, [:page, :page_size])
      result = Tournaments.list_tournaments(filters, page, page_size)

      render(conn, :index,
        tournaments: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end

  def show(conn, %{"slug" => slug}) do
    tournament = Tournaments.get_tournament_by_slug!(slug)
    render(conn, :show, tournament: tournament)
  end
end
