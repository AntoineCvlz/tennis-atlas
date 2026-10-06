defmodule TennisAtlasApiWeb.TournamentEditionMatchController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Tournaments
  alias TennisAtlasApiWeb.QueryParams

  @types %{
    year: :integer,
    tour: Ecto.ParameterizedType.init(Ecto.Enum, values: [:atp, :wta]),
    status:
      Ecto.ParameterizedType.init(Ecto.Enum,
        values: [:scheduled, :live, :finished, :retired, :walkover, :cancelled]
      )
  }

  def index(conn, %{"slug" => slug} = params) do
    with {:ok, query} <- QueryParams.cast(params, @types, [:year]) do
      edition = Tournaments.get_edition!(slug, query.year)
      filters = Map.drop(query, [:page, :page_size, :year])
      result = Tournaments.list_matches_for_edition(edition.id, filters, query.page, query.page_size)

      conn
      |> put_view(json: TennisAtlasApiWeb.MatchJSON)
      |> render(:index,
        matches: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end
end
