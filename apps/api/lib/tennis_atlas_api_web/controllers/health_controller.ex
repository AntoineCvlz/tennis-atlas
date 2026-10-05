defmodule TennisAtlasApiWeb.HealthController do
  use TennisAtlasApiWeb, :controller

  alias TennisAtlasApi.Repo

  def index(conn, _params) do
    database_status =
      case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
        {:ok, _result} -> "connected"
        {:error, _reason} -> "unavailable"
      end

    json(conn, %{status: "ok", database: database_status})
  end
end
