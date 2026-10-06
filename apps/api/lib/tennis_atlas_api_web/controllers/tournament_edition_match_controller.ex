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
    with {:ok, query} <- QueryParams.cast(params, @types, [:year]),
         :ok <- validate_year(query.year) do
      edition = Tournaments.get_edition!(slug, query.year)
      filters = Map.drop(query, [:page, :page_size, :year])

      result =
        Tournaments.list_matches_for_edition(edition.id, filters, query.page, query.page_size)

      conn
      |> put_view(json: TennisAtlasApiWeb.MatchJSON)
      |> render(:index,
        matches: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end

  # Postgres's `int4` year column would overflow (and raise) on an
  # arbitrarily large year, so bound it here before it reaches the query —
  # 1850..2200 generously covers all plausible tournament years.
  defp validate_year(year) when year in 1850..2200, do: :ok
  defp validate_year(_year), do: {:error, year_error_changeset()}

  defp year_error_changeset do
    {%{}, %{year: :integer}}
    |> Ecto.Changeset.cast(%{}, [])
    |> Ecto.Changeset.add_error(:year, "is invalid")
  end
end
