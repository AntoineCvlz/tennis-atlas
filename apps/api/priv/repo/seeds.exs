# Fictional seed data for local development. None of the tournaments,
# venues, or players below are real — see docs/superpowers/specs/
# 2026-10-05-phase-2-database-design.md section 4. Real data starts
# arriving from an external provider at Phase 9 (Data ingestion).
#
# Run after `mix ecto.migrate` (or `mix ecto.reset`):
#   docker compose run --rm api mix run priv/repo/seeds.exs
#
# Re-running against a database that already has this data will raise
# on the unique constraints (slug, (tournament_id, year), etc.) — this
# script is meant to run once against a fresh database, not to be
# idempotent.

alias TennisAtlasApi.Repo
alias TennisAtlasApi.Venues.{Venue, Court}
alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition, TournamentEntry}
alias TennisAtlasApi.Players.{Player, Ranking}
alias TennisAtlasApi.Matches.{Match, Set}

insert_venue = fn attrs -> %Venue{} |> Venue.changeset(attrs) |> Repo.insert!() end

insert_court = fn venue, attrs ->
  %Court{} |> Court.changeset(Map.put(attrs, :venue_id, venue.id)) |> Repo.insert!()
end

insert_tournament = fn attrs -> %Tournament{} |> Tournament.changeset(attrs) |> Repo.insert!() end

insert_edition = fn tournament, attrs ->
  %TournamentEdition{}
  |> TournamentEdition.changeset(Map.put(attrs, :tournament_id, tournament.id))
  |> Repo.insert!()
end

insert_player = fn attrs -> %Player{} |> Player.changeset(attrs) |> Repo.insert!() end

insert_entry = fn edition, player, tour, seed ->
  %TournamentEntry{}
  |> TournamentEntry.changeset(%{
    tournament_edition_id: edition.id,
    player_id: player.id,
    tour: tour,
    seed: seed
  })
  |> Repo.insert!()
end

insert_match = fn edition, tour, round, player_a, player_b, winner, court, best_of ->
  now = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(-7, :day)

  %Match{}
  |> Match.changeset(%{
    tournament_edition_id: edition.id,
    tour: tour,
    round: round,
    player_a_id: player_a.id,
    player_b_id: player_b.id,
    winner_id: winner.id,
    court_id: court.id,
    status: :finished,
    best_of: best_of,
    scheduled_at: now,
    started_at: now,
    finished_at: DateTime.add(now, 7200, :second)
  })
  |> Repo.insert!()
end

insert_set = fn match, set_number, a_games, b_games, tiebreak_a, tiebreak_b ->
  %Set{}
  |> Set.changeset(%{
    match_id: match.id,
    set_number: set_number,
    player_a_games: a_games,
    player_b_games: b_games,
    tiebreak_a: tiebreak_a,
    tiebreak_b: tiebreak_b
  })
  |> Repo.insert!()
end

# A straight-sets result: winner takes 2 sets (best_of: 3) or 3 sets
# (best_of: 5), each 6-4, except the first set of a best_of: 5 match
# ends on a 7-6 tiebreak to prove the tiebreak columns work.
straight_sets = fn match, best_of ->
  sets_to_win = if best_of == 5, do: 3, else: 2

  if best_of == 5 do
    insert_set.(match, 1, 7, 6, 7, 5)
    for n <- 2..sets_to_win, do: insert_set.(match, n, 6, 4, nil, nil)
  else
    for n <- 1..sets_to_win, do: insert_set.(match, n, 6, 4, nil, nil)
  end
end

# Builds a single-elimination bracket (QF -> SF -> F) from 8 seeded
# players, pairing players[0] vs players[1], players[2] vs players[3],
# etc. The lower-indexed player in each pair always wins, so players[0]
# wins the final - deterministic and good enough for fictional data.
# Also creates the TournamentEntry for all 8 players (seed = bracket
# position). Returns the champion.
build_bracket = fn edition, tour, court, players, best_of ->
  players
  |> Enum.with_index(1)
  |> Enum.each(fn {player, seed} -> insert_entry.(edition, player, tour, seed) end)

  qf_winners =
    players
    |> Enum.chunk_every(2)
    |> Enum.map(fn [a, b] ->
      match = insert_match.(edition, tour, :qf, a, b, a, court, best_of)
      straight_sets.(match, best_of)
      a
    end)

  [sf_a, sf_b] =
    qf_winners
    |> Enum.chunk_every(2)
    |> Enum.map(fn [a, b] ->
      match = insert_match.(edition, tour, :sf, a, b, a, court, best_of)
      straight_sets.(match, best_of)
      a
    end)

  final = insert_match.(edition, tour, :f, sf_a, sf_b, sf_a, court, best_of)
  straight_sets.(final, best_of)

  sf_a
end

# --- Venues & courts ---

paris =
  insert_venue.(%{
    name: "Stade Fictif de Paris",
    city: "Paris",
    country_code: "FRA",
    latitude: 48.8472,
    longitude: 2.2519
  })

london =
  insert_venue.(%{
    name: "All England Fictif Club",
    city: "Londres",
    country_code: "GBR",
    latitude: 51.4340,
    longitude: -0.2140
  })

new_york =
  insert_venue.(%{
    name: "Fictif National Tennis Center",
    city: "New York",
    country_code: "USA",
    latitude: 40.7498,
    longitude: -73.8458
  })

court_paris = insert_court.(paris, %{name: "Court Central Fictif", surface: :clay, capacity: 15_000, indoor: false})
court_london = insert_court.(london, %{name: "Court Central Fictif", surface: :grass, capacity: 15_000, indoor: false})
court_ny = insert_court.(new_york, %{name: "Court Central Fictif", surface: :hard, capacity: 23_000, indoor: false})

# --- Tournaments & editions ---

roland_garros =
  insert_tournament.(%{
    name: "Internationaux Fictifs de France",
    slug: "internationaux-fictifs-de-france",
    category: :grand_slam,
    surface: :clay,
    venue_id: paris.id
  })

wimbledon =
  insert_tournament.(%{
    name: "Championnats Fictifs de Wimbledon",
    slug: "championnats-fictifs-de-wimbledon",
    category: :grand_slam,
    surface: :grass,
    venue_id: london.id
  })

ny_open =
  insert_tournament.(%{
    name: "Open Fictif de New York",
    slug: "open-fictif-de-new-york",
    category: :atp_500,
    surface: :hard,
    venue_id: new_york.id
  })

rg_edition = insert_edition.(roland_garros, %{year: 2025, start_date: ~D[2025-05-25], end_date: ~D[2025-06-08], status: :completed})
wimbledon_edition = insert_edition.(wimbledon, %{year: 2025, start_date: ~D[2025-06-30], end_date: ~D[2025-07-13], status: :completed})
ny_edition = insert_edition.(ny_open, %{year: 2025, start_date: ~D[2025-02-10], end_date: ~D[2025-02-16], status: :completed})

# --- Players (fictional) ---

atp_players =
  [
    %{first_name: "Mateo", last_name: "Rivera", slug: "mateo-rivera", country_code: "ESP"},
    %{first_name: "Lukas", last_name: "Hoffmann", slug: "lukas-hoffmann", country_code: "GER"},
    %{first_name: "Kenji", last_name: "Watanabe", slug: "kenji-watanabe", country_code: "JPN"},
    %{first_name: "Dario", last_name: "Conti", slug: "dario-conti", country_code: "ITA"},
    %{first_name: "Noah", last_name: "Johansson", slug: "noah-johansson", country_code: "SWE"},
    %{first_name: "Felix", last_name: "Duarte", slug: "felix-duarte", country_code: "POR"},
    %{first_name: "Ivan", last_name: "Petrov", slug: "ivan-petrov", country_code: "BUL"},
    %{first_name: "Owen", last_name: "Mitchell", slug: "owen-mitchell", country_code: "AUS"}
  ]
  |> Enum.map(&insert_player.(Map.put(&1, :hand, :right)))

wta_players =
  [
    %{first_name: "Elena", last_name: "Marchetti", slug: "elena-marchetti", country_code: "ITA"},
    %{first_name: "Sofia", last_name: "Larsson", slug: "sofia-larsson", country_code: "SWE"},
    %{first_name: "Amara", last_name: "Okafor", slug: "amara-okafor", country_code: "NGA"},
    %{first_name: "Camille", last_name: "Dubois", slug: "camille-dubois", country_code: "FRA"},
    %{first_name: "Yuki", last_name: "Tanaka", slug: "yuki-tanaka", country_code: "JPN"},
    %{first_name: "Isabel", last_name: "Rocha", slug: "isabel-rocha", country_code: "BRA"},
    %{first_name: "Mia", last_name: "Andersen", slug: "mia-andersen", country_code: "DEN"},
    %{first_name: "Priya", last_name: "Sharma", slug: "priya-sharma", country_code: "IND"}
  ]
  |> Enum.map(&insert_player.(Map.put(&1, :hand, :left)))

# --- Brackets (QF -> SF -> F, 7 matches each) ---

build_bracket.(rg_edition, :atp, court_paris, atp_players, 5)
build_bracket.(wimbledon_edition, :wta, court_london, wta_players, 3)
build_bracket.(ny_edition, :atp, court_ny, atp_players, 3)

# --- Rankings (one snapshot per player, also cached onto Player) ---

seed_rankings = fn players, ranking_type ->
  players
  |> Enum.with_index(1)
  |> Enum.each(fn {player, position} ->
    points = 10_000 - position * 500

    %Ranking{}
    |> Ranking.changeset(%{
      player_id: player.id,
      ranking_type: ranking_type,
      position: position,
      points: points,
      as_of_date: ~D[2025-09-01]
    })
    |> Repo.insert!()

    player
    |> Player.changeset(%{current_ranking: position, current_ranking_points: points})
    |> Repo.update!()
  end)
end

seed_rankings.(atp_players, :atp)
seed_rankings.(wta_players, :wta)

IO.puts(
  "Seeded 3 venues, 3 courts, 3 tournaments, 3 editions, #{length(atp_players) + length(wta_players)} players, 21 matches."
)
