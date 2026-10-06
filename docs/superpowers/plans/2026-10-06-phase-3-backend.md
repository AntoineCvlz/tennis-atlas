# Tennis Atlas — Phase 3 : Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four read-only REST resources (Tournaments, Players, Matches, Rankings) backed by Phoenix contexts, with pagination, query-param validation, and a consistent JSON/error contract — proving the Phase 2 schema is queryable through a real API. No write endpoints, no frontend consumption, no Oban — those are later phases.

**Architecture:** Each resource gets context query functions added to its existing namespace module (`Tournaments`, `Players`, `Matches`), a native Phoenix JSON view, and a controller wired through a shared `QueryParams` validator and `FallbackController` for 422s. 404s fall through to Phoenix's existing `Ecto.NoResultsError` → `ErrorJSON` path, unchanged since Phase 1 — no new code needed for that case. A hand-rolled `Pagination` helper and a `test/support/fixtures/` convention (one module per schema) are introduced once, in the earliest task that needs them, and reused by every later task.

**Tech Stack:** Phoenix contexts & controllers, Ecto (query composition, `Ecto.ParameterizedType.init(Ecto.Enum, ...)` for schemaless query-param casting), native Phoenix JSON views, ExUnit + `Phoenix.ConnTest`.

**Spec:** [docs/superpowers/specs/2026-10-06-phase-3-backend-design.md](../specs/2026-10-06-phase-3-backend-design.md) (routes, contexts, pagination, filters, error contract) and [docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md](../specs/2026-10-05-tennis-atlas-architecture-design.md) (project-wide architecture).

## Global Constraints

- This phase exposes **read-only** endpoints only (`GET`) — no `POST`/`PUT`/`PATCH`/`DELETE` route is added to the router, per the architecture spec's read-via-REST / write-via-contexts split.
- JSON response keys stay **snake_case**, identical to Ecto column names — no case transformation anywhere.
- Pagination is a **hand-rolled helper**, not a library: `page` (default 1), `page_size` (default 20, max 100 — values above 100 are silently capped, not rejected).
- Context functions live in the **existing namespace modules** created in Phase 2 (`Tournaments`, `Players`, `Matches`) — no new context module names.
- `Venue` and `Court` have **no dedicated endpoints** — they only ever appear nested inside `Tournament`/`Match` JSON responses.
- `GET /api/rankings` **requires** the `ranking_type` filter — 422 if absent, never an unfiltered mix of ATP and WTA rows.
- 404 for a missing resource is Phoenix's default `Ecto.NoResultsError` → `ErrorJSON` path (already configured since Phase 1) — do not add `try`/`rescue` or any new code for this case; raising `Ecto.NoResultsError` from a context's `get_*!` function is sufficient.
- 422 for invalid/missing query params goes through `TennisAtlasApiWeb.FallbackController` + `ChangesetJSON`, built once in Task 2 and reused by every controller from Task 3 onward.
- All commands run via `docker compose run --rm api <cmd>` — no local Elixir install assumed (same as Phases 1–2).

## Review Focus

- Non-numeric `:id` on `GET /api/matches/:id` (e.g. `/api/matches/not-a-number`) must return 404, not crash with an unhandled `Ecto.Query.CastError` (500) — `Repo.get!/2` raises a non-`Plug.Exception` error on a bad integer cast, which Phoenix would otherwise turn into a bare 500. Pinned in Task 6.
- An invalid enum value on any filter query param (e.g. `?surface=nope`) must return 422 with a field-level error, not be silently ignored or crash. Pinned in Task 3.
- `GET /api/rankings` with no `ranking_type` must return 422, never fall back to returning every ranking row across both tours. Pinned in Task 7.
- A `page` number past the last page (e.g. `page=999` on a handful of rows) must return an empty `data` array with correct `meta`, not an error. Pinned in Task 1.
- A `page_size` above the cap (e.g. `page_size=500`) must be silently capped at 100, not honored as-is (which would let a client force an unbounded query) and not rejected as invalid. Pinned in Task 1.

---

### Task 1: Pagination helper

**Files:**
- Create: `apps/api/lib/tennis_atlas_api/pagination.ex`
- Test: `apps/api/test/tennis_atlas_api/pagination_test.exs`

**Interfaces:**
- Consumes: nothing new (uses `TennisAtlasApi.Repo` and `TennisAtlasApi.Venues.Venue`, both from Phase 1/2, only inside this task's own test).
- Produces: `TennisAtlasApi.Pagination.paginate(queryable, repo, opts \\ [])` → `%{entries: [...], page: integer, page_size: integer, total_count: integer, total_pages: integer}`. Every context function from Task 3 onward calls this.

- [ ] **Step 1: Write the failing test**

Create `apps/api/test/tennis_atlas_api/pagination_test.exs`:

```elixir
defmodule TennisAtlasApi.PaginationTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Venues.Venue

  defp insert_venues(count) do
    for n <- 1..count do
      %Venue{}
      |> Venue.changeset(%{name: "Venue #{n}", city: "City", country_code: "FRA"})
      |> Repo.insert!()
    end
  end

  test "paginates the first page" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 1, page_size: 2)

    assert length(result.entries) == 2
    assert result.page == 1
    assert result.page_size == 2
    assert result.total_count == 5
    assert result.total_pages == 3
  end

  test "paginates a partial last page" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 3, page_size: 2)

    assert length(result.entries) == 1
    assert result.total_pages == 3
  end

  test "returns an empty page past the end instead of erroring" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 10, page_size: 2)

    assert result.entries == []
    assert result.total_count == 5
  end

  test "caps page_size at 100" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo, page: 1, page_size: 500)

    assert result.page_size == 100
    assert length(result.entries) == 5
  end

  test "defaults to page 1 and page_size 20 when opts are omitted" do
    insert_venues(5)
    query = from(v in Venue, order_by: [asc: v.id])

    result = Pagination.paginate(query, Repo)

    assert result.page == 1
    assert result.page_size == 20
  end
end
```

`from/2` and `Repo` are available here via `TennisAtlasApi.DataCase`'s `using` block, which already imports `Ecto.Query` and aliases `TennisAtlasApi.Repo`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/pagination_test.exs`
Expected: FAIL — `TennisAtlasApi.Pagination` is undefined.

- [ ] **Step 3: Implement the pagination helper**

Create `apps/api/lib/tennis_atlas_api/pagination.ex`:

```elixir
defmodule TennisAtlasApi.Pagination do
  import Ecto.Query

  @default_page 1
  @default_page_size 20
  @max_page_size 100

  def paginate(queryable, repo, opts \\ []) do
    page = opts |> Keyword.get(:page, @default_page) |> max(1)

    page_size =
      opts
      |> Keyword.get(:page_size, @default_page_size)
      |> min(@max_page_size)
      |> max(1)

    total_count = repo.aggregate(queryable, :count)
    total_pages = ceil(total_count / page_size)

    entries =
      queryable
      |> limit(^page_size)
      |> offset(^((page - 1) * page_size))
      |> repo.all()

    %{
      entries: entries,
      page: page,
      page_size: page_size,
      total_count: total_count,
      total_pages: total_pages
    }
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/pagination_test.exs`
Expected: PASS (5 tests, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add apps/api/lib/tennis_atlas_api/pagination.ex apps/api/test/tennis_atlas_api/pagination_test.exs
git commit -m "feat: add pagination helper"
```

---

### Task 2: Shared request/response plumbing

**Files:**
- Create: `apps/api/lib/tennis_atlas_api_web/query_params.ex`
- Test: `apps/api/test/tennis_atlas_api_web/query_params_test.exs`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/fallback_controller.ex`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/changeset_json.ex`

**Interfaces:**
- Consumes: nothing new.
- Produces: `TennisAtlasApiWeb.QueryParams.cast(params, types \\ %{}, required \\ [])` → `{:ok, map}` (always has integer `:page`/`:page_size` keys, defaulted to 1/20) or `{:error, %Ecto.Changeset{}}`. `TennisAtlasApiWeb.FallbackController`, registered via `action_fallback` in every resource controller from Task 3 onward, maps `{:error, %Ecto.Changeset{}}` to a 422 response rendered by `TennisAtlasApiWeb.ChangesetJSON.error/1`. Neither `FallbackController` nor `ChangesetJSON` has a dedicated test in this task — they have no observable behavior in isolation; Task 3's "returns 422 for an invalid surface filter" test is their first real exercise.

- [ ] **Step 1: Write the failing test for QueryParams**

Create `apps/api/test/tennis_atlas_api_web/query_params_test.exs`:

```elixir
defmodule TennisAtlasApiWeb.QueryParamsTest do
  use ExUnit.Case, async: true

  alias TennisAtlasApiWeb.QueryParams

  test "defaults page and page_size when absent" do
    assert {:ok, %{page: 1, page_size: 20}} = QueryParams.cast(%{})
  end

  test "casts page and page_size from string params" do
    assert {:ok, %{page: 2, page_size: 50}} = QueryParams.cast(%{"page" => "2", "page_size" => "50"})
  end

  test "rejects page below 1" do
    assert {:error, changeset} = QueryParams.cast(%{"page" => "0"})
    refute changeset.valid?
  end

  test "rejects a non-numeric page" do
    assert {:error, _changeset} = QueryParams.cast(%{"page" => "abc"})
  end

  test "casts extra typed fields and leaves them nil when absent" do
    types = %{surface: Ecto.ParameterizedType.init(Ecto.Enum, values: [:clay, :grass, :hard, :indoor])}

    assert {:ok, %{surface: nil}} = QueryParams.cast(%{}, types)
    assert {:ok, %{surface: :clay}} = QueryParams.cast(%{"surface" => "clay"}, types)
    assert {:error, changeset} = QueryParams.cast(%{"surface" => "nope"}, types)
    assert %{surface: ["is invalid"]} = errors_on(changeset)
  end

  test "enforces required fields" do
    assert {:error, changeset} = QueryParams.cast(%{}, %{ranking_type: :string}, [:ranking_type])
    assert %{ranking_type: ["can't be blank"]} = errors_on(changeset)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
```

This is a plain `ExUnit.Case` (not `DataCase`) — `QueryParams.cast/3` never touches the database.

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/query_params_test.exs`
Expected: FAIL — `TennisAtlasApiWeb.QueryParams` is undefined.

- [ ] **Step 3: Implement QueryParams**

Create `apps/api/lib/tennis_atlas_api_web/query_params.ex`:

```elixir
defmodule TennisAtlasApiWeb.QueryParams do
  # `cast/3` is this module's own public API, so import everything from
  # Ecto.Changeset *except* its own `cast/3` — otherwise the import would
  # shadow this function and calling `cast/3` below would recurse into
  # itself instead of reaching Ecto.Changeset.cast/3.
  import Ecto.Changeset, except: [cast: 3]

  @pagination_types %{page: :integer, page_size: :integer}
  @pagination_defaults %{page: 1, page_size: 20}

  def cast(params, types \\ %{}, required \\ []) do
    all_types = Map.merge(@pagination_types, types)

    # Every key in `all_types` must exist in `data`, even as nil — otherwise
    # `apply_changes/1` below omits any filter the caller didn't supply
    # instead of returning it as `nil`, and callers matching on e.g.
    # `%{surface: nil}` would fail against a map missing the key entirely.
    data =
      all_types
      |> Map.new(fn {key, _type} -> {key, nil} end)
      |> Map.merge(@pagination_defaults)

    changeset =
      {data, all_types}
      |> Ecto.Changeset.cast(params, Map.keys(all_types))
      |> validate_number(:page, greater_than: 0)
      |> validate_number(:page_size, greater_than: 0)
      |> validate_required(required)

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/query_params_test.exs`
Expected: PASS (6 tests, 0 failures).

- [ ] **Step 5: Commit QueryParams**

```bash
git add apps/api/lib/tennis_atlas_api_web/query_params.ex apps/api/test/tennis_atlas_api_web/query_params_test.exs
git commit -m "feat: add QueryParams query-string validator"
```

- [ ] **Step 6: Add FallbackController and ChangesetJSON**

Create `apps/api/lib/tennis_atlas_api_web/controllers/changeset_json.ex`:

```elixir
defmodule TennisAtlasApiWeb.ChangesetJSON do
  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp translate_error({msg, opts}) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
```

Create `apps/api/lib/tennis_atlas_api_web/controllers/fallback_controller.ex`:

```elixir
defmodule TennisAtlasApiWeb.FallbackController do
  use TennisAtlasApiWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: TennisAtlasApiWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
end
```

- [ ] **Step 7: Verify it compiles cleanly**

Run: `docker compose run --rm api mix compile --warnings-as-errors`
Expected: compiles with no warnings or errors. (No behavioral test here — both modules are inert until a controller uses `action_fallback` in Task 3; that task's 422 test is what actually exercises this code path.)

- [ ] **Step 8: Commit**

```bash
git add apps/api/lib/tennis_atlas_api_web/controllers/changeset_json.ex apps/api/lib/tennis_atlas_api_web/controllers/fallback_controller.ex
git commit -m "feat: add FallbackController and ChangesetJSON for 422 responses"
```

---

### Task 3: Tournaments resource (list + show)

**Files:**
- Create: `apps/api/test/support/fixtures/venues_fixtures.ex`
- Create: `apps/api/test/support/fixtures/tournaments_fixtures.ex`
- Create: `apps/api/lib/tennis_atlas_api/tournaments.ex`
- Test: `apps/api/test/tennis_atlas_api/tournaments_test.exs`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/tournament_json.ex`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/tournament_controller.ex`
- Modify: `apps/api/lib/tennis_atlas_api_web/router.ex`
- Test: `apps/api/test/tennis_atlas_api_web/controllers/tournament_controller_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.Pagination.paginate/3` (Task 1), `TennisAtlasApiWeb.QueryParams.cast/3` + `TennisAtlasApiWeb.FallbackController` (Task 2).
- Produces: `TennisAtlasApi.VenuesFixtures.venue_fixture/1`, `TennisAtlasApi.TournamentsFixtures.{tournament_fixture/1, tournament_edition_fixture/1}` — reused by every later task. `TennisAtlasApi.Tournaments.list_tournaments/3` and `get_tournament_by_slug!/1`. Task 5 adds `get_edition!/2` and `list_matches_for_edition/3` to this same `Tournaments` module.

- [ ] **Step 1: Write the venue and tournament fixtures**

Create `apps/api/test/support/fixtures/venues_fixtures.ex`:

```elixir
defmodule TennisAtlasApi.VenuesFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Venues.Venue

  def venue_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])

    defaults = %{name: "Test Venue #{n}", city: "Test City", country_code: "FRA"}

    {:ok, venue} =
      defaults
      |> Map.merge(attrs)
      |> then(&Venue.changeset(%Venue{}, &1))
      |> Repo.insert()

    venue
  end
end
```

Create `apps/api/test/support/fixtures/tournaments_fixtures.ex`:

```elixir
defmodule TennisAtlasApi.TournamentsFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}

  def tournament_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])

    defaults = %{
      name: "Test Tournament #{n}",
      slug: "test-tournament-#{n}",
      category: :atp_500,
      surface: :hard
    }

    {:ok, tournament} =
      defaults
      |> Map.merge(attrs)
      |> then(&Tournament.changeset(%Tournament{}, &1))
      |> Repo.insert()

    tournament
  end

  def tournament_edition_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    tournament_id = Map.get_lazy(attrs, :tournament_id, fn -> tournament_fixture(%{}).id end)

    defaults = %{year: 2025, start_date: ~D[2025-01-01], end_date: ~D[2025-01-14], status: :completed}

    {:ok, edition} =
      defaults
      |> Map.merge(attrs)
      |> Map.put(:tournament_id, tournament_id)
      |> then(&TournamentEdition.changeset(%TournamentEdition{}, &1))
      |> Repo.insert()

    edition
  end
end
```

These are support files, not tests — no RED/GREEN cycle for them directly; Step 3 below exercises them.

- [ ] **Step 2: Write the failing context tests**

Create `apps/api/test/tennis_atlas_api/tournaments_test.exs`:

```elixir
defmodule TennisAtlasApi.TournamentsTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Tournaments
  import TennisAtlasApi.TournamentsFixtures
  import TennisAtlasApi.VenuesFixtures

  describe "list_tournaments/3" do
    test "returns tournaments with venue preloaded" do
      venue = venue_fixture(%{name: "Venue X"})
      tournament_fixture(%{name: "A", venue_id: venue.id})

      result = Tournaments.list_tournaments()

      assert [%{venue: %{name: "Venue X"}}] = result.entries
    end

    test "filters by surface" do
      tournament_fixture(%{name: "Clay one", surface: :clay})
      tournament_fixture(%{name: "Hard one", surface: :hard})

      result = Tournaments.list_tournaments(%{surface: :clay})

      assert [%{name: "Clay one"}] = result.entries
    end

    test "filters by category" do
      tournament_fixture(%{name: "Slam", category: :grand_slam})
      tournament_fixture(%{name: "Not slam", category: :atp_250})

      result = Tournaments.list_tournaments(%{category: :grand_slam})

      assert [%{name: "Slam"}] = result.entries
    end

    test "paginates results" do
      for n <- 1..3, do: tournament_fixture(%{name: "T#{n}"})

      result = Tournaments.list_tournaments(%{}, 1, 2)

      assert length(result.entries) == 2
      assert result.total_count == 3
    end
  end

  describe "get_tournament_by_slug!/1" do
    test "returns the tournament with venue and editions preloaded, newest edition first" do
      tournament = tournament_fixture(%{slug: "test-slug"})
      tournament_edition_fixture(%{tournament_id: tournament.id, year: 2024})
      tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})

      result = Tournaments.get_tournament_by_slug!("test-slug")

      assert result.id == tournament.id
      assert [%{year: 2025}, %{year: 2024}] = result.editions
    end

    test "raises Ecto.NoResultsError for an unknown slug" do
      assert_raise Ecto.NoResultsError, fn -> Tournaments.get_tournament_by_slug!("nope") end
    end
  end
end
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments_test.exs`
Expected: FAIL — `TennisAtlasApi.Tournaments` is undefined.

- [ ] **Step 4: Implement the Tournaments context**

Create `apps/api/lib/tennis_atlas_api/tournaments.ex`:

```elixir
defmodule TennisAtlasApi.Tournaments do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}

  def list_tournaments(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Tournament
    |> apply_filter(:surface, filters[:surface])
    |> apply_filter(:category, filters[:category])
    |> preload(:venue)
    |> order_by(asc: :name)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_tournament_by_slug!(slug) do
    Tournament
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:venue, editions: from(e in TournamentEdition, order_by: [desc: e.year])])
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments_test.exs`
Expected: PASS (6 tests, 0 failures).

- [ ] **Step 6: Commit the context**

```bash
git add apps/api/test/support/fixtures/venues_fixtures.ex apps/api/test/support/fixtures/tournaments_fixtures.ex apps/api/lib/tennis_atlas_api/tournaments.ex apps/api/test/tennis_atlas_api/tournaments_test.exs
git commit -m "feat: add Tournaments context (list_tournaments, get_tournament_by_slug!)"
```

- [ ] **Step 7: Write the failing controller test**

Create `apps/api/test/tennis_atlas_api_web/controllers/tournament_controller_test.exs`:

```elixir
defmodule TennisAtlasApiWeb.TournamentControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.TournamentsFixtures
  import TennisAtlasApi.VenuesFixtures

  describe "GET /api/tournaments" do
    test "lists tournaments with pagination meta", %{conn: conn} do
      tournament_fixture(%{name: "A"})
      tournament_fixture(%{name: "B"})

      conn = get(conn, ~p"/api/tournaments")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta == %{"page" => 1, "page_size" => 20, "total_count" => 2, "total_pages" => 1}
    end

    test "filters by surface", %{conn: conn} do
      tournament_fixture(%{name: "Clay one", surface: :clay})
      tournament_fixture(%{name: "Hard one", surface: :hard})

      conn = get(conn, ~p"/api/tournaments?surface=clay")

      assert %{"data" => [%{"name" => "Clay one"}]} = json_response(conn, 200)
    end

    test "returns 422 for an invalid surface filter", %{conn: conn} do
      conn = get(conn, ~p"/api/tournaments?surface=nope")

      assert %{"errors" => %{"surface" => ["is invalid"]}} = json_response(conn, 422)
    end
  end

  describe "GET /api/tournaments/:slug" do
    test "shows a tournament with venue and editions", %{conn: conn} do
      venue = venue_fixture(%{name: "Venue X"})
      tournament = tournament_fixture(%{slug: "test-slug", venue_id: venue.id})
      tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})

      conn = get(conn, ~p"/api/tournaments/test-slug")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["slug"] == "test-slug"
      assert data["venue"]["name"] == "Venue X"
      assert [%{"year" => 2025}] = data["editions"]
    end

    test "returns 404 for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/api/tournaments/does-not-exist")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
```

- [ ] **Step 8: Run the controller test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/tournament_controller_test.exs`
Expected: FAIL — no route matches `/api/tournaments` yet.

- [ ] **Step 9: Implement the JSON view**

Create `apps/api/lib/tennis_atlas_api_web/controllers/tournament_json.ex`:

```elixir
defmodule TennisAtlasApiWeb.TournamentJSON do
  alias TennisAtlasApi.Tournaments.Tournament

  def index(%{tournaments: tournaments, meta: meta}) do
    %{data: for(t <- tournaments, do: summary(t)), meta: meta}
  end

  def show(%{tournament: tournament}) do
    %{data: detail(tournament)}
  end

  defp summary(%Tournament{} = t) do
    %{
      id: t.id,
      name: t.name,
      slug: t.slug,
      category: t.category,
      surface: t.surface,
      venue: venue(t.venue)
    }
  end

  defp detail(%Tournament{} = t) do
    t
    |> summary()
    |> Map.merge(%{
      description: t.description,
      logo_url: t.logo_url,
      hero_image_url: t.hero_image_url,
      editions: for(e <- t.editions, do: edition_summary(e))
    })
  end

  defp edition_summary(edition) do
    %{id: edition.id, year: edition.year, start_date: edition.start_date, end_date: edition.end_date, status: edition.status}
  end

  defp venue(nil), do: nil
  defp venue(venue), do: %{id: venue.id, name: venue.name, city: venue.city, country_code: venue.country_code}
end
```

- [ ] **Step 10: Implement the controller**

Create `apps/api/lib/tennis_atlas_api_web/controllers/tournament_controller.ex`:

```elixir
defmodule TennisAtlasApiWeb.TournamentController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Tournaments
  alias TennisAtlasApiWeb.QueryParams

  @filter_types %{
    surface: Ecto.ParameterizedType.init(Ecto.Enum, values: [:clay, :grass, :hard, :indoor]),
    category:
      Ecto.ParameterizedType.init(Ecto.Enum,
        values: [:grand_slam, :masters_1000, :atp_500, :atp_250, :wta_1000, :wta_500, :wta_250]
      )
  }

  def index(conn, params) do
    with {:ok, query} <- QueryParams.cast(params, @filter_types) do
      %{page: page, page_size: page_size} = query
      filters = Map.drop(query, [:page, :page_size])
      result = Tournaments.list_tournaments(filters, page, page_size)

      render(conn, :index,
        tournaments: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end

  def show(conn, %{"slug" => slug}) do
    tournament = Tournaments.get_tournament_by_slug!(slug)
    render(conn, :show, tournament: tournament)
  end
end
```

- [ ] **Step 11: Add the routes**

Modify `apps/api/lib/tennis_atlas_api_web/router.ex` — add inside the existing `/api` scope, after the `/health` route:

```elixir
    get "/health", HealthController, :index

    get "/tournaments", TournamentController, :index
    get "/tournaments/:slug", TournamentController, :show
```

- [ ] **Step 12: Run the controller test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/tournament_controller_test.exs`
Expected: PASS (5 tests, 0 failures).

- [ ] **Step 13: Run the full suite to check for regressions**

Run: `docker compose run --rm api mix test`
Expected: all tests pass.

- [ ] **Step 14: Commit**

```bash
git add apps/api/lib/tennis_atlas_api_web/controllers/tournament_json.ex apps/api/lib/tennis_atlas_api_web/controllers/tournament_controller.ex apps/api/lib/tennis_atlas_api_web/router.ex apps/api/test/tennis_atlas_api_web/controllers/tournament_controller_test.exs
git commit -m "feat: add GET /api/tournaments and /api/tournaments/:slug"
```

---

### Task 4: Players resource (list + show)

**Files:**
- Create: `apps/api/test/support/fixtures/players_fixtures.ex`
- Create: `apps/api/lib/tennis_atlas_api/players.ex`
- Test: `apps/api/test/tennis_atlas_api/players_test.exs`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/player_json.ex`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/player_controller.ex`
- Modify: `apps/api/lib/tennis_atlas_api_web/router.ex`
- Test: `apps/api/test/tennis_atlas_api_web/controllers/player_controller_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.Pagination.paginate/3` (Task 1), `TennisAtlasApiWeb.QueryParams.cast/3` + `FallbackController` (Task 2).
- Produces: `TennisAtlasApi.PlayersFixtures.player_fixture/1` — reused by Task 5, Task 6, Task 7. `TennisAtlasApi.Players.list_players/3` and `get_player_by_slug!/1`. Task 7 adds `list_rankings/3` to this same `Players` module and `ranking_fixture/1` to this same fixtures file.

- [ ] **Step 1: Write the player fixture**

Create `apps/api/test/support/fixtures/players_fixtures.ex`:

```elixir
defmodule TennisAtlasApi.PlayersFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Players.Player

  def player_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])

    defaults = %{
      first_name: "Test",
      last_name: "Player#{n}",
      slug: "test-player-#{n}",
      country_code: "FRA"
    }

    {:ok, player} =
      defaults
      |> Map.merge(attrs)
      |> then(&Player.changeset(%Player{}, &1))
      |> Repo.insert()

    player
  end
end
```

- [ ] **Step 2: Write the failing context tests**

Create `apps/api/test/tennis_atlas_api/players_test.exs`:

```elixir
defmodule TennisAtlasApi.PlayersTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Players
  import TennisAtlasApi.PlayersFixtures

  describe "list_players/3" do
    test "returns all players" do
      player_fixture(%{first_name: "A"})
      player_fixture(%{first_name: "B"})

      result = Players.list_players()

      assert length(result.entries) == 2
    end

    test "filters by country_code" do
      player_fixture(%{first_name: "French", country_code: "FRA"})
      player_fixture(%{first_name: "Spanish", country_code: "ESP"})

      result = Players.list_players(%{country_code: "ESP"})

      assert [%{first_name: "Spanish"}] = result.entries
    end

    test "paginates results" do
      for n <- 1..3, do: player_fixture(%{first_name: "P#{n}"})

      result = Players.list_players(%{}, 1, 2)

      assert length(result.entries) == 2
      assert result.total_count == 3
    end
  end

  describe "get_player_by_slug!/1" do
    test "returns the player" do
      player = player_fixture(%{slug: "known-slug"})

      assert Players.get_player_by_slug!("known-slug").id == player.id
    end

    test "raises Ecto.NoResultsError for an unknown slug" do
      assert_raise Ecto.NoResultsError, fn -> Players.get_player_by_slug!("nope") end
    end
  end
end
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players_test.exs`
Expected: FAIL — `TennisAtlasApi.Players` is undefined.

- [ ] **Step 4: Implement the Players context**

Create `apps/api/lib/tennis_atlas_api/players.ex`:

```elixir
defmodule TennisAtlasApi.Players do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Players.Player

  def list_players(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Player
    |> apply_filter(:country_code, filters[:country_code])
    |> order_by(asc: :last_name, asc: :first_name)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_player_by_slug!(slug), do: Repo.get_by!(Player, slug: slug)

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players_test.exs`
Expected: PASS (5 tests, 0 failures).

- [ ] **Step 6: Commit the context**

```bash
git add apps/api/test/support/fixtures/players_fixtures.ex apps/api/lib/tennis_atlas_api/players.ex apps/api/test/tennis_atlas_api/players_test.exs
git commit -m "feat: add Players context (list_players, get_player_by_slug!)"
```

- [ ] **Step 7: Write the failing controller test**

Create `apps/api/test/tennis_atlas_api_web/controllers/player_controller_test.exs`:

```elixir
defmodule TennisAtlasApiWeb.PlayerControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.PlayersFixtures

  describe "GET /api/players" do
    test "lists players with pagination meta", %{conn: conn} do
      player_fixture(%{first_name: "A"})
      player_fixture(%{first_name: "B"})

      conn = get(conn, ~p"/api/players")

      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta == %{"page" => 1, "page_size" => 20, "total_count" => 2, "total_pages" => 1}
    end

    test "filters by country_code", %{conn: conn} do
      player_fixture(%{first_name: "French", country_code: "FRA"})
      player_fixture(%{first_name: "Spanish", country_code: "ESP"})

      conn = get(conn, ~p"/api/players?country_code=ESP")

      assert %{"data" => [%{"first_name" => "Spanish"}]} = json_response(conn, 200)
    end
  end

  describe "GET /api/players/:slug" do
    test "shows a player", %{conn: conn} do
      player_fixture(%{slug: "known-slug", first_name: "Known"})

      conn = get(conn, ~p"/api/players/known-slug")

      assert %{"data" => %{"first_name" => "Known"}} = json_response(conn, 200)
    end

    test "returns 404 for an unknown slug", %{conn: conn} do
      conn = get(conn, ~p"/api/players/does-not-exist")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
```

- [ ] **Step 8: Run the controller test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/player_controller_test.exs`
Expected: FAIL — no route matches `/api/players` yet.

- [ ] **Step 9: Implement the JSON view**

Create `apps/api/lib/tennis_atlas_api_web/controllers/player_json.ex`:

```elixir
defmodule TennisAtlasApiWeb.PlayerJSON do
  alias TennisAtlasApi.Players.Player

  def index(%{players: players, meta: meta}) do
    %{data: for(p <- players, do: summary(p)), meta: meta}
  end

  def show(%{player: player}) do
    %{data: detail(player)}
  end

  defp summary(%Player{} = p) do
    %{
      id: p.id,
      first_name: p.first_name,
      last_name: p.last_name,
      slug: p.slug,
      country_code: p.country_code,
      current_ranking: p.current_ranking,
      current_ranking_points: p.current_ranking_points
    }
  end

  defp detail(%Player{} = p) do
    Map.merge(summary(p), %{birth_date: p.birth_date, hand: p.hand, height_cm: p.height_cm})
  end
end
```

- [ ] **Step 10: Implement the controller**

Create `apps/api/lib/tennis_atlas_api_web/controllers/player_controller.ex`:

```elixir
defmodule TennisAtlasApiWeb.PlayerController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Players
  alias TennisAtlasApiWeb.QueryParams

  @filter_types %{country_code: :string}

  def index(conn, params) do
    with {:ok, query} <- QueryParams.cast(params, @filter_types) do
      %{page: page, page_size: page_size} = query
      filters = Map.drop(query, [:page, :page_size])
      result = Players.list_players(filters, page, page_size)

      render(conn, :index,
        players: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end

  def show(conn, %{"slug" => slug}) do
    player = Players.get_player_by_slug!(slug)
    render(conn, :show, player: player)
  end
end
```

- [ ] **Step 11: Add the routes**

Modify `apps/api/lib/tennis_atlas_api_web/router.ex` — add after the tournament routes:

```elixir
    get "/players", PlayerController, :index
    get "/players/:slug", PlayerController, :show
```

- [ ] **Step 12: Run the controller test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/player_controller_test.exs`
Expected: PASS (4 tests, 0 failures).

- [ ] **Step 13: Run the full suite to check for regressions**

Run: `docker compose run --rm api mix test`
Expected: all tests pass.

- [ ] **Step 14: Commit**

```bash
git add apps/api/lib/tennis_atlas_api_web/controllers/player_json.ex apps/api/lib/tennis_atlas_api_web/controllers/player_controller.ex apps/api/lib/tennis_atlas_api_web/router.ex apps/api/test/tennis_atlas_api_web/controllers/player_controller_test.exs
git commit -m "feat: add GET /api/players and /api/players/:slug"
```

---

### Task 5: Tournament edition matches (nested list)

**Files:**
- Create: `apps/api/test/support/fixtures/matches_fixtures.ex`
- Modify: `apps/api/lib/tennis_atlas_api/tournaments.ex`
- Modify: `apps/api/test/tennis_atlas_api/tournaments_test.exs`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/match_json.ex`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/tournament_edition_match_controller.ex`
- Modify: `apps/api/lib/tennis_atlas_api_web/router.ex`
- Test: `apps/api/test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.TournamentsFixtures.tournament_edition_fixture/1` (Task 3), `TennisAtlasApi.PlayersFixtures.player_fixture/1` (Task 4), `TennisAtlasApi.Pagination.paginate/3` (Task 1), `TennisAtlasApiWeb.QueryParams`/`FallbackController` (Task 2).
- Produces: `TennisAtlasApi.MatchesFixtures.{match_fixture/1, set_fixture/1}` — reused by Task 6. `TennisAtlasApi.Tournaments.get_edition!/2` and `list_matches_for_edition/3`. `TennisAtlasApiWeb.MatchJSON.show/1` is written now but only exercised starting Task 6 — Task 5 exercises `index/1`.

- [ ] **Step 1: Write the match and set fixtures**

Create `apps/api/test/support/fixtures/matches_fixtures.ex`:

```elixir
defmodule TennisAtlasApi.MatchesFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Matches.{Match, Set}
  import TennisAtlasApi.TournamentsFixtures, only: [tournament_edition_fixture: 1]
  import TennisAtlasApi.PlayersFixtures, only: [player_fixture: 1]

  def match_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    tournament_edition_id = Map.get_lazy(attrs, :tournament_edition_id, fn -> tournament_edition_fixture(%{}).id end)
    player_a_id = Map.get_lazy(attrs, :player_a_id, fn -> player_fixture(%{}).id end)
    player_b_id = Map.get_lazy(attrs, :player_b_id, fn -> player_fixture(%{}).id end)

    defaults = %{tour: :atp, round: :qf, status: :scheduled, best_of: 3}

    {:ok, match} =
      defaults
      |> Map.merge(attrs)
      |> Map.merge(%{
        tournament_edition_id: tournament_edition_id,
        player_a_id: player_a_id,
        player_b_id: player_b_id
      })
      |> then(&Match.changeset(%Match{}, &1))
      |> Repo.insert()

    match
  end

  def set_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    match_id = Map.get_lazy(attrs, :match_id, fn -> match_fixture(%{}).id end)

    defaults = %{set_number: 1, player_a_games: 6, player_b_games: 4}

    {:ok, set} =
      defaults
      |> Map.merge(attrs)
      |> Map.put(:match_id, match_id)
      |> then(&Set.changeset(%Set{}, &1))
      |> Repo.insert()

    set
  end
end
```

- [ ] **Step 2: Write the failing context tests**

Modify `apps/api/test/tennis_atlas_api/tournaments_test.exs` — add `import TennisAtlasApi.MatchesFixtures` next to the other imports, and append these two `describe` blocks:

```elixir
  describe "get_edition!/2" do
    test "returns the edition with tournament preloaded" do
      tournament = tournament_fixture(%{slug: "edition-test"})
      edition = tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})

      result = Tournaments.get_edition!("edition-test", 2025)

      assert result.id == edition.id
      assert result.tournament.slug == "edition-test"
    end

    test "raises Ecto.NoResultsError for an unknown year" do
      tournament_fixture(%{slug: "edition-test-2"})

      assert_raise Ecto.NoResultsError, fn -> Tournaments.get_edition!("edition-test-2", 1999) end
    end
  end

  describe "list_matches_for_edition/3" do
    test "returns matches for the given edition only" do
      edition_a = tournament_edition_fixture(%{})
      edition_b = tournament_edition_fixture(%{})
      match_fixture(%{tournament_edition_id: edition_a.id})
      match_fixture(%{tournament_edition_id: edition_b.id})

      result = Tournaments.list_matches_for_edition(edition_a.id)

      assert length(result.entries) == 1
    end

    test "filters by tour" do
      edition = tournament_edition_fixture(%{})
      match_fixture(%{tournament_edition_id: edition.id, tour: :atp, status: :finished})
      match_fixture(%{tournament_edition_id: edition.id, tour: :wta, status: :finished})

      result = Tournaments.list_matches_for_edition(edition.id, %{tour: :atp})

      assert [%{tour: :atp}] = result.entries
    end
  end
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments_test.exs`
Expected: FAIL — `Tournaments.get_edition!/2` and `list_matches_for_edition/3` are undefined.

- [ ] **Step 4: Implement get_edition!/2 and list_matches_for_edition/3**

Modify `apps/api/lib/tennis_atlas_api/tournaments.ex` — replace the whole file with:

```elixir
defmodule TennisAtlasApi.Tournaments do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Tournaments.{Tournament, TournamentEdition}
  alias TennisAtlasApi.Matches.Match

  def list_tournaments(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Tournament
    |> apply_filter(:surface, filters[:surface])
    |> apply_filter(:category, filters[:category])
    |> preload(:venue)
    |> order_by(asc: :name)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_tournament_by_slug!(slug) do
    Tournament
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:venue, editions: from(e in TournamentEdition, order_by: [desc: e.year])])
  end

  def get_edition!(tournament_slug, year) do
    TournamentEdition
    |> join(:inner, [e], t in assoc(e, :tournament))
    |> where([e, t], t.slug == ^tournament_slug and e.year == ^year)
    |> preload(:tournament)
    |> Repo.one!()
  end

  def list_matches_for_edition(edition_id, filters \\ %{}, page \\ 1, page_size \\ 20) do
    Match
    |> where([m], m.tournament_edition_id == ^edition_id)
    |> apply_filter(:tour, filters[:tour])
    |> apply_filter(:status, filters[:status])
    |> preload([:player_a, :player_b, :court])
    |> order_by(asc: :id)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments_test.exs`
Expected: PASS (10 tests, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add apps/api/test/support/fixtures/matches_fixtures.ex apps/api/lib/tennis_atlas_api/tournaments.ex apps/api/test/tennis_atlas_api/tournaments_test.exs
git commit -m "feat: add get_edition! and list_matches_for_edition to Tournaments context"
```

- [ ] **Step 7: Write the failing controller test**

Create `apps/api/test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs`:

```elixir
defmodule TennisAtlasApiWeb.TournamentEditionMatchControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.TournamentsFixtures
  import TennisAtlasApi.MatchesFixtures

  describe "GET /api/tournaments/:slug/editions/:year/matches" do
    test "lists matches for the edition", %{conn: conn} do
      tournament = tournament_fixture(%{slug: "with-matches"})
      edition = tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})
      match_fixture(%{tournament_edition_id: edition.id})

      conn = get(conn, ~p"/api/tournaments/with-matches/editions/2025/matches")

      assert %{"data" => [_match]} = json_response(conn, 200)
    end

    test "returns 404 for an unknown tournament/year combination", %{conn: conn} do
      tournament_fixture(%{slug: "no-matches"})

      conn = get(conn, ~p"/api/tournaments/no-matches/editions/1999/matches")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end

    test "filters by tour", %{conn: conn} do
      tournament = tournament_fixture(%{slug: "filter-tour"})
      edition = tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})
      match_fixture(%{tournament_edition_id: edition.id, tour: :atp})
      match_fixture(%{tournament_edition_id: edition.id, tour: :wta})

      conn = get(conn, ~p"/api/tournaments/filter-tour/editions/2025/matches?tour=atp")

      assert %{"data" => [match]} = json_response(conn, 200)
      assert match["tour"] == "atp"
    end
  end
end
```

- [ ] **Step 8: Run the controller test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs`
Expected: FAIL — no route matches yet.

- [ ] **Step 9: Implement MatchJSON**

Create `apps/api/lib/tennis_atlas_api_web/controllers/match_json.ex`:

```elixir
defmodule TennisAtlasApiWeb.MatchJSON do
  alias TennisAtlasApi.Matches.Match

  def index(%{matches: matches, meta: meta}) do
    %{data: for(m <- matches, do: summary(m)), meta: meta}
  end

  def show(%{match: match}) do
    %{data: detail(match)}
  end

  defp summary(%Match{} = m) do
    %{
      id: m.id,
      tour: m.tour,
      round: m.round,
      status: m.status,
      scheduled_at: m.scheduled_at,
      started_at: m.started_at,
      finished_at: m.finished_at,
      best_of: m.best_of,
      winner_id: m.winner_id,
      player_a: player_ref(m.player_a),
      player_b: player_ref(m.player_b),
      court: court_ref(m.court)
    }
  end

  defp detail(%Match{} = m) do
    Map.merge(summary(m), %{
      tournament: tournament_ref(m.tournament_edition),
      sets: for(s <- m.sets, do: set_ref(s))
    })
  end

  defp player_ref(nil), do: nil
  defp player_ref(player), do: %{id: player.id, first_name: player.first_name, last_name: player.last_name, slug: player.slug}

  defp court_ref(nil), do: nil
  defp court_ref(court), do: %{id: court.id, name: court.name, surface: court.surface}

  defp tournament_ref(edition) do
    %{
      edition_id: edition.id,
      year: edition.year,
      tournament_id: edition.tournament.id,
      tournament_name: edition.tournament.name,
      tournament_slug: edition.tournament.slug
    }
  end

  defp set_ref(s) do
    %{set_number: s.set_number, player_a_games: s.player_a_games, player_b_games: s.player_b_games, tiebreak_a: s.tiebreak_a, tiebreak_b: s.tiebreak_b}
  end
end
```

- [ ] **Step 10: Implement the controller**

Create `apps/api/lib/tennis_atlas_api_web/controllers/tournament_edition_match_controller.ex`:

```elixir
defmodule TennisAtlasApiWeb.TournamentEditionMatchController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Tournaments
  alias TennisAtlasApiWeb.QueryParams

  @types %{
    year: :integer,
    tour: Ecto.ParameterizedType.init(Ecto.Enum, values: [:atp, :wta]),
    status:
      Ecto.ParameterizedType.init(Ecto.Enum,
        values: [:scheduled, :live, :finished, :retired, :walkover, :cancelled]
      )
  }

  def index(conn, %{"slug" => slug} = params) do
    with {:ok, query} <- QueryParams.cast(params, @types, [:year]) do
      edition = Tournaments.get_edition!(slug, query.year)
      filters = Map.drop(query, [:page, :page_size, :year])
      result = Tournaments.list_matches_for_edition(edition.id, filters, query.page, query.page_size)

      render(conn, :index,
        matches: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end
end
```

- [ ] **Step 11: Add the route**

Modify `apps/api/lib/tennis_atlas_api_web/router.ex` — add after the player routes:

```elixir
    get "/tournaments/:slug/editions/:year/matches", TournamentEditionMatchController, :index
```

- [ ] **Step 12: Run the controller test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs`
Expected: PASS (3 tests, 0 failures).

- [ ] **Step 13: Run the full suite to check for regressions**

Run: `docker compose run --rm api mix test`
Expected: all tests pass.

- [ ] **Step 14: Commit**

```bash
git add apps/api/lib/tennis_atlas_api_web/controllers/match_json.ex apps/api/lib/tennis_atlas_api_web/controllers/tournament_edition_match_controller.ex apps/api/lib/tennis_atlas_api_web/router.ex apps/api/test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs
git commit -m "feat: add GET /api/tournaments/:slug/editions/:year/matches"
```

---

### Task 6: Match detail

**Files:**
- Create: `apps/api/lib/tennis_atlas_api/matches.ex`
- Test: `apps/api/test/tennis_atlas_api/matches_test.exs`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/match_controller.ex`
- Modify: `apps/api/lib/tennis_atlas_api_web/router.ex`
- Test: `apps/api/test/tennis_atlas_api_web/controllers/match_controller_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.MatchesFixtures.{match_fixture/1, set_fixture/1}` (Task 5), `TennisAtlasApiWeb.MatchJSON.show/1` (Task 5, already written).
- Produces: `TennisAtlasApi.Matches.get_match!/1`. Nothing later depends on this task.

- [ ] **Step 1: Write the failing context test**

Create `apps/api/test/tennis_atlas_api/matches_test.exs`:

```elixir
defmodule TennisAtlasApi.MatchesTest do
  use TennisAtlasApi.DataCase, async: true

  alias TennisAtlasApi.Matches
  import TennisAtlasApi.MatchesFixtures

  describe "get_match!/1" do
    test "returns the match with sets, players, court and tournament preloaded" do
      match = match_fixture(%{})
      set_fixture(%{match_id: match.id, set_number: 1})

      result = Matches.get_match!(match.id)

      assert result.id == match.id
      assert length(result.sets) == 1
      assert result.tournament_edition.tournament.id != nil
    end

    test "raises Ecto.NoResultsError for an unknown id" do
      assert_raise Ecto.NoResultsError, fn -> Matches.get_match!(999_999) end
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/matches_test.exs`
Expected: FAIL — `TennisAtlasApi.Matches` is undefined.

- [ ] **Step 3: Implement the Matches context**

Create `apps/api/lib/tennis_atlas_api/matches.ex`:

```elixir
defmodule TennisAtlasApi.Matches do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Matches.Match

  def get_match!(id) do
    Match
    |> Repo.get!(id)
    |> Repo.preload([:sets, :player_a, :player_b, :court, tournament_edition: :tournament])
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/matches_test.exs`
Expected: PASS (2 tests, 0 failures).

- [ ] **Step 5: Commit**

```bash
git add apps/api/lib/tennis_atlas_api/matches.ex apps/api/test/tennis_atlas_api/matches_test.exs
git commit -m "feat: add Matches context (get_match!)"
```

- [ ] **Step 6: Write the failing controller test**

Create `apps/api/test/tennis_atlas_api_web/controllers/match_controller_test.exs`:

```elixir
defmodule TennisAtlasApiWeb.MatchControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.MatchesFixtures

  describe "GET /api/matches/:id" do
    test "shows a match with sets and tournament context", %{conn: conn} do
      match = match_fixture(%{})
      set_fixture(%{match_id: match.id, set_number: 1})

      conn = get(conn, ~p"/api/matches/#{match.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == match.id
      assert length(data["sets"]) == 1
      assert data["tournament"]["tournament_id"] != nil
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn = get(conn, ~p"/api/matches/999999")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end

    test "returns 404 for a non-numeric id instead of crashing", %{conn: conn} do
      conn = get(conn, ~p"/api/matches/not-a-number")

      assert json_response(conn, 404) == %{"errors" => %{"detail" => "Not Found"}}
    end
  end
end
```

- [ ] **Step 7: Run the controller test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/match_controller_test.exs`
Expected: FAIL — no route matches yet.

- [ ] **Step 8: Implement the controller**

Create `apps/api/lib/tennis_atlas_api_web/controllers/match_controller.ex`:

```elixir
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
```

`Integer.parse/1` rejects non-numeric ids before they ever reach `Repo.get!/2` — passing a non-numeric string straight to `Repo.get!/2` raises `Ecto.Query.CastError`, which has no `Plug.Exception` mapping and would surface as a bare 500 instead of the 404 a REST client expects for "no such resource".

- [ ] **Step 9: Add the route**

Modify `apps/api/lib/tennis_atlas_api_web/router.ex` — add after the edition-matches route:

```elixir
    get "/matches/:id", MatchController, :show
```

- [ ] **Step 10: Run the controller test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/match_controller_test.exs`
Expected: PASS (3 tests, 0 failures).

- [ ] **Step 11: Run the full suite to check for regressions**

Run: `docker compose run --rm api mix test`
Expected: all tests pass.

- [ ] **Step 12: Commit**

```bash
git add apps/api/lib/tennis_atlas_api_web/controllers/match_controller.ex apps/api/lib/tennis_atlas_api_web/router.ex apps/api/test/tennis_atlas_api_web/controllers/match_controller_test.exs
git commit -m "feat: add GET /api/matches/:id"
```

---

### Task 7: Rankings resource

**Files:**
- Modify: `apps/api/lib/tennis_atlas_api/players.ex`
- Modify: `apps/api/test/support/fixtures/players_fixtures.ex`
- Modify: `apps/api/test/tennis_atlas_api/players_test.exs`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/ranking_json.ex`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/ranking_controller.ex`
- Modify: `apps/api/lib/tennis_atlas_api_web/router.ex`
- Test: `apps/api/test/tennis_atlas_api_web/controllers/ranking_controller_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.PlayersFixtures.player_fixture/1` (Task 4), `TennisAtlasApi.Pagination.paginate/3` (Task 1), `TennisAtlasApiWeb.QueryParams`/`FallbackController` (Task 2).
- Produces: `TennisAtlasApi.PlayersFixtures.ranking_fixture/1`. `TennisAtlasApi.Players.list_rankings/3`. Nothing later depends on this task.

- [ ] **Step 1: Add the ranking fixture**

Modify `apps/api/test/support/fixtures/players_fixtures.ex` — add the `Ranking` alias and this function:

```elixir
defmodule TennisAtlasApi.PlayersFixtures do
  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Players.{Player, Ranking}

  def player_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    n = System.unique_integer([:positive])

    defaults = %{
      first_name: "Test",
      last_name: "Player#{n}",
      slug: "test-player-#{n}",
      country_code: "FRA"
    }

    {:ok, player} =
      defaults
      |> Map.merge(attrs)
      |> then(&Player.changeset(%Player{}, &1))
      |> Repo.insert()

    player
  end

  def ranking_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    player_id = Map.get_lazy(attrs, :player_id, fn -> player_fixture(%{}).id end)

    defaults = %{ranking_type: :atp, position: 1, points: 5000, as_of_date: ~D[2025-09-01]}

    {:ok, ranking} =
      defaults
      |> Map.merge(attrs)
      |> Map.put(:player_id, player_id)
      |> then(&Ranking.changeset(%Ranking{}, &1))
      |> Repo.insert()

    ranking
  end
end
```

- [ ] **Step 2: Write the failing context tests**

Modify `apps/api/test/tennis_atlas_api/players_test.exs` — append this `describe` block:

```elixir
  describe "list_rankings/3" do
    test "returns only the latest snapshot per player for the given type" do
      player = player_fixture(%{})
      ranking_fixture(%{player_id: player.id, ranking_type: :atp, as_of_date: ~D[2025-01-01], position: 5})
      ranking_fixture(%{player_id: player.id, ranking_type: :atp, as_of_date: ~D[2025-09-01], position: 3})

      result = Players.list_rankings(%{ranking_type: :atp})

      assert [%{position: 3, as_of_date: ~D[2025-09-01]}] = result.entries
    end

    test "excludes the other ranking type" do
      player_a = player_fixture(%{})
      player_b = player_fixture(%{})
      ranking_fixture(%{player_id: player_a.id, ranking_type: :atp, position: 1})
      ranking_fixture(%{player_id: player_b.id, ranking_type: :wta, position: 1})

      result = Players.list_rankings(%{ranking_type: :atp})

      assert [%{player_id: player_id}] = result.entries
      assert player_id == player_a.id
    end

    test "orders by position ascending" do
      player_a = player_fixture(%{})
      player_b = player_fixture(%{})
      ranking_fixture(%{player_id: player_a.id, ranking_type: :atp, position: 2})
      ranking_fixture(%{player_id: player_b.id, ranking_type: :atp, position: 1})

      result = Players.list_rankings(%{ranking_type: :atp})

      assert [%{position: 1}, %{position: 2}] = result.entries
    end
  end
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players_test.exs`
Expected: FAIL — `Players.list_rankings/3` is undefined.

- [ ] **Step 4: Implement list_rankings/3**

Modify `apps/api/lib/tennis_atlas_api/players.ex` — replace the whole file with:

```elixir
defmodule TennisAtlasApi.Players do
  import Ecto.Query

  alias TennisAtlasApi.Repo
  alias TennisAtlasApi.Pagination
  alias TennisAtlasApi.Players.{Player, Ranking}

  def list_players(filters \\ %{}, page \\ 1, page_size \\ 20) do
    Player
    |> apply_filter(:country_code, filters[:country_code])
    |> order_by(asc: :last_name, asc: :first_name)
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  def get_player_by_slug!(slug), do: Repo.get_by!(Player, slug: slug)

  def list_rankings(filters, page \\ 1, page_size \\ 20) do
    ranking_type = filters.ranking_type

    latest =
      from(r in Ranking,
        where: r.ranking_type == ^ranking_type,
        group_by: r.player_id,
        select: %{player_id: r.player_id, as_of_date: max(r.as_of_date)}
      )

    from(r in Ranking,
      join: l in subquery(latest),
      on: r.player_id == l.player_id and r.as_of_date == l.as_of_date,
      where: r.ranking_type == ^ranking_type,
      order_by: [asc: r.position],
      preload: [:player]
    )
    |> Pagination.paginate(Repo, page: page, page_size: page_size)
  end

  defp apply_filter(query, _field, nil), do: query
  defp apply_filter(query, field, value), do: where(query, [q], field(q, ^field) == ^value)
end
```

`list_rankings/3` reads `filters.ranking_type` directly (not `Map.fetch!/2` or a `nil` fallback) because the only caller — `RankingController`, Step 9 below — validates `ranking_type` as required via `QueryParams.cast/3` before ever calling this function; by the time `filters` reaches here, the key is guaranteed present.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/players_test.exs`
Expected: PASS (8 tests, 0 failures).

- [ ] **Step 6: Commit**

```bash
git add apps/api/test/support/fixtures/players_fixtures.ex apps/api/lib/tennis_atlas_api/players.ex apps/api/test/tennis_atlas_api/players_test.exs
git commit -m "feat: add list_rankings to Players context"
```

- [ ] **Step 7: Write the failing controller test**

Create `apps/api/test/tennis_atlas_api_web/controllers/ranking_controller_test.exs`:

```elixir
defmodule TennisAtlasApiWeb.RankingControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  import TennisAtlasApi.PlayersFixtures

  describe "GET /api/rankings" do
    test "lists rankings for the given type", %{conn: conn} do
      player = player_fixture(%{})
      ranking_fixture(%{player_id: player.id, ranking_type: :atp, position: 1})

      conn = get(conn, ~p"/api/rankings?ranking_type=atp")

      assert %{"data" => [entry]} = json_response(conn, 200)
      assert entry["ranking_type"] == "atp"
      assert entry["player"]["id"] == player.id
    end

    test "returns 422 when ranking_type is missing", %{conn: conn} do
      conn = get(conn, ~p"/api/rankings")

      assert %{"errors" => %{"ranking_type" => ["can't be blank"]}} = json_response(conn, 422)
    end
  end
end
```

- [ ] **Step 8: Run the controller test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/ranking_controller_test.exs`
Expected: FAIL — no route matches yet.

- [ ] **Step 9: Implement the JSON view and controller**

Create `apps/api/lib/tennis_atlas_api_web/controllers/ranking_json.ex`:

```elixir
defmodule TennisAtlasApiWeb.RankingJSON do
  def index(%{rankings: rankings, meta: meta}) do
    %{data: for(r <- rankings, do: entry(r)), meta: meta}
  end

  defp entry(r) do
    %{
      ranking_type: r.ranking_type,
      position: r.position,
      points: r.points,
      as_of_date: r.as_of_date,
      player: %{id: r.player.id, first_name: r.player.first_name, last_name: r.player.last_name, slug: r.player.slug}
    }
  end
end
```

Create `apps/api/lib/tennis_atlas_api_web/controllers/ranking_controller.ex`:

```elixir
defmodule TennisAtlasApiWeb.RankingController do
  use TennisAtlasApiWeb, :controller

  action_fallback TennisAtlasApiWeb.FallbackController

  alias TennisAtlasApi.Players
  alias TennisAtlasApiWeb.QueryParams

  @types %{ranking_type: Ecto.ParameterizedType.init(Ecto.Enum, values: [:atp, :wta])}

  def index(conn, params) do
    with {:ok, query} <- QueryParams.cast(params, @types, [:ranking_type]) do
      %{page: page, page_size: page_size} = query
      filters = Map.drop(query, [:page, :page_size])
      result = Players.list_rankings(filters, page, page_size)

      render(conn, :index,
        rankings: result.entries,
        meta: Map.take(result, [:page, :page_size, :total_count, :total_pages])
      )
    end
  end
end
```

- [ ] **Step 10: Add the route**

Modify `apps/api/lib/tennis_atlas_api_web/router.ex` — add after the matches route:

```elixir
    get "/rankings", RankingController, :index
```

- [ ] **Step 11: Run the controller test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/ranking_controller_test.exs`
Expected: PASS (2 tests, 0 failures).

- [ ] **Step 12: Run the full suite to check for regressions**

Run: `docker compose run --rm api mix test`
Expected: all tests pass.

- [ ] **Step 13: Commit**

```bash
git add apps/api/lib/tennis_atlas_api_web/controllers/ranking_json.ex apps/api/lib/tennis_atlas_api_web/controllers/ranking_controller.ex apps/api/lib/tennis_atlas_api_web/router.ex apps/api/test/tennis_atlas_api_web/controllers/ranking_controller_test.exs
git commit -m "feat: add GET /api/rankings"
```

---

### Task 8: Final verification and docs

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: the full test suite built across Tasks 1–7.
- Produces: nothing new — this task verifies and documents.

- [ ] **Step 1: Run the full test suite**

Run: `docker compose run --rm api mix test`
Expected: all tests pass. Count up the `test "..."` occurrences across every file touched in this plan plus the 33 from Phase 2's final count if you want to sanity-check the total; do not assume a specific number without recounting — Phase 2's ledger already found the naive "sum the per-task counts" estimate wrong once.

- [ ] **Step 2: Check for compiler warnings**

Run: `docker compose run --rm api mix compile --warnings-as-errors`
Expected: exits 0, no warnings.

- [ ] **Step 3: Smoke-test the running stack**

Run: `docker compose up -d`
Then wait for the `api` and `db` services to report healthy, then:

```bash
docker compose run --rm api mix run priv/repo/seeds.exs
curl -s http://localhost:4000/api/tournaments | head -c 500
curl -s "http://localhost:4000/api/rankings?ranking_type=atp" | head -c 500
curl -s http://localhost:4000/api/rankings
```

Expected: the first two calls return 200 with real seeded data (tournament names like "Internationaux Fictifs de France", ranking entries with player names); the last call (no `ranking_type`) returns a 422 body `{"errors":{"ranking_type":["can't be blank"]}}`. Use the actual `API_PORT` from your local `.env` if it differs from 4000.

Then: `docker compose down`

- [ ] **Step 4: Document the new endpoints in the root README**

Modify `README.md` — replace this line:

```markdown
- API : http://localhost:4000 (health check : `/api/health`)
```

with:

```markdown
- API : http://localhost:4000 (health check : `/api/health`)

### Endpoints de l'API (Phase 3)

Toutes les routes sont en lecture seule (`GET`), pagination `?page=&page_size=` (défaut 1/20, max 100) :

- `GET /api/tournaments` — filtres : `surface`, `category`
- `GET /api/tournaments/:slug`
- `GET /api/tournaments/:slug/editions/:year/matches` — filtres : `tour`, `status`
- `GET /api/players` — filtre : `country_code`
- `GET /api/players/:slug`
- `GET /api/matches/:id`
- `GET /api/rankings` — filtre `ranking_type` **obligatoire**
```

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: document Phase 3 REST endpoints"
```
