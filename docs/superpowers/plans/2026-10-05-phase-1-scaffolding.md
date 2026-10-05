# Tennis Atlas — Phase 1 : Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `docker compose up` boot three wired services — PostgreSQL, a Phoenix API, and a SvelteKit web app — with the web app proving connectivity by calling the API's health endpoint, which itself proves it can reach Postgres. No data model, no real UI yet — pure plumbing.

**Architecture:** A monorepo (`apps/web`, `apps/api`) managed by pnpm workspaces at the root. Each app runs in Docker Compose during development via a bind mount (source lives on the host, named volumes protect `deps`/`_build`/`node_modules` from being shadowed by the bind mount). No app code is baked into the Docker images — the images only provide the toolchain; Compose supplies the source via volumes. This means the only tool required on the host machine is Docker Desktop + Git — not Node, not Elixir.

**Tech Stack:** SvelteKit 5 (TypeScript, runes) · Phoenix (Elixir, latest stable, OTP 27) · Ecto · PostgreSQL 16 · pnpm workspaces · Docker Compose.

**Spec:** [docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md](../specs/2026-10-05-tennis-atlas-architecture-design.md)

## Global Constraints

- Frontend uses Svelte 5 (runes), TypeScript.
- Backend uses the latest stable Elixir + OTP 27 + Phoenix 1.7/1.8, Ecto, PostgreSQL.
- Monorepo JS tooling is pnpm workspaces only — no Turborepo, no Nx.
- No Redis.
- PostgreSQL is the only source of truth; the frontend never calls an external API directly (not exercised yet in Phase 1, no external tennis API is involved here).
- Phase 1 must work with only Docker Desktop, Docker Compose, and Git installed on the host — no local Node or Elixir required to scaffold or run anything.

---

### Task 1: Monorepo root scaffolding

**Files:**
- Create: `package.json`
- Create: `pnpm-workspace.yaml`
- Create: `.gitignore`
- Create: `.env.example`
- Create: `README.md`

**Interfaces:**
- Consumes: nothing (first task)
- Produces: the pnpm workspace root that Tasks 5/6 (`apps/web`) will join; the `.env.example` variable names (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT`, `API_PORT`, `WEB_PORT`, `PUBLIC_API_URL`) that Task 2's `docker-compose.yml` will consume.

- [ ] **Step 1: Create the root `package.json`**

```json
{
  "name": "tennis-atlas",
  "private": true,
  "version": "0.0.0",
  "packageManager": "pnpm@9.12.0"
}
```

- [ ] **Step 2: Create `pnpm-workspace.yaml`**

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

- [ ] **Step 3: Create `.gitignore`**

```
# Dependencies
node_modules/
apps/api/deps/
apps/api/_build/

# Build artifacts
apps/web/.svelte-kit/
apps/web/build/
apps/api/priv/static/assets/

# Environment
.env

# Elixir
*.ez
apps/api/erl_crash.dump

# OS
.DS_Store
Thumbs.db

# Editor
.vscode/
.idea/

# Dev tooling scratch (git worktrees, subagent-driven-development workspaces)
.worktrees/
.superpowers/
```

- [ ] **Step 4: Create `.env.example`**

```
# PostgreSQL
POSTGRES_USER=tennis_atlas
POSTGRES_PASSWORD=tennis_atlas_dev
POSTGRES_DB=tennis_atlas_dev
POSTGRES_PORT=5432

# Phoenix API
API_PORT=4000

# SvelteKit web
WEB_PORT=5173
PUBLIC_API_URL=http://localhost:4000
```

- [ ] **Step 5: Create `README.md`**

```markdown
# Tennis Atlas

Plateforme d'exploration du tennis mondial — projet portfolio.

## Stack

- Frontend : SvelteKit + TypeScript
- Backend : Phoenix (Elixir) + Ecto + PostgreSQL

Voir [docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md](docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md) pour le design complet.

## Développement local

(instructions à venir — Phase 1 en cours)
```

- [ ] **Step 6: Verify the structure**

Run: `ls -la` at repo root
Expected: `package.json`, `pnpm-workspace.yaml`, `.gitignore`, `.env.example`, `README.md`, `docs/` all present.

- [ ] **Step 7: Commit**

```bash
git add package.json pnpm-workspace.yaml .gitignore .env.example README.md
git commit -m "chore: scaffold monorepo root (pnpm workspace, env, gitignore)"
```

---

### Task 2: PostgreSQL via Docker Compose

**Files:**
- Create: `docker-compose.yml`

**Interfaces:**
- Consumes: `.env.example` variable names from Task 1 (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT`).
- Produces: a running `db` service on the Compose network, reachable as host `db` on port `5432` from other Compose services, and as `localhost:${POSTGRES_PORT}` from the host machine. Tasks 3+ depend on this service being healthy before connecting.

- [ ] **Step 1: Create `.env` from the example**

```bash
cp .env.example .env
```

- [ ] **Step 2: Create `docker-compose.yml`**

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "${POSTGRES_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:
```

- [ ] **Step 3: Start Postgres and verify it's healthy**

Run: `docker compose up -d db && sleep 5 && docker compose ps`
Expected: the `db` row shows `(healthy)`.

- [ ] **Step 4: Verify connectivity directly**

Run: `docker compose exec db pg_isready -U tennis_atlas`
Expected: output ends with `accepting connections`.

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: add PostgreSQL service to docker-compose"
```

(`.env` stays untracked — it's in `.gitignore` from Task 1.)

---

### Task 3: Phoenix API skeleton

**Files:**
- Create: `apps/api/` (generated by `mix phx.new`)
- Modify: `apps/api/config/dev.exs`
- Modify: `apps/api/config/test.exs`
- Create: `docker/api.Dockerfile`
- Modify: `docker-compose.yml`

**Interfaces:**
- Consumes: the `db` service from Task 2 (host `db`, port `5432`, credentials from `.env`).
- Produces: `TennisAtlasApi.Repo` (the Ecto repo module), reachable at container DNS name `api` on port `4000` inside the Compose network, and `localhost:${API_PORT}` from the host. Task 4 adds routes to this app; Task 6 (web) calls `http://localhost:${API_PORT}/api/health`.

- [ ] **Step 1: Generate the Phoenix project via a throwaway Docker container**

No Elixir needs to be installed on the host — this one-off container does the generation and then exits.

```bash
docker run --rm \
  -v "$(pwd)/apps:/workspace/apps" \
  -w /workspace/apps \
  elixir:1.17.3-otp-27-alpine \
  sh -c "apk add --no-cache build-base git > /dev/null && mix local.hex --force && mix local.rebar --force && mix archive.install hex phx_new --force && mix phx.new api --app tennis_atlas_api --no-html --no-assets --no-mailer --no-gettext --database postgres --install"
```

If `elixir:1.17.3-otp-27-alpine` no longer exists on Docker Hub by the time this runs, use the closest current Elixir 1.17.x / OTP 27 alpine tag listed at `hub.docker.com/_/elixir` — keep the same tag in `docker/api.Dockerfile` (Step 4) for consistency.

- [ ] **Step 2: Verify the project was generated**

Run: `ls apps/api`
Expected: `mix.exs`, `lib/`, `config/`, `test/`, `priv/` present.

- [ ] **Step 3: Parameterize the dev DB connection**

Open `apps/api/config/dev.exs`. Find the `config :tennis_atlas_api, TennisAtlasApi.Repo` block and replace it with:

```elixir
config :tennis_atlas_api, TennisAtlasApi.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "tennis_atlas_api_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

- [ ] **Step 4: Parameterize the test DB connection**

Open `apps/api/config/test.exs`. Find the `config :tennis_atlas_api, TennisAtlasApi.Repo` block and replace it with:

```elixir
config :tennis_atlas_api, TennisAtlasApi.Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "#{System.get_env("POSTGRES_DB", "tennis_atlas_api_test")}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
```

- [ ] **Step 5: Create `docker/api.Dockerfile`**

```dockerfile
FROM elixir:1.17.3-otp-27-alpine

RUN apk add --no-cache build-base git

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

CMD ["sh", "-c", "mix deps.get && mix ecto.create && mix ecto.migrate && mix phx.server"]
```

- [ ] **Step 6: Add the `api` service to `docker-compose.yml`**

Add this service alongside `db`, and add the two named volumes at the bottom:

```yaml
  api:
    build:
      context: .
      dockerfile: docker/api.Dockerfile
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_HOST: db
    ports:
      - "${API_PORT}:4000"
    volumes:
      - ./apps/api:/app
      - api_deps:/app/deps
      - api_build:/app/_build
    depends_on:
      db:
        condition: service_healthy
```

Full `volumes:` block at the bottom of the file becomes:

```yaml
volumes:
  postgres_data:
  api_deps:
  api_build:
```

- [ ] **Step 7: Build the image and create the database**

Run: `docker compose build api && docker compose run --rm api mix ecto.create`
Expected: exit code 0, output mentions the database was created (or already exists — both are fine).

- [ ] **Step 8: Boot the API and verify it's serving**

Run: `docker compose up -d api && sleep 5 && docker compose logs api --tail 30`
Expected: logs contain a line like `Running TennisAtlasApiWeb.Endpoint with cowboy`.

Run: `docker compose stop api`

- [ ] **Step 9: Commit**

```bash
git add apps/api docker/api.Dockerfile docker-compose.yml
git commit -m "feat: generate Phoenix API skeleton wired to Postgres via Docker"
```

---

### Task 4: `/api/health` endpoint with CORS

**Files:**
- Modify: `apps/api/mix.exs`
- Modify: `apps/api/lib/tennis_atlas_api_web/endpoint.ex`
- Modify: `apps/api/lib/tennis_atlas_api_web/router.ex`
- Create: `apps/api/lib/tennis_atlas_api_web/controllers/health_controller.ex`
- Test: `apps/api/test/tennis_atlas_api_web/controllers/health_controller_test.exs`

**Interfaces:**
- Consumes: `TennisAtlasApi.Repo` from Task 3.
- Produces: `GET /api/health` → `{"status": "ok", "database": "connected"}`. Task 6 (web homepage) calls this exact endpoint and reads these exact two JSON keys.

- [ ] **Step 1: Add the CORS dependency**

Open `apps/api/mix.exs`, find `defp deps do`, add this line to the list:

```elixir
      {:cors_plug, "~> 3.0"},
```

- [ ] **Step 2: Fetch the new dependency**

Run: `docker compose run --rm api mix deps.get`
Expected: exit code 0, `cors_plug` listed as fetched.

- [ ] **Step 3: Write the failing test**

Create `apps/api/test/tennis_atlas_api_web/controllers/health_controller_test.exs`:

```elixir
defmodule TennisAtlasApiWeb.HealthControllerTest do
  use TennisAtlasApiWeb.ConnCase, async: true

  test "GET /api/health returns ok status and confirms database connectivity", %{conn: conn} do
    conn = get(conn, ~p"/api/health")

    assert %{"status" => "ok", "database" => "connected"} = json_response(conn, 200)
  end
end
```

- [ ] **Step 4: Run it to verify it fails**

Run: `docker compose run --rm api sh -c "mix ecto.create --quiet; mix test test/tennis_atlas_api_web/controllers/health_controller_test.exs"`
Expected: FAIL — no route matches `GET /api/health` (404), since the route doesn't exist yet.

- [ ] **Step 5: Add the health controller**

Create `apps/api/lib/tennis_atlas_api_web/controllers/health_controller.ex`:

```elixir
defmodule TennisAtlasApiWeb.HealthController do
  use TennisAtlasApiWeb, :controller

  alias TennisAtlasApi.Repo

  def index(conn, _params) do
    database_status =
      case Ecto.Adapters.SQL.query(Repo, "SELECT 1", []) do
        {:ok, _result} -> "connected"
        {:error, _reason} -> "unavailable"
      end

    json(conn, %{status: "ok", database: database_status})
  end
end
```

- [ ] **Step 6: Wire the route**

Open `apps/api/lib/tennis_atlas_api_web/router.ex`. Inside the existing `scope "/api", TennisAtlasApiWeb do ... pipe_through :api ... end` block (create it if the generator didn't, using this exact shape), add:

```elixir
    get "/health", HealthController, :index
```

If the generated router has no `:api` scope yet, the full block should look like:

```elixir
  scope "/api", TennisAtlasApiWeb do
    pipe_through :api

    get "/health", HealthController, :index
  end
```

- [ ] **Step 7: Enable CORS for the SvelteKit dev origin**

Open `apps/api/lib/tennis_atlas_api_web/endpoint.ex`. Find the line `plug TennisAtlasApiWeb.Router` and add this line directly above it:

```elixir
  plug CorsPlug, origin: ["http://localhost:5173"]
```

- [ ] **Step 8: Run the test again to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/health_controller_test.exs`
Expected: PASS, 1 test, 0 failures.

- [ ] **Step 9: Verify over real HTTP**

Run: `docker compose up -d api && sleep 3 && curl -s http://localhost:4000/api/health`
Expected: `{"status":"ok","database":"connected"}`

Run: `docker compose stop api`

- [ ] **Step 10: Commit**

```bash
git add apps/api/mix.exs apps/api/mix.lock apps/api/lib/tennis_atlas_api_web/endpoint.ex apps/api/lib/tennis_atlas_api_web/router.ex apps/api/lib/tennis_atlas_api_web/controllers/health_controller.ex apps/api/test/tennis_atlas_api_web/controllers/health_controller_test.exs
git commit -m "feat: add /api/health endpoint with CORS for the web dev origin"
```

---

### Task 5: SvelteKit skeleton

**Files:**
- Create: `apps/web/` (generated by `sv create`)
- Create: `docker/web.Dockerfile`
- Modify: `docker-compose.yml`

**Interfaces:**
- Consumes: nothing from earlier tasks directly (generation step is standalone).
- Produces: a SvelteKit dev server reachable at `localhost:${WEB_PORT}`. Task 6 edits `apps/web/src/routes/+page.svelte`, which this task generates.

- [ ] **Step 1: Generate the SvelteKit project via a throwaway Docker container**

```bash
docker run --rm \
  -v "$(pwd)/apps:/workspace/apps" \
  -w /workspace/apps \
  node:22-alpine \
  sh -c "corepack enable && pnpm dlx sv create web --template minimal --types ts --no-add-ons --install pnpm"
```

- [ ] **Step 2: Verify the project was generated**

Run: `ls apps/web`
Expected: `package.json`, `src/`, `svelte.config.js`, `vite.config.ts` present.

- [ ] **Step 3: Create `docker/web.Dockerfile`**

```dockerfile
FROM node:22-alpine

RUN corepack enable

WORKDIR /app

CMD ["sh", "-c", "pnpm install && pnpm dev --host 0.0.0.0 --port 5173"]
```

- [ ] **Step 4: Add the `web` service to `docker-compose.yml`**

```yaml
  web:
    build:
      context: .
      dockerfile: docker/web.Dockerfile
    environment:
      PUBLIC_API_URL: ${PUBLIC_API_URL}
    ports:
      - "${WEB_PORT}:5173"
    volumes:
      - ./apps/web:/app
      - web_node_modules:/app/node_modules
    depends_on:
      - api
```

Add `web_node_modules:` to the `volumes:` block at the bottom, next to `api_deps:` and `api_build:`.

- [ ] **Step 5: Build and boot, verify it serves**

Run: `docker compose build web && docker compose up -d web && sleep 8 && curl -s -o /dev/null -w "%{http_code}" http://localhost:5173`
Expected: `200`

Run: `docker compose stop web`

- [ ] **Step 6: Commit**

```bash
git add apps/web docker/web.Dockerfile docker-compose.yml
git commit -m "feat: generate SvelteKit skeleton wired into docker-compose"
```

---

### Task 6: Homepage calls the health endpoint

**Files:**
- Modify: `apps/web/src/routes/+page.svelte`

**Interfaces:**
- Consumes: `GET /api/health` from Task 4, returning `{"status": "...", "database": "..."}`; `PUBLIC_API_URL` env var from `.env` (Task 1) via `$env/dynamic/public`.
- Produces: the Phase 1 homepage — nothing downstream in this plan depends on it, but Phase 4 (frontend design system) will replace this file's contents.

- [ ] **Step 1: Replace the homepage**

Open `apps/web/src/routes/+page.svelte` and replace its full contents with:

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { env } from '$env/dynamic/public';

  type HealthStatus = { status: string; database: string };

  let health = $state<HealthStatus | null>(null);
  let error = $state<string | null>(null);

  onMount(async () => {
    try {
      const res = await fetch(`${env.PUBLIC_API_URL}/api/health`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      health = await res.json();
    } catch (e) {
      error = e instanceof Error ? e.message : 'Unknown error';
    }
  });
</script>

<main>
  <h1>Tennis Atlas</h1>
  <p>Explore the world of tennis.</p>

  {#if error}
    <p>API unreachable: {error}</p>
  {:else if health}
    <p>API status: {health.status} — database: {health.database}</p>
  {:else}
    <p>Checking API connection…</p>
  {/if}
</main>
```

- [ ] **Step 2: Boot the full stack and verify the static part**

Run: `docker compose up -d db api web && sleep 8 && curl -s http://localhost:5173 | grep "Tennis Atlas"`
Expected: match found (the `<h1>` renders server-side regardless of the client-side fetch).

- [ ] **Step 3: Manual browser check (not automatable — do this yourself)**

Open `http://localhost:5173` in a browser. Expected: the page shows "Tennis Atlas", and within a second or two the line changes to "API status: ok — database: connected". This is the one step in this plan that proves the full browser → API → Postgres round trip; `curl` alone can't observe client-side `fetch` results.

- [ ] **Step 4: Stop the stack**

Run: `docker compose down`

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/routes/+page.svelte
git commit -m "feat: homepage calls /api/health to prove the full stack is wired"
```

---

### Task 7: Finalize README and verify the clean-start path

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: everything from Tasks 1-6.
- Produces: the onboarding path a reader (or Phase 2's implementer) follows to get the stack running.

- [ ] **Step 1: Replace the README's dev section**

Open `README.md` and replace its full contents with:

```markdown
# Tennis Atlas

Plateforme d'exploration du tennis mondial — projet portfolio démontrant une architecture full-stack avec SvelteKit, Phoenix/Elixir et PostgreSQL.

## Stack

- **Frontend** : SvelteKit 5 + TypeScript
- **Backend** : Phoenix (Elixir) + Ecto + PostgreSQL
- **Jobs & synchronisation** : Oban (à partir de la Phase 9)
- **Temps réel** : Phoenix PubSub + Channels (à partir de la Phase 11)

Voir [docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md](docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md) pour le design complet.

## Développement local

Prérequis : Docker Desktop + Git. Aucune installation locale de Node ou d'Elixir n'est nécessaire.

```bash
cp .env.example .env
docker compose up
```

- API : http://localhost:4000 (health check : `/api/health`)
- Web : http://localhost:5173

## Structure du monorepo

```
apps/
  web/        SvelteKit
  api/        Phoenix
packages/
  shared/     types partagés (à venir)
docker/       Dockerfiles de dev
docs/         specs et plans d'implémentation
```
```

- [ ] **Step 2: Verify the clean-start path end to end**

Run: `docker compose down -v` (tears down containers AND the named volumes, simulating a fresh clone)
Run: `docker compose up -d`
Run: `sleep 20 && curl -s http://localhost:4000/api/health && echo && curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5173`
Expected: `{"status":"ok","database":"connected"}` followed by `200`.

- [ ] **Step 3: Stop the stack**

Run: `docker compose down`

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: finalize README with local development instructions"
```

Phase 1 is complete once this task's verification passes: `docker compose up` on a clean checkout brings up all three services, and the browser check from Task 6 confirms the full round trip.
