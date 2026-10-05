# Tennis Atlas — Phase 2 : Database Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nine Ecto schemas with migrations, changesets, and changeset tests, plus a fictional seed dataset (3 venues, 3 tournaments, 16 players, 21 matches) — proving the data model from the design spec is sound and queryable. No Phoenix contexts (query functions), no REST API, no Oban — those are later phases.

**Architecture:** Each entity gets a migration (`mix ecto.gen.migration`), an `Ecto.Schema` module with a `changeset/2` function, and a `DataCase`-based test file covering required fields, enum validation, and unique constraints. Modules are namespaced by anticipated Phoenix context (`Venues`, `Tournaments`, `Players`, `Matches`) even though the context *functions* don't exist yet. Tasks are ordered by foreign-key dependency so every task's tests can actually run against real referenced rows.

**Tech Stack:** Ecto, Ecto.Enum, PostgreSQL (via the `db` service from Phase 1), ExUnit + `TennisAtlasApi.DataCase` (generated in Phase 1).

**Spec:** [docs/superpowers/specs/2026-10-05-phase-2-database-design.md](../specs/2026-10-05-phase-2-database-design.md) (field-level schema, the `tour` field rationale, seed plan) and [docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md](../specs/2026-10-05-tennis-atlas-architecture-design.md) (project-wide architecture).

## Global Constraints

- PostgreSQL is the only source of truth (per the architecture spec) — no external API calls anywhere in this phase.
- All enumerated columns use `Ecto.Enum` (`:string` column + application-level validation), never a native Postgres enum type.
- `Tournament` and `TournamentEdition` are separate entities; `Tournament` references `Venue` via `venue_id`, never duplicates `city`/`country` as raw text.
- `Match` and `TournamentEntry` carry a `tour` field (`:atp` / `:wta`) — required because a Grand Slam `Tournament` hosts both draws simultaneously under one `TournamentEdition`.
- `Match` has no free-text `score` field — `Set` rows are the only source of truth for scores.
- Seed data is 100% fictional (invented names, invented tournaments) and must say so in a comment in `seeds.exs` — no real player or tournament data before Phase 9 (external provider integration).
- Commands run via `docker compose run --rm api <cmd>` / `docker compose exec api <cmd>` against the `api` service built in Phase 1 — no local Elixir install assumed.

---

### Task 1: Venue + Court

**Files:**
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_venues.exs`
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_courts.exs`
- Create: `apps/api/lib/tennis_atlas_api/venues/venue.ex`
- Create: `apps/api/lib/tennis_atlas_api/venues/court.ex`
- Test: `apps/api/test/tennis_atlas_api/venues/venue_test.exs`
- Test: `apps/api/test/tennis_atlas_api/venues/court_test.exs`

**Interfaces:**
- Consumes: nothing (first task; no FK dependencies).
- Produces: `TennisAtlasApi.Venues.Venue` (fields: `name`, `city`, `country_code`, `latitude`, `longitude`) and `TennisAtlasApi.Venues.Court` (fields: `venue_id`, `name`, `surface` (`Ecto.Enum` `:clay/:grass/:hard/:indoor`), `capacity`, `indoor`), each with a `changeset/2`. Task 2 (`Tournament.venue_id`) and Task 5 (`Match.court_id`) reference these tables by FK; Task 7 (seeds) calls `Venue.changeset/2` and `Court.changeset/2` directly.

- [ ] **Step 1: Start the `db` service (needed for every task from here on)**

Run: `docker compose up -d db`
Expected: `db` container reaches `(healthy)`.

- [ ] **Step 2: Generate the venues migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_venues`
Expected: prints the created file path under `priv/repo/migrations/`.

- [ ] **Step 3: Write the venues migration**

Open the generated file and replace the `change` function with:

```elixir
def change do
  create table(:venues) do
    add :name, :string, null: false
    add :city, :string, null: false
    add :country_code, :string, null: false
    add :latitude, :float
    add :longitude, :float

    timestamps()
  end
end
```

- [ ] **Step 4: Generate the courts migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_courts`

- [ ] **Step 5: Write the courts migration**

```elixir
def change do
  create table(:courts) do
    add :venue_id, references(:venues, on_delete: :delete_all), null: false
    add :name, :string, null: false
    add :surface, :string, null: false
    add :capacity, :integer
    add :indoor, :boolean, null: false, default: false

    timestamps()
  end

  create index(:courts, [:venue_id])
end
```

- [ ] **Step 6: Run the migrations**

Run: `docker compose run --rm api mix ecto.migrate`
Expected: both migrations listed as applied, exit code 0.

- [ ] **Step 7: Write the failing tests**

Create `apps/api/test/tennis_atlas_api/venues/venue_test.exs`:

```elixir
defmodule TennisAtlasApi.Venues.VenueTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Venues.Venue

  test "changeset with valid attributes is valid" do
    changeset =
      Venue.changeset(%Venue{}, %{
        name: "Stade Fictif de Paris",
        city: "Paris",
        country_code: "FRA",
        latitude: 48.8472,
        longitude: 2.2519
      })

    assert changeset.valid?
  end

  test "changeset requires name, city, country_code" do
    changeset = Venue.changeset(%Venue{}, %{})

    refute changeset.valid?

    assert %{name: ["can't be blank"], city: ["can't be blank"], country_code: ["can't be blank"]} =
             errors_on(changeset)
  end
end
```

Create `apps/api/test/tennis_atlas_api/venues/court_test.exs`:

```elixir
defmodule TennisAtlasApi.Venues.CourtTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Venues.{Court, Venue}
  alias TennisAtlasApi.Repo

  defp venue_fixture do
    %Venue{}
    |> Venue.changeset(%{name: "Test Venue", city: "Test City", country_code: "FRA"})
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    venue = venue_fixture()

    changeset =
      Court.changeset(%Court{}, %{
        venue_id: venue.id,
        name: "Court Central",
        surface: :clay,
        capacity: 15_000,
        indoor: false
      })

    assert changeset.valid?
  end

  test "changeset requires venue_id, name, surface" do
    changeset = Court.changeset(%Court{}, %{})

    refute changeset.valid?

    assert %{venue_id: ["can't be blank"], name: ["can't be blank"], surface: ["can't be blank"]} =
             errors_on(changeset)
  end

  test "changeset rejects an invalid surface value" do
    venue = venue_fixture()

    changeset =
      Court.changeset(%Court{}, %{venue_id: venue.id, name: "Court 1", surface: :clay_tennis})

    refute changeset.valid?
    assert %{surface: ["is invalid"]} = errors_on(changeset)
  end
end
```

- [ ] **Step 8: Run tests to verify they fail**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/venues/`
Expected: FAIL — `TennisAtlasApi.Venues.Venue`/`Court` modules undefined (compile error is the expected RED state here, since the schema modules don't exist yet).

- [ ] **Step 9: Write the Venue schema**

Create `apps/api/lib/tennis_atlas_api/venues/venue.ex`:

```elixir
defmodule TennisAtlasApi.Venues.Venue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "venues" do
    field :name, :string
    field :city, :string
    field :country_code, :string
    field :latitude, :float
    field :longitude, :float

    has_many :courts, TennisAtlasApi.Venues.Court

    timestamps()
  end

  @required_fields [:name, :city, :country_code]
  @optional_fields [:latitude, :longitude]

  def changeset(venue, attrs) do
    venue
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
```

- [ ] **Step 10: Write the Court schema**

Create `apps/api/lib/tennis_atlas_api/venues/court.ex`:

```elixir
defmodule TennisAtlasApi.Venues.Court do
  use Ecto.Schema
  import Ecto.Changeset

  schema "courts" do
    field :name, :string
    field :surface, Ecto.Enum, values: [:clay, :grass, :hard, :indoor]
    field :capacity, :integer
    field :indoor, :boolean, default: false

    belongs_to :venue, TennisAtlasApi.Venues.Venue

    timestamps()
  end

  @required_fields [:venue_id, :name, :surface]
  @optional_fields [:capacity, :indoor]

  def changeset(court, attrs) do
    court
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:venue_id)
  end
end
```

- [ ] **Step 11: Run tests to verify they pass**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/venues/`
Expected: PASS, 5 tests, 0 failures.

- [ ] **Step 12: Commit**

```bash
git add apps/api/priv/repo/migrations apps/api/lib/tennis_atlas_api/venues apps/api/test/tennis_atlas_api/venues
git commit -m "feat: add Venue and Court schemas"
```

---

### Task 2: Tournament + TournamentEdition

**Files:**
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_tournaments.exs`
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_tournament_editions.exs`
- Create: `apps/api/lib/tennis_atlas_api/tournaments/tournament.ex`
- Create: `apps/api/lib/tennis_atlas_api/tournaments/tournament_edition.ex`
- Test: `apps/api/test/tennis_atlas_api/tournaments/tournament_test.exs`
- Test: `apps/api/test/tennis_atlas_api/tournaments/tournament_edition_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.Venues.Venue` (Task 1) via `venue_id`.
- Produces: `TennisAtlasApi.Tournaments.Tournament` (fields: `name`, `slug`, `category` (`Ecto.Enum` `:grand_slam/:masters_1000/:atp_500/:atp_250/:wta_1000/:wta_500/:wta_250`), `surface`, `venue_id`, `description`, `logo_url`, `hero_image_url`) and `TennisAtlasApi.Tournaments.TournamentEdition` (fields: `tournament_id`, `year`, `start_date`, `end_date`, `status` (`Ecto.Enum` `:upcoming/:ongoing/:completed/:cancelled`, default `:upcoming`)). Tasks 4, 5, and 7 reference `TournamentEdition` by FK.

- [ ] **Step 1: Generate the tournaments migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_tournaments`

- [ ] **Step 2: Write the tournaments migration**

```elixir
def change do
  create table(:tournaments) do
    add :name, :string, null: false
    add :slug, :string, null: false
    add :category, :string, null: false
    add :surface, :string, null: false
    add :venue_id, references(:venues, on_delete: :nilify_all)
    add :description, :text
    add :logo_url, :string
    add :hero_image_url, :string

    timestamps()
  end

  create unique_index(:tournaments, [:slug])
  create index(:tournaments, [:venue_id])
end
```

- [ ] **Step 3: Generate the tournament_editions migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_tournament_editions`

- [ ] **Step 4: Write the tournament_editions migration**

```elixir
def change do
  create table(:tournament_editions) do
    add :tournament_id, references(:tournaments, on_delete: :delete_all), null: false
    add :year, :integer, null: false
    add :start_date, :date, null: false
    add :end_date, :date, null: false
    add :status, :string, null: false, default: "upcoming"

    timestamps()
  end

  create unique_index(:tournament_editions, [:tournament_id, :year])
end
```

- [ ] **Step 5: Run the migrations**

Run: `docker compose run --rm api mix ecto.migrate`
Expected: both migrations applied, exit code 0.

- [ ] **Step 6: Write the failing tests**

Create `apps/api/test/tennis_atlas_api/tournaments/tournament_test.exs`:

```elixir
defmodule TennisAtlasApi.Tournaments.TournamentTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments.Tournament
  alias TennisAtlasApi.Repo

  @valid_attrs %{
    name: "Roland Garros Fictif",
    slug: "roland-garros-fictif",
    category: :grand_slam,
    surface: :clay
  }

  test "changeset with valid attributes is valid" do
    changeset = Tournament.changeset(%Tournament{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset requires name, slug, category, surface" do
    changeset = Tournament.changeset(%Tournament{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.name == ["can't be blank"]
    assert errors.slug == ["can't be blank"]
    assert errors.category == ["can't be blank"]
    assert errors.surface == ["can't be blank"]
  end

  test "slug must be unique" do
    {:ok, _tournament} = Tournament.changeset(%Tournament{}, @valid_attrs) |> Repo.insert()

    {:error, changeset} =
      %Tournament{}
      |> Tournament.changeset(@valid_attrs)
      |> Repo.insert()

    assert %{slug: ["has already been taken"]} = errors_on(changeset)
  end
end
```

Create `apps/api/test/tennis_atlas_api/tournaments/tournament_edition_test.exs`:

```elixir
defmodule TennisAtlasApi.Tournaments.TournamentEditionTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Repo

  defp tournament_fixture do
    %Tournament{}
    |> Tournament.changeset(%{
      name: "Test Tournament",
      slug: "test-tournament-#{System.unique_integer([:positive])}",
      category: :atp_250,
      surface: :hard
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    tournament = tournament_fixture()

    changeset =
      TournamentEdition.changeset(%TournamentEdition{}, %{
        tournament_id: tournament.id,
        year: 2025,
        start_date: ~D[2025-05-25],
        end_date: ~D[2025-06-08]
      })

    assert changeset.valid?
  end

  test "changeset requires tournament_id, year, start_date, end_date" do
    changeset = TournamentEdition.changeset(%TournamentEdition{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.tournament_id == ["can't be blank"]
    assert errors.year == ["can't be blank"]
    assert errors.start_date == ["can't be blank"]
    assert errors.end_date == ["can't be blank"]
  end

  test "defaults status to :upcoming" do
    tournament = tournament_fixture()

    {:ok, edition} =
      %TournamentEdition{}
      |> TournamentEdition.changeset(%{
        tournament_id: tournament.id,
        year: 2025,
        start_date: ~D[2025-05-25],
        end_date: ~D[2025-06-08]
      })
      |> Repo.insert()

    assert edition.status == :upcoming
  end

  test "(tournament_id, year) must be unique" do
    tournament = tournament_fixture()

    attrs = %{
      tournament_id: tournament.id,
      year: 2025,
      start_date: ~D[2025-05-25],
      end_date: ~D[2025-06-08]
    }

    {:ok, _edition} = TournamentEdition.changeset(%TournamentEdition{}, attrs) |> Repo.insert()
    {:error, changeset} = TournamentEdition.changeset(%TournamentEdition{}, attrs) |> Repo.insert()

    assert %{tournament_id: ["has already been taken"]} = errors_on(changeset)
  end
end
```

- [ ] **Step 7: Run tests to verify they fail**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments/`
Expected: FAIL — modules undefined.

- [ ] **Step 8: Write the Tournament schema**

Create `apps/api/lib/tennis_atlas_api/tournaments/tournament.ex`:

```elixir
defmodule TennisAtlasApi.Tournaments.Tournament do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournaments" do
    field :name, :string
    field :slug, :string

    field :category, Ecto.Enum,
      values: [:grand_slam, :masters_1000, :atp_500, :atp_250, :wta_1000, :wta_500, :wta_250]

    field :surface, Ecto.Enum, values: [:clay, :grass, :hard, :indoor]
    field :description, :string
    field :logo_url, :string
    field :hero_image_url, :string

    belongs_to :venue, TennisAtlasApi.Venues.Venue
    has_many :editions, TennisAtlasApi.Tournaments.TournamentEdition

    timestamps()
  end

  @required_fields [:name, :slug, :category, :surface]
  @optional_fields [:venue_id, :description, :logo_url, :hero_image_url]

  def changeset(tournament, attrs) do
    tournament
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:venue_id)
  end
end
```

- [ ] **Step 9: Write the TournamentEdition schema**

Create `apps/api/lib/tennis_atlas_api/tournaments/tournament_edition.ex`:

```elixir
defmodule TennisAtlasApi.Tournaments.TournamentEdition do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournament_editions" do
    field :year, :integer
    field :start_date, :date
    field :end_date, :date

    field :status, Ecto.Enum,
      values: [:upcoming, :ongoing, :completed, :cancelled],
      default: :upcoming

    belongs_to :tournament, TennisAtlasApi.Tournaments.Tournament

    timestamps()
  end

  @required_fields [:tournament_id, :year, :start_date, :end_date]
  @optional_fields [:status]

  def changeset(tournament_edition, attrs) do
    tournament_edition
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:tournament_id)
    |> unique_constraint([:tournament_id, :year])
  end
end
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments/`
Expected: PASS, 7 tests, 0 failures.

- [ ] **Step 11: Commit**

```bash
git add apps/api/priv/repo/migrations apps/api/lib/tennis_atlas_api/tournaments apps/api/test/tennis_atlas_api/tournaments
git commit -m "feat: add Tournament and TournamentEdition schemas"
```

---

### Task 3: Player

**Files:**
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_players.exs`
- Create: `apps/api/lib/tennis_atlas_api/players/player.ex`
- Test: `apps/api/test/tennis_atlas_api/players/player_test.exs`

**Interfaces:**
- Consumes: nothing (no FK dependencies).
- Produces: `TennisAtlasApi.Players.Player` (fields: `first_name`, `last_name`, `slug`, `country_code`, `birth_date`, `hand` (`Ecto.Enum` `:left/:right`), `height_cm`, `current_ranking`, `current_ranking_points`). Tasks 4, 5, 6, 7 reference this by FK.

- [ ] **Step 1: Generate the migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_players`

- [ ] **Step 2: Write the migration**

```elixir
def change do
  create table(:players) do
    add :first_name, :string, null: false
    add :last_name, :string, null: false
    add :slug, :string, null: false
    add :country_code, :string, null: false
    add :birth_date, :date
    add :hand, :string
    add :height_cm, :integer
    add :current_ranking, :integer
    add :current_ranking_points, :integer

    timestamps()
  end

  create unique_index(:players, [:slug])
end
```

- [ ] **Step 3: Run the migration**

Run: `docker compose run --rm api mix ecto.migrate`

- [ ] **Step 4: Write the failing test**

Create `apps/api/test/tennis_atlas_api/players/player_test.exs`:

```elixir
defmodule TennisAtlasApi.Players.PlayerTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Players.Player
  alias TennisAtlasApi.Repo

  @valid_attrs %{
    first_name: "Mateo",
    last_name: "Rivera",
    slug: "mateo-rivera",
    country_code: "ESP"
  }

  test "changeset with valid attributes is valid" do
    changeset = Player.changeset(%Player{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset requires first_name, last_name, slug, country_code" do
    changeset = Player.changeset(%Player{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.first_name == ["can't be blank"]
    assert errors.last_name == ["can't be blank"]
    assert errors.slug == ["can't be blank"]
    assert errors.country_code == ["can't be blank"]
  end

  test "slug must be unique" do
    {:ok, _player} = Player.changeset(%Player{}, @valid_attrs) |> Repo.insert()

    {:error, changeset} = Player.changeset(%Player{}, @valid_attrs) |> Repo.insert()

    assert %{slug: ["has already been taken"]} = errors_on(changeset)
  end

  test "rejects an invalid hand value" do
    changeset = Player.changeset(%Player{}, Map.put(@valid_attrs, :hand, :ambidextrous))

    refute changeset.valid?
    assert %{hand: ["is invalid"]} = errors_on(changeset)
  end
end
```

- [ ] **Step 5: Run test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players/player_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 6: Write the Player schema**

Create `apps/api/lib/tennis_atlas_api/players/player.ex`:

```elixir
defmodule TennisAtlasApi.Players.Player do
  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :first_name, :string
    field :last_name, :string
    field :slug, :string
    field :country_code, :string
    field :birth_date, :date
    field :hand, Ecto.Enum, values: [:left, :right]
    field :height_cm, :integer
    field :current_ranking, :integer
    field :current_ranking_points, :integer

    timestamps()
  end

  @required_fields [:first_name, :last_name, :slug, :country_code]
  @optional_fields [:birth_date, :hand, :height_cm, :current_ranking, :current_ranking_points]

  def changeset(player, attrs) do
    player
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:slug)
  end
end
```

- [ ] **Step 7: Run test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players/player_test.exs`
Expected: PASS, 4 tests, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add apps/api/priv/repo/migrations apps/api/lib/tennis_atlas_api/players apps/api/test/tennis_atlas_api/players
git commit -m "feat: add Player schema"
```

---

### Task 4: TournamentEntry

**Files:**
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_tournament_entries.exs`
- Create: `apps/api/lib/tennis_atlas_api/tournaments/tournament_entry.ex`
- Test: `apps/api/test/tennis_atlas_api/tournaments/tournament_entry_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.Tournaments.TournamentEdition` (Task 2) via `tournament_edition_id`, `TennisAtlasApi.Players.Player` (Task 3) via `player_id`.
- Produces: `TennisAtlasApi.Tournaments.TournamentEntry` (fields: `tournament_edition_id`, `player_id`, `tour` (`Ecto.Enum` `:atp/:wta`), `seed`, `entry_type` (`Ecto.Enum` `:direct/:qualifier/:wildcard/:lucky_loser`, default `:direct`), `status` (`Ecto.Enum` `:active/:withdrawn`, default `:active`)). Task 7 (seeds) calls `TournamentEntry.changeset/2` directly.

- [ ] **Step 1: Generate the migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_tournament_entries`

- [ ] **Step 2: Write the migration**

```elixir
def change do
  create table(:tournament_entries) do
    add :tournament_edition_id, references(:tournament_editions, on_delete: :delete_all), null: false
    add :player_id, references(:players, on_delete: :delete_all), null: false
    add :tour, :string, null: false
    add :seed, :integer
    add :entry_type, :string, null: false, default: "direct"
    add :status, :string, null: false, default: "active"

    timestamps()
  end

  create unique_index(:tournament_entries, [:tournament_edition_id, :player_id])
  create index(:tournament_entries, [:player_id])
end
```

- [ ] **Step 3: Run the migration**

Run: `docker compose run --rm api mix ecto.migrate`

- [ ] **Step 4: Write the failing test**

Create `apps/api/test/tennis_atlas_api/tournaments/tournament_entry_test.exs`:

```elixir
defmodule TennisAtlasApi.Tournaments.TournamentEntryTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition, TournamentEntry}
  alias TennisAtlasApi.Players.Player
  alias TennisAtlasApi.Repo

  defp edition_fixture do
    tournament =
      %Tournament{}
      |> Tournament.changeset(%{
        name: "Test Tournament",
        slug: "test-tournament-#{System.unique_integer([:positive])}",
        category: :atp_250,
        surface: :hard
      })
      |> Repo.insert!()

    %TournamentEdition{}
    |> TournamentEdition.changeset(%{
      tournament_id: tournament.id,
      year: 2025,
      start_date: ~D[2025-01-01],
      end_date: ~D[2025-01-08]
    })
    |> Repo.insert!()
  end

  defp player_fixture do
    %Player{}
    |> Player.changeset(%{
      first_name: "Test",
      last_name: "Player",
      slug: "test-player-#{System.unique_integer([:positive])}",
      country_code: "FRA"
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    edition = edition_fixture()
    player = player_fixture()

    changeset =
      TournamentEntry.changeset(%TournamentEntry{}, %{
        tournament_edition_id: edition.id,
        player_id: player.id,
        tour: :atp,
        seed: 1
      })

    assert changeset.valid?
  end

  test "changeset requires tournament_edition_id, player_id, tour" do
    changeset = TournamentEntry.changeset(%TournamentEntry{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.tournament_edition_id == ["can't be blank"]
    assert errors.player_id == ["can't be blank"]
    assert errors.tour == ["can't be blank"]
  end

  test "(tournament_edition_id, player_id) must be unique" do
    edition = edition_fixture()
    player = player_fixture()
    attrs = %{tournament_edition_id: edition.id, player_id: player.id, tour: :atp}

    {:ok, _entry} = TournamentEntry.changeset(%TournamentEntry{}, attrs) |> Repo.insert()
    {:error, changeset} = TournamentEntry.changeset(%TournamentEntry{}, attrs) |> Repo.insert()

    assert %{tournament_edition_id: ["has already been taken"]} = errors_on(changeset)
  end

  test "defaults entry_type to :direct and status to :active" do
    edition = edition_fixture()
    player = player_fixture()

    {:ok, entry} =
      %TournamentEntry{}
      |> TournamentEntry.changeset(%{
        tournament_edition_id: edition.id,
        player_id: player.id,
        tour: :wta
      })
      |> Repo.insert()

    assert entry.entry_type == :direct
    assert entry.status == :active
  end
end
```

- [ ] **Step 5: Run test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments/tournament_entry_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 6: Write the TournamentEntry schema**

Create `apps/api/lib/tennis_atlas_api/tournaments/tournament_entry.ex`:

```elixir
defmodule TennisAtlasApi.Tournaments.TournamentEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tournament_entries" do
    field :tour, Ecto.Enum, values: [:atp, :wta]
    field :seed, :integer
    field :entry_type, Ecto.Enum, values: [:direct, :qualifier, :wildcard, :lucky_loser], default: :direct
    field :status, Ecto.Enum, values: [:active, :withdrawn], default: :active

    belongs_to :tournament_edition, TennisAtlasApi.Tournaments.TournamentEdition
    belongs_to :player, TennisAtlasApi.Players.Player

    timestamps()
  end

  @required_fields [:tournament_edition_id, :player_id, :tour]
  @optional_fields [:seed, :entry_type, :status]

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:tournament_edition_id)
    |> foreign_key_constraint(:player_id)
    |> unique_constraint([:tournament_edition_id, :player_id])
  end
end
```

- [ ] **Step 7: Run test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments/tournament_entry_test.exs`
Expected: PASS, 4 tests, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add apps/api/priv/repo/migrations apps/api/lib/tennis_atlas_api/tournaments/tournament_entry.ex apps/api/test/tennis_atlas_api/tournaments/tournament_entry_test.exs
git commit -m "feat: add TournamentEntry schema"
```

---

### Task 5: Match + Set

**Files:**
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_matches.exs`
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_sets.exs`
- Create: `apps/api/lib/tennis_atlas_api/matches/match.ex`
- Create: `apps/api/lib/tennis_atlas_api/matches/set.ex`
- Test: `apps/api/test/tennis_atlas_api/matches/match_test.exs`
- Test: `apps/api/test/tennis_atlas_api/matches/set_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.Tournaments.TournamentEdition` (Task 2), `TennisAtlasApi.Players.Player` (Task 3), `TennisAtlasApi.Venues.Court` (Task 1).
- Produces: `TennisAtlasApi.Matches.Match` (fields: `tournament_edition_id`, `tour`, `round` (`Ecto.Enum` `:r128/:r64/:r32/:r16/:qf/:sf/:f`), `player_a_id`, `player_b_id`, `court_id`, `scheduled_at`, `started_at`, `finished_at`, `status` (`Ecto.Enum` `:scheduled/:live/:finished/:retired/:walkover/:cancelled`, default `:scheduled`), `winner_id`, `best_of` default `3`) and `TennisAtlasApi.Matches.Set` (fields: `match_id`, `set_number`, `player_a_games`, `player_b_games`, `tiebreak_a`, `tiebreak_b`). Task 7 (seeds) calls both `changeset/2` functions directly.

- [ ] **Step 1: Generate the matches migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_matches`

- [ ] **Step 2: Write the matches migration**

```elixir
def change do
  create table(:matches) do
    add :tournament_edition_id, references(:tournament_editions, on_delete: :delete_all), null: false
    add :tour, :string, null: false
    add :round, :string, null: false
    add :player_a_id, references(:players, on_delete: :nilify_all)
    add :player_b_id, references(:players, on_delete: :nilify_all)
    add :court_id, references(:courts, on_delete: :nilify_all)
    add :scheduled_at, :utc_datetime
    add :started_at, :utc_datetime
    add :finished_at, :utc_datetime
    add :status, :string, null: false, default: "scheduled"
    add :winner_id, references(:players, on_delete: :nilify_all)
    add :best_of, :integer, null: false, default: 3

    timestamps()
  end

  create index(:matches, [:tournament_edition_id])
  create index(:matches, [:player_a_id])
  create index(:matches, [:player_b_id])
  create index(:matches, [:status])
end
```

- [ ] **Step 3: Generate the sets migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_sets`

- [ ] **Step 4: Write the sets migration**

```elixir
def change do
  create table(:sets) do
    add :match_id, references(:matches, on_delete: :delete_all), null: false
    add :set_number, :integer, null: false
    add :player_a_games, :integer, null: false
    add :player_b_games, :integer, null: false
    add :tiebreak_a, :integer
    add :tiebreak_b, :integer

    timestamps()
  end

  create unique_index(:sets, [:match_id, :set_number])
end
```

- [ ] **Step 5: Run the migrations**

Run: `docker compose run --rm api mix ecto.migrate`

- [ ] **Step 6: Write the failing tests**

Create `apps/api/test/tennis_atlas_api/matches/match_test.exs`:

```elixir
defmodule TennisAtlasApi.Matches.MatchTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Matches.Match
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Repo

  defp edition_fixture do
    tournament =
      %Tournament{}
      |> Tournament.changeset(%{
        name: "Test Tournament",
        slug: "test-tournament-#{System.unique_integer([:positive])}",
        category: :atp_250,
        surface: :hard
      })
      |> Repo.insert!()

    %TournamentEdition{}
    |> TournamentEdition.changeset(%{
      tournament_id: tournament.id,
      year: 2025,
      start_date: ~D[2025-01-01],
      end_date: ~D[2025-01-08]
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    edition = edition_fixture()

    changeset = Match.changeset(%Match{}, %{tournament_edition_id: edition.id, tour: :atp, round: :f})

    assert changeset.valid?
  end

  test "changeset requires tournament_edition_id, tour, round" do
    changeset = Match.changeset(%Match{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.tournament_edition_id == ["can't be blank"]
    assert errors.tour == ["can't be blank"]
    assert errors.round == ["can't be blank"]
  end

  test "defaults status to :scheduled and best_of to 3" do
    edition = edition_fixture()

    {:ok, match} =
      %Match{}
      |> Match.changeset(%{tournament_edition_id: edition.id, tour: :atp, round: :qf})
      |> Repo.insert()

    assert match.status == :scheduled
    assert match.best_of == 3
  end

  test "rejects an invalid round value" do
    edition = edition_fixture()

    changeset =
      Match.changeset(%Match{}, %{tournament_edition_id: edition.id, tour: :atp, round: :round_of_64})

    refute changeset.valid?
    assert %{round: ["is invalid"]} = errors_on(changeset)
  end
end
```

Create `apps/api/test/tennis_atlas_api/matches/set_test.exs`:

```elixir
defmodule TennisAtlasApi.Matches.SetTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Matches.{Match, Set}
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Repo

  defp match_fixture do
    tournament =
      %Tournament{}
      |> Tournament.changeset(%{
        name: "Test Tournament",
        slug: "test-tournament-#{System.unique_integer([:positive])}",
        category: :atp_250,
        surface: :hard
      })
      |> Repo.insert!()

    edition =
      %TournamentEdition{}
      |> TournamentEdition.changeset(%{
        tournament_id: tournament.id,
        year: 2025,
        start_date: ~D[2025-01-01],
        end_date: ~D[2025-01-08]
      })
      |> Repo.insert!()

    %Match{}
    |> Match.changeset(%{tournament_edition_id: edition.id, tour: :atp, round: :f})
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    match = match_fixture()

    changeset =
      Set.changeset(%Set{}, %{match_id: match.id, set_number: 1, player_a_games: 6, player_b_games: 4})

    assert changeset.valid?
  end

  test "changeset requires match_id, set_number, player_a_games, player_b_games" do
    changeset = Set.changeset(%Set{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.match_id == ["can't be blank"]
    assert errors.set_number == ["can't be blank"]
    assert errors.player_a_games == ["can't be blank"]
    assert errors.player_b_games == ["can't be blank"]
  end

  test "(match_id, set_number) must be unique" do
    match = match_fixture()
    attrs = %{match_id: match.id, set_number: 1, player_a_games: 6, player_b_games: 4}

    {:ok, _set} = Set.changeset(%Set{}, attrs) |> Repo.insert()
    {:error, changeset} = Set.changeset(%Set{}, attrs) |> Repo.insert()

    assert %{match_id: ["has already been taken"]} = errors_on(changeset)
  end
end
```

- [ ] **Step 7: Run tests to verify they fail**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/matches/`
Expected: FAIL — modules undefined.

- [ ] **Step 8: Write the Match schema**

Create `apps/api/lib/tennis_atlas_api/matches/match.ex`:

```elixir
defmodule TennisAtlasApi.Matches.Match do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matches" do
    field :tour, Ecto.Enum, values: [:atp, :wta]
    field :round, Ecto.Enum, values: [:r128, :r64, :r32, :r16, :qf, :sf, :f]
    field :scheduled_at, :utc_datetime
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    field :status, Ecto.Enum,
      values: [:scheduled, :live, :finished, :retired, :walkover, :cancelled],
      default: :scheduled

    field :best_of, :integer, default: 3

    belongs_to :tournament_edition, TennisAtlasApi.Tournaments.TournamentEdition
    belongs_to :player_a, TennisAtlasApi.Players.Player
    belongs_to :player_b, TennisAtlasApi.Players.Player
    belongs_to :winner, TennisAtlasApi.Players.Player
    belongs_to :court, TennisAtlasApi.Venues.Court

    has_many :sets, TennisAtlasApi.Matches.Set

    timestamps()
  end

  @required_fields [:tournament_edition_id, :tour, :round]
  @optional_fields [
    :player_a_id,
    :player_b_id,
    :court_id,
    :scheduled_at,
    :started_at,
    :finished_at,
    :status,
    :winner_id,
    :best_of
  ]

  def changeset(match, attrs) do
    match
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:tournament_edition_id)
    |> foreign_key_constraint(:player_a_id)
    |> foreign_key_constraint(:player_b_id)
    |> foreign_key_constraint(:court_id)
    |> foreign_key_constraint(:winner_id)
  end
end
```

- [ ] **Step 9: Write the Set schema**

Create `apps/api/lib/tennis_atlas_api/matches/set.ex`:

```elixir
defmodule TennisAtlasApi.Matches.Set do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sets" do
    field :set_number, :integer
    field :player_a_games, :integer
    field :player_b_games, :integer
    field :tiebreak_a, :integer
    field :tiebreak_b, :integer

    belongs_to :match, TennisAtlasApi.Matches.Match

    timestamps()
  end

  @required_fields [:match_id, :set_number, :player_a_games, :player_b_games]
  @optional_fields [:tiebreak_a, :tiebreak_b]

  def changeset(set, attrs) do
    set
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:match_id)
    |> unique_constraint([:match_id, :set_number])
  end
end
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/matches/`
Expected: PASS, 7 tests, 0 failures.

- [ ] **Step 11: Commit**

```bash
git add apps/api/priv/repo/migrations apps/api/lib/tennis_atlas_api/matches apps/api/test/tennis_atlas_api/matches
git commit -m "feat: add Match and Set schemas"
```

---

### Task 6: Ranking

**Files:**
- Create: `apps/api/priv/repo/migrations/<timestamp>_create_rankings.exs`
- Create: `apps/api/lib/tennis_atlas_api/players/ranking.ex`
- Test: `apps/api/test/tennis_atlas_api/players/ranking_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.Players.Player` (Task 3) via `player_id`.
- Produces: `TennisAtlasApi.Players.Ranking` (fields: `player_id`, `ranking_type` (`Ecto.Enum` `:atp/:wta`), `position`, `points`, `as_of_date`). Task 7 (seeds) calls `Ranking.changeset/2` directly.

- [ ] **Step 1: Generate the migration**

Run: `docker compose run --rm api mix ecto.gen.migration create_rankings`

- [ ] **Step 2: Write the migration**

```elixir
def change do
  create table(:rankings) do
    add :player_id, references(:players, on_delete: :delete_all), null: false
    add :ranking_type, :string, null: false
    add :position, :integer, null: false
    add :points, :integer, null: false
    add :as_of_date, :date, null: false

    timestamps()
  end

  create unique_index(:rankings, [:player_id, :ranking_type, :as_of_date])
end
```

- [ ] **Step 3: Run the migration**

Run: `docker compose run --rm api mix ecto.migrate`

- [ ] **Step 4: Write the failing test**

Create `apps/api/test/tennis_atlas_api/players/ranking_test.exs`:

```elixir
defmodule TennisAtlasApi.Players.RankingTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Players.{Player, Ranking}
  alias TennisAtlasApi.Repo

  defp player_fixture do
    %Player{}
    |> Player.changeset(%{
      first_name: "Test",
      last_name: "Player",
      slug: "test-player-#{System.unique_integer([:positive])}",
      country_code: "FRA"
    })
    |> Repo.insert!()
  end

  test "changeset with valid attributes is valid" do
    player = player_fixture()

    changeset =
      Ranking.changeset(%Ranking{}, %{
        player_id: player.id,
        ranking_type: :atp,
        position: 1,
        points: 10_000,
        as_of_date: ~D[2025-06-01]
      })

    assert changeset.valid?
  end

  test "changeset requires all fields" do
    changeset = Ranking.changeset(%Ranking{}, %{})

    refute changeset.valid?
    errors = errors_on(changeset)
    assert errors.player_id == ["can't be blank"]
    assert errors.ranking_type == ["can't be blank"]
    assert errors.position == ["can't be blank"]
    assert errors.points == ["can't be blank"]
    assert errors.as_of_date == ["can't be blank"]
  end

  test "(player_id, ranking_type, as_of_date) must be unique" do
    player = player_fixture()

    attrs = %{
      player_id: player.id,
      ranking_type: :atp,
      position: 1,
      points: 10_000,
      as_of_date: ~D[2025-06-01]
    }

    {:ok, _ranking} = Ranking.changeset(%Ranking{}, attrs) |> Repo.insert()
    {:error, changeset} = Ranking.changeset(%Ranking{}, attrs) |> Repo.insert()

    assert %{player_id: ["has already been taken"]} = errors_on(changeset)
  end
end
```

- [ ] **Step 5: Run test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players/ranking_test.exs`
Expected: FAIL — module undefined.

- [ ] **Step 6: Write the Ranking schema**

Create `apps/api/lib/tennis_atlas_api/players/ranking.ex`:

```elixir
defmodule TennisAtlasApi.Players.Ranking do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rankings" do
    field :ranking_type, Ecto.Enum, values: [:atp, :wta]
    field :position, :integer
    field :points, :integer
    field :as_of_date, :date

    belongs_to :player, TennisAtlasApi.Players.Player

    timestamps()
  end

  @required_fields [:player_id, :ranking_type, :position, :points, :as_of_date]

  def changeset(ranking, attrs) do
    ranking
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:player_id)
    |> unique_constraint([:player_id, :ranking_type, :as_of_date])
  end
end
```

- [ ] **Step 7: Run test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players/ranking_test.exs`
Expected: PASS, 3 tests, 0 failures.

- [ ] **Step 8: Commit**

```bash
git add apps/api/priv/repo/migrations apps/api/lib/tennis_atlas_api/players/ranking.ex apps/api/test/tennis_atlas_api/players/ranking_test.exs
git commit -m "feat: add Ranking schema"
```

---

### Task 7: Seeds

**Files:**
- Modify: `apps/api/priv/repo/seeds.exs`

**Interfaces:**
- Consumes: all schemas from Tasks 1-6 (`Venue`, `Court`, `Tournament`, `TournamentEdition`, `Player`, `TournamentEntry`, `Match`, `Set`, `Ranking`).
- Produces: a populated dev database — 3 venues, 3 courts, 3 tournaments, 3 editions, 16 players, 48 tournament entries (16 players × 3 tournaments — see step 1 note on reuse), 21 matches (7 per tournament), ~54 sets, 16 ranking snapshots. Nothing downstream in this plan depends on this data programmatically; it's for manual verification (Task 8) and for Phase 4+ frontend work.

- [ ] **Step 1: Replace `priv/repo/seeds.exs`**

Open `apps/api/priv/repo/seeds.exs` and replace its full contents with:

```elixir
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
```

- [ ] **Step 2: Run the seeds against a fresh database**

Run: `docker compose run --rm api mix ecto.reset && docker compose run --rm api mix run priv/repo/seeds.exs`
Expected: exit code 0, final line printed: `Seeded 3 venues, 3 courts, 3 tournaments, 3 editions, 16 players, 21 matches.`

- [ ] **Step 3: Spot-check row counts**

Run:

```bash
docker compose run --rm api mix run -e '
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Matches.{Match, Set}
  alias TennisAtlasApi.Players.Player
  alias TennisAtlasApi.Tournaments.TournamentEntry
  import Ecto.Query

  IO.puts("players: #{Repo.aggregate(Player, :count)}")
  IO.puts("matches: #{Repo.aggregate(Match, :count)}")
  IO.puts("sets: #{Repo.aggregate(Set, :count)}")
  IO.puts("entries: #{Repo.aggregate(TournamentEntry, :count)}")
'
```

Expected: `players: 16`, `matches: 21`, `entries: 48`, `sets: 49` (Roland Garros is best_of: 5 → 3 sets × 7 matches = 21; Wimbledon and the NY Open are best_of: 3 → 2 sets × 7 matches × 2 tournaments = 28; 21 + 28 = 49).

- [ ] **Step 4: Commit**

```bash
git add apps/api/priv/repo/seeds.exs
git commit -m "feat: add fictional seed dataset (3 tournaments, 16 players, 21 matches)"
```

---

### Task 8: Final verification

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: everything from Tasks 1-7.
- Produces: confirmation that the full migration suite is reversible, the full test suite passes together, and seeding works from a clean slate — plus a README pointer so a future developer (or the Phase 3 implementer) knows how to load demo data.

- [ ] **Step 1: Run the full test suite**

Run: `docker compose run --rm api mix test`
Expected: all tests pass (Phase 1's health controller test + all Phase 2 schema tests — 33 tests total: 5 Venue/Court + 7 Tournament/Edition + 4 Player + 4 TournamentEntry + 7 Match/Set + 3 Ranking + 1 health + whatever Phase 1 already had), 0 failures, pristine output (no warnings).

- [ ] **Step 2: Verify every migration is reversible**

Run: `docker compose run --rm api mix ecto.rollback --all`
Expected: exit code 0, all 9 Phase 2 migrations (plus nothing from Phase 1, which had none) rolled back without error.

Run: `docker compose run --rm api mix ecto.migrate`
Expected: exit code 0, all migrations re-applied.

- [ ] **Step 3: Verify the clean-slate seed path**

Run: `docker compose run --rm api mix ecto.reset && docker compose run --rm api mix run priv/repo/seeds.exs`
Expected: exit code 0, same success message as Task 7 Step 2.

- [ ] **Step 4: Add a README note on seeding**

Open `README.md`, find the `## Développement local` section, and add this line after the existing `docker compose up` instructions (before the "API : ..." / "Web : ..." bullet list, or right after it — place it so the section reads naturally):

```markdown
Pour charger des données de démonstration (fictives) :

```bash
docker compose run --rm api mix run priv/repo/seeds.exs
```
```

- [ ] **Step 5: Stop the stack**

Run: `docker compose down`

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "docs: document seed data loading"
```

Phase 2 is complete once this task's three verification steps (full suite, migration rollback/reapply roundtrip, clean-slate seed run) all pass.
