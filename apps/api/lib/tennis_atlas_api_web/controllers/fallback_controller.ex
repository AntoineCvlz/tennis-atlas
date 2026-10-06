defmodule TennisAtlasApiWeb.FallbackController do
  use TennisAtlasApiWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: TennisAtlasApiWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
