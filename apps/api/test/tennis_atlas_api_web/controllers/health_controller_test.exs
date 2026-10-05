defmodule TennisAtlasApiWeb.HealthControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  test "GET /api/health returns ok status and confirms database connectivity", %{conn: conn} do
    conn = get(conn, ~p"/api/health")

    assert %{"status" => "ok", "database" => "connected"} = json_response(conn, 200)
  end
end
