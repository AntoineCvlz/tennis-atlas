defmodule TennisAtlasApi.Repo do
  use Ecto.Repo,
    otp_app: :tennis_atlas_api,
    adapter: Ecto.Adapters.Postgres
end
