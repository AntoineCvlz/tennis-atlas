defmodule TennisAtlasApiWeb.Router do
  use TennisAtlasApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", TennisAtlasApiWeb do
    pipe_through :api

    get "/health", HealthController, :index

    get "/tournaments", TournamentController, :index
    get "/tournaments/:slug", TournamentController, :show

    get "/players", PlayerController, :index
    get "/players/:slug", PlayerController, :show

    get "/tournaments/:slug/editions/:year/matches", TournamentEditionMatchController, :index
    get "/matches/:id", MatchController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:tennis_atlas_api, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: TennisAtlasApiWeb.Telemetry
    end
  end
end
