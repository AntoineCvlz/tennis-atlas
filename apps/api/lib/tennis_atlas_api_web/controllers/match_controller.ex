defmodule TennisAtlasApiWeb.MatchController do
  use TennisAtlasApiWeb, :controller

  alias TennisAtlasApi.Matches

  def show(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {int_id, ""} ->
        match = Matches.get_match!(int_id)
        render(conn, :show, match: match)

      _ ->
        conn
        |> put_status(:not_found)
        |> put_view(json: TennisAtlasApiWeb.ErrorJSON)
        |> render(:"404")
    end
  end
end
