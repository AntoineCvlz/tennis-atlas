defmodule TennisAtlasApiWeb.MatchController do
  use TennisAtlasApiWeb, :controller

  alias TennisAtlasApi.Matches

  def show(conn, %{"id" => id}) do
    case Integer.parse(id) do
      {int_id, ""} when int_id > 0 and int_id <= 9_223_372_036_854_775_807 ->
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
