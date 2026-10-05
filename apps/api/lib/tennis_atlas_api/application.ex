defmodule TennisAtlasApi.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TennisAtlasApiWeb.Telemetry,
      TennisAtlasApi.Repo,
      {DNSCluster, query: Application.get_env(:tennis_atlas_api, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TennisAtlasApi.PubSub},
      # Start a worker by calling: TennisAtlasApi.Worker.start_link(arg)
      # {TennisAtlasApi.Worker, arg},
      # Start to serve requests, typically the last entry
      TennisAtlasApiWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TennisAtlasApi.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TennisAtlasApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
