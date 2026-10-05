FROM elixir:1.17.3-otp-27-alpine

RUN apk add --no-cache build-base git

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

CMD ["sh", "-c", "mix deps.get && mix ecto.create && mix ecto.migrate && mix phx.server"]
