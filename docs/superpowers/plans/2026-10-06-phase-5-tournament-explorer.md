# Tennis Atlas — Phase 5 : Tournament Explorer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tournament list (paginated, filterable by surface/category), a tournament detail page (Schedule/Players/Results tabs), and a player detail page — all server-side-rendered and consuming the Phase 3 API. Includes one small targeted Phase 3 backend addition (match sets in the edition-matches list endpoint) and a frontend fix (`ApiError` carrying the HTTP status) needed for proper 404 handling. No Draw, no surface theming, no match detail page — those are later phases.

**Architecture:** Backend: `MatchJSON`'s list response gains `sets` (already computed for the detail response, now shared). Frontend: the Phase 4 SSR-via-`load()` pattern continues — three new routes each get a `+page.server.ts` that calls the API client and either returns data or translates a 404 `ApiError` into SvelteKit's real `error(404, ...)`. Pagination/filter state lives entirely in the URL's query string (native `<form method="GET">`, no client JS). The one piece of non-trivial logic per page (deduplicating players from matches, building a pagination href that preserves active filters, formatting round/status/score) lives in plain `.ts` modules, kept unit-testable without `@testing-library/svelte` — same discipline as Phase 4.

**Tech Stack:** Elixir/Phoenix/Ecto (backend addition), SvelteKit 3 (Svelte 5 runes) + Tailwind v4 + Vitest (frontend, unchanged from Phase 4).

**Spec:** [docs/superpowers/specs/2026-10-06-phase-5-tournament-explorer-design.md](../specs/2026-10-06-phase-5-tournament-explorer-design.md) (scope decisions, exact DTO shapes, the `ApiError.status` fix rationale) and [docs/superpowers/specs/2026-10-06-phase-4-frontend-design.md](../specs/2026-10-06-phase-4-frontend-design.md) (the SSR/`#lib`/Tailwind conventions this plan continues).

## Global Constraints

- **`#lib`, not `$lib`.** This project's SvelteKit removed the classic `$lib` alias (discovered in Phase 4, confirmed by an actual build error) — every new frontend import across every task in this plan must use `#lib/...`.
- Players on a tournament's roster are **derived from its matches** (dedup `player_a`/`player_b`), not from a `tournament_entries` endpoint — none exists, and none is added.
- The tournament detail page shows **only the most recent edition** (`editions[0]`, already sorted newest-first by the API) — no year selector this phase.
- A 404 from the API on an individual resource (`GET /api/tournaments/:slug`, `GET /api/players/:slug`) must become SvelteKit's **real 404 page**, via `ApiError.status === 404` → `throw error(404, ...)` — never a generic 500, never a blank/empty-looking page.
- A **non**-404 API failure on an individual resource must **propagate unchanged** — never silently treated as "not found."
- Pagination and filters live in the **URL query string** (`?surface=&category=&page=`), read in `load({ url })`, submitted via a native `<form method="GET">` — no client-side fetch, no JS-driven state for this.
- Nav gains a "Tournois" link — the Phase 4 nav was deliberately minimal with exactly this intent ("add links phase by phase as real pages land"); `/tournaments` now exists.
- No Svelte component rendering tests this phase (consistent with Phase 4) — every non-trivial piece of logic is extracted into a plain, unit-tested `.ts` function first.
- All backend commands run via `docker compose run --rm api <cmd>`, all frontend commands via `docker compose run --rm web <cmd>`.

## Review Focus

- An unknown tournament or player slug must render SvelteKit's real 404 page, not a 500 or a blank page. Pinned in Tasks 6 and 7.
- A non-404 API failure (e.g. the API returning 500) on a tournament/player detail page must propagate as a real error, not get silently converted into a fake "not found." Pinned in Tasks 6 and 7.
- A player who appears in multiple matches of the same edition (won their earlier rounds) must appear exactly once in the Players tab, not once per match they played. Pinned in Task 4.
- Pagination links on the tournament list must preserve the active `surface`/`category` filters — clicking "Suivant" must not silently reset them. Pinned in Task 5.
- A tournament with no editions yet (`editions: []`, possible for freshly-created data) must render with an empty match list, not crash on `editions[0]`. Pinned in Task 6.

---

### Task 1: Backend — include sets in the edition-matches list response

**Files:**
- Modify: `apps/api/lib/tennis_atlas_api_web/controllers/match_json.ex`
- Modify: `apps/api/lib/tennis_atlas_api/tournaments.ex`
- Modify: `apps/api/test/tennis_atlas_api/tournaments_test.exs`
- Modify: `apps/api/test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs`

**Interfaces:**
- Consumes: nothing new (modifies existing Phase 3 code).
- Produces: `GET /api/tournaments/:slug/editions/:year/matches` now includes `sets` per match, matching the shape `GET /api/matches/:id` already produces. Frontend Task 3's `Match` type and Task 6's results tab depend on this field actually being present.

- [ ] **Step 1: Write the failing context test**

Modify `apps/api/test/tennis_atlas_api/tournaments_test.exs` — add this test inside the existing `describe "list_matches_for_edition/3"` block (after the "filters by tour" test, before the block's closing `end`):

```elixir
    test "preloads sets" do
      edition = tournament_edition_fixture(%{})
      match = match_fixture(%{tournament_edition_id: edition.id})
      set_fixture(%{match_id: match.id, set_number: 1, player_a_games: 6, player_b_games: 4})

      result = Tournaments.list_matches_for_edition(edition.id)

      assert [%{sets: [%{set_number: 1, player_a_games: 6, player_b_games: 4}]}] = result.entries
    end
```

(`match_fixture/1` and `set_fixture/1` are already imported in this file via `TennisAtlasApi.MatchesFixtures`.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments_test.exs`
Expected: FAIL — `result.entries`' matches have `sets: #Ecto.Association.NotLoaded<...>`, not a loaded list, so the pattern match fails.

- [ ] **Step 3: Add :sets to the preload**

Modify `apps/api/lib/tennis_atlas_api/tournaments.ex` — in `list_matches_for_edition/3`, change:

```elixir
    |> preload([:player_a, :player_b, :court])
```

to:

```elixir
    |> preload([:player_a, :player_b, :court, :sets])
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api/tournaments_test.exs`
Expected: PASS (11 tests, 0 failures).

- [ ] **Step 5: Write the failing controller test**

Modify `apps/api/test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs` — replace the "lists matches for the edition" test with:

```elixir
    test "lists matches for the edition, including each match's sets", %{conn: conn} do
      tournament = tournament_fixture(%{slug: "with-matches"})
      edition = tournament_edition_fixture(%{tournament_id: tournament.id, year: 2025})
      match = match_fixture(%{tournament_edition_id: edition.id})
      set_fixture(%{match_id: match.id, set_number: 1, player_a_games: 6, player_b_games: 4})

      conn = get(conn, ~p"/api/tournaments/with-matches/editions/2025/matches")

      assert %{"data" => [match_json]} = json_response(conn, 200)
      assert [%{"set_number" => 1, "player_a_games" => 6, "player_b_games" => 4}] = match_json["sets"]
    end
```

- [ ] **Step 6: Run the controller test to verify it fails**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs`
Expected: FAIL — `match_json["sets"]` is `nil` (the JSON view doesn't emit it yet), pattern match fails.

- [ ] **Step 7: Move sets into the shared summary**

Modify `apps/api/lib/tennis_atlas_api_web/controllers/match_json.ex` — change `summary/1` and `detail/1` from:

```elixir
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
```

to:

```elixir
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
      court: court_ref(m.court),
      sets: for(s <- m.sets, do: set_ref(s))
    }
  end

  defp detail(%Match{} = m) do
    Map.merge(summary(m), %{tournament: tournament_ref(m.tournament_edition)})
  end
```

- [ ] **Step 8: Run the controller test to verify it passes**

Run: `docker compose run --rm api mix test test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs`
Expected: PASS (4 tests, 0 failures).

- [ ] **Step 9: Run the full backend suite to check for regressions**

Run: `docker compose run --rm api mix test`
Expected: all tests pass (this change also affects `GET /api/matches/:id`'s response shape only in that `sets` is now computed via `summary/1` instead of inline in `detail/1` — same output, refactor only; the existing match-detail controller test should still pass unmodified).

- [ ] **Step 10: Commit**

```bash
git add apps/api/lib/tennis_atlas_api_web/controllers/match_json.ex apps/api/lib/tennis_atlas_api/tournaments.ex apps/api/test/tennis_atlas_api/tournaments_test.exs apps/api/test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs
git commit -m "feat: include sets in the edition-matches list response"
```

---

### Task 2: Frontend — ApiError carries the HTTP status

**Files:**
- Modify: `apps/web/src/lib/api/client.ts`
- Modify: `apps/web/src/lib/api/client.test.ts`

**Interfaces:**
- Consumes: nothing new.
- Produces: `ApiError` now has a public `status: number` field. Tasks 6 and 7's `load()` functions check `error.status === 404` to decide whether to render a real 404 page.

- [ ] **Step 1: Write the failing test**

Modify `apps/web/src/lib/api/client.test.ts` — replace the "throws ApiError on a non-ok response" test with:

```ts
	test('throws ApiError carrying the response status on a non-ok response', async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn().mockResolvedValue({ ok: false, status: 404, json: () => Promise.resolve({}) })
		);

		const thrown = await apiFetch('/api/tournaments/unknown').catch((e) => e);

		expect(thrown).toBeInstanceOf(ApiError);
		expect(thrown.status).toBe(404);
	});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `thrown.status` is `undefined` (TypeScript will also flag this at typecheck time, but the test itself fails at the assertion).

- [ ] **Step 3: Add the status field**

Modify `apps/web/src/lib/api/client.ts`:

```ts
import { API_INTERNAL_URL } from '$app/env/private';

export class ApiError extends Error {
	status: number;

	constructor(message: string, status: number) {
		super(message);
		this.status = status;
	}
}

export async function apiFetch<T>(path: string): Promise<T> {
	const res = await fetch(`${API_INTERNAL_URL}${path}`);

	if (!res.ok) {
		throw new ApiError(`API request failed: ${res.status} ${path}`, res.status);
	}

	return res.json() as Promise<T>;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/api/client.ts apps/web/src/lib/api/client.test.ts
git commit -m "feat: give ApiError a status field for 404 handling"
```

---

### Task 3: Frontend — API client types and functions

**Files:**
- Modify: `apps/web/src/lib/api/types.ts`
- Modify: `apps/web/src/lib/api/tournaments.ts`
- Modify: `apps/web/src/lib/api/tournaments.test.ts`
- Create: `apps/web/src/lib/api/players.ts`
- Test: `apps/web/src/lib/api/players.test.ts`

**Interfaces:**
- Consumes: `apiFetch` (Task 2's version, with `ApiError.status`).
- Produces: `MatchSet`, `PlayerRef`, `CourtRef`, `Match`, `TournamentEdition`, `TournamentDetail`, `Player`, `PageMeta` types; `listTournaments(params)`, `getTournament(slug)`, `getMatchesForEdition(slug, year)`, `getPlayer(slug)` — consumed by Tasks 4, 5, 6, 7.

- [ ] **Step 1: Add the new types**

Modify `apps/web/src/lib/api/types.ts` — append after the existing `Tournament` type:

```ts
// Named `MatchSet`, not `Set` — `Set` would shadow the built-in JS/TS type.
export type MatchSet = {
	set_number: number;
	player_a_games: number;
	player_b_games: number;
	tiebreak_a: number | null;
	tiebreak_b: number | null;
};

export type PlayerRef = {
	id: number;
	first_name: string;
	last_name: string;
	slug: string;
};

export type CourtRef = {
	id: number;
	name: string;
	surface: string;
};

export type Match = {
	id: number;
	tour: string;
	round: string;
	status: string;
	scheduled_at: string | null;
	started_at: string | null;
	finished_at: string | null;
	best_of: number;
	winner_id: number | null;
	player_a: PlayerRef | null;
	player_b: PlayerRef | null;
	court: CourtRef | null;
	sets: MatchSet[];
};

export type TournamentEdition = {
	id: number;
	year: number;
	start_date: string;
	end_date: string;
	status: string;
};

export type TournamentDetail = Tournament & {
	description: string | null;
	logo_url: string | null;
	hero_image_url: string | null;
	editions: TournamentEdition[];
};

export type Player = {
	id: number;
	first_name: string;
	last_name: string;
	slug: string;
	country_code: string;
	current_ranking: number | null;
	current_ranking_points: number | null;
	birth_date: string | null;
	hand: string | null;
	height_cm: number | null;
};

export type PageMeta = {
	page: number;
	page_size: number;
	total_count: number;
	total_pages: number;
};
```

- [ ] **Step 2: Write the failing tests for the new tournaments.ts functions**

Modify `apps/web/src/lib/api/tournaments.test.ts` — append:

```ts
import { listTournaments, getTournament, getMatchesForEdition } from './tournaments';

describe('listTournaments', () => {
	test('builds the query string from the given filters and page', async () => {
		const tournaments = [
			{ id: 1, name: 'A', slug: 'a', category: 'atp_250', surface: 'hard', venue: null }
		];
		const meta = { page: 2, page_size: 20, total_count: 1, total_pages: 1 };
		vi.mocked(apiFetch).mockResolvedValue({ data: tournaments, meta });

		const result = await listTournaments({ surface: 'clay', category: 'grand_slam', page: 2 });

		expect(apiFetch).toHaveBeenCalledWith(
			'/api/tournaments?surface=clay&category=grand_slam&page=2'
		);
		expect(result).toEqual({ tournaments, meta });
	});

	test('omits unset filters from the query string', async () => {
		const meta = { page: 1, page_size: 20, total_count: 0, total_pages: 0 };
		vi.mocked(apiFetch).mockResolvedValue({ data: [], meta });

		await listTournaments({});

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments?');
	});
});

describe('getTournament', () => {
	test('fetches /api/tournaments/:slug and returns the detail payload', async () => {
		const tournament = {
			id: 1,
			name: 'A',
			slug: 'a',
			category: 'grand_slam',
			surface: 'clay',
			venue: null,
			description: null,
			logo_url: null,
			hero_image_url: null,
			editions: []
		};
		vi.mocked(apiFetch).mockResolvedValue({ data: tournament });

		const result = await getTournament('a');

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments/a');
		expect(result).toEqual(tournament);
	});
});

describe('getMatchesForEdition', () => {
	test('fetches the edition matches with a large page_size', async () => {
		vi.mocked(apiFetch).mockResolvedValue({ data: [] });

		const result = await getMatchesForEdition('a', 2025);

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments/a/editions/2025/matches?page_size=100');
		expect(result).toEqual([]);
	});
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `listTournaments`, `getTournament`, `getMatchesForEdition` are undefined.

- [ ] **Step 4: Implement the new functions**

Modify `apps/web/src/lib/api/tournaments.ts`:

```ts
import { apiFetch } from './client';
import type { Tournament, TournamentDetail, Match, PageMeta } from './types';

export async function getTournaments(): Promise<Tournament[]> {
	const { data } = await apiFetch<{ data: Tournament[] }>('/api/tournaments');
	return data;
}

export async function listTournaments(params: {
	surface?: string;
	category?: string;
	page?: number;
}): Promise<{ tournaments: Tournament[]; meta: PageMeta }> {
	const query = new URLSearchParams();
	if (params.surface) query.set('surface', params.surface);
	if (params.category) query.set('category', params.category);
	if (params.page) query.set('page', String(params.page));

	const { data, meta } = await apiFetch<{ data: Tournament[]; meta: PageMeta }>(
		`/api/tournaments?${query.toString()}`
	);
	return { tournaments: data, meta };
}

export async function getTournament(slug: string): Promise<TournamentDetail> {
	const { data } = await apiFetch<{ data: TournamentDetail }>(`/api/tournaments/${slug}`);
	return data;
}

export async function getMatchesForEdition(slug: string, year: number): Promise<Match[]> {
	const { data } = await apiFetch<{ data: Match[] }>(
		`/api/tournaments/${slug}/editions/${year}/matches?page_size=100`
	);
	return data;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 6: Write the failing test for getPlayer**

Create `apps/web/src/lib/api/players.test.ts`:

```ts
import { describe, expect, test, vi } from 'vitest';

vi.mock('./client', () => ({ apiFetch: vi.fn() }));

import { apiFetch } from './client';
import { getPlayer } from './players';

describe('getPlayer', () => {
	test('fetches /api/players/:slug and returns the player', async () => {
		const player = {
			id: 1,
			first_name: 'Mateo',
			last_name: 'Rivera',
			slug: 'mateo-rivera',
			country_code: 'ESP',
			current_ranking: 3,
			current_ranking_points: 4500,
			birth_date: '1998-04-02',
			hand: 'right',
			height_cm: 185
		};
		vi.mocked(apiFetch).mockResolvedValue({ data: player });

		const result = await getPlayer('mateo-rivera');

		expect(apiFetch).toHaveBeenCalledWith('/api/players/mateo-rivera');
		expect(result).toEqual(player);
	});
});
```

- [ ] **Step 7: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./players` does not exist yet.

- [ ] **Step 8: Implement getPlayer**

Create `apps/web/src/lib/api/players.ts`:

```ts
import { apiFetch } from './client';
import type { Player } from './types';

export async function getPlayer(slug: string): Promise<Player> {
	const { data } = await apiFetch<{ data: Player }>(`/api/players/${slug}`);
	return data;
}
```

- [ ] **Step 9: Run the full suite to verify everything passes**

Run: `docker compose run --rm web pnpm test`
Expected: all tests pass.

- [ ] **Step 10: Commit**

```bash
git add apps/web/src/lib/api/types.ts apps/web/src/lib/api/tournaments.ts apps/web/src/lib/api/tournaments.test.ts apps/web/src/lib/api/players.ts apps/web/src/lib/api/players.test.ts
git commit -m "feat: add Match/Player/TournamentDetail types and API client functions"
```

---

### Task 4: Frontend — formatters and player-from-matches logic

**Files:**
- Modify: `apps/web/src/lib/format.ts`
- Modify: `apps/web/src/lib/format.test.ts`
- Create: `apps/web/src/lib/tournament.ts`
- Test: `apps/web/src/lib/tournament.test.ts`

**Interfaces:**
- Consumes: `MatchSet`, `Match`, `PlayerRef` types (Task 3).
- Produces: `formatRound`, `formatMatchStatus`, `formatScore`, `formatHand` (all in `lib/format.ts`), `playersFromMatches` (`lib/tournament.ts`) — consumed by Task 5 (list page, via existing `formatCategory`/`formatSurface`), Task 6 (match display, roster), Task 7 (player page, `formatHand`).

- [ ] **Step 1: Write the failing formatter tests**

Modify `apps/web/src/lib/format.test.ts` — append:

```ts
import { formatRound, formatMatchStatus, formatScore, formatHand } from './format';

describe('formatRound', () => {
	test.each([
		['r128', '128e de finale'],
		['r64', '64e de finale'],
		['r32', '32e de finale'],
		['r16', '8e de finale'],
		['qf', 'Quart de finale'],
		['sf', 'Demi-finale'],
		['f', 'Finale']
	])('maps %s to %s', (input, expected) => {
		expect(formatRound(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped round', () => {
		expect(formatRound('r256')).toBe('r256');
	});
});

describe('formatMatchStatus', () => {
	test.each([
		['scheduled', 'Programmé'],
		['live', 'En direct'],
		['finished', 'Terminé'],
		['retired', 'Abandon'],
		['walkover', 'Forfait'],
		['cancelled', 'Annulé']
	])('maps %s to %s', (input, expected) => {
		expect(formatMatchStatus(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped status', () => {
		expect(formatMatchStatus('postponed')).toBe('postponed');
	});
});

describe('formatScore', () => {
	test('formats a straight-sets score', () => {
		const sets = [
			{ set_number: 1, player_a_games: 6, player_b_games: 4, tiebreak_a: null, tiebreak_b: null },
			{ set_number: 2, player_a_games: 6, player_b_games: 3, tiebreak_a: null, tiebreak_b: null }
		];
		expect(formatScore(sets)).toBe('6-4, 6-3');
	});

	test('formats a tiebreak set with the loser tiebreak points', () => {
		const sets = [{ set_number: 1, player_a_games: 7, player_b_games: 6, tiebreak_a: 7, tiebreak_b: 5 }];
		expect(formatScore(sets)).toBe('7-6(5)');
	});

	test('orders sets by set_number regardless of input order', () => {
		const sets = [
			{ set_number: 2, player_a_games: 6, player_b_games: 3, tiebreak_a: null, tiebreak_b: null },
			{ set_number: 1, player_a_games: 6, player_b_games: 4, tiebreak_a: null, tiebreak_b: null }
		];
		expect(formatScore(sets)).toBe('6-4, 6-3');
	});
});

describe('formatHand', () => {
	test.each([
		['left', 'Gaucher'],
		['right', 'Droitier']
	])('maps %s to %s', (input, expected) => {
		expect(formatHand(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped hand', () => {
		expect(formatHand('ambidextrous')).toBe('ambidextrous');
	});
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `formatRound`, `formatMatchStatus`, `formatScore`, `formatHand` are undefined.

- [ ] **Step 3: Implement the formatters**

Modify `apps/web/src/lib/format.ts` — append (keep the existing `CATEGORY_LABELS`/`SURFACE_LABELS`/`formatCategory`/`formatSurface` unchanged):

```ts
import type { MatchSet } from './api/types';

const ROUND_LABELS: Record<string, string> = {
	r128: '128e de finale',
	r64: '64e de finale',
	r32: '32e de finale',
	r16: '8e de finale',
	qf: 'Quart de finale',
	sf: 'Demi-finale',
	f: 'Finale'
};

const MATCH_STATUS_LABELS: Record<string, string> = {
	scheduled: 'Programmé',
	live: 'En direct',
	finished: 'Terminé',
	retired: 'Abandon',
	walkover: 'Forfait',
	cancelled: 'Annulé'
};

const HAND_LABELS: Record<string, string> = {
	left: 'Gaucher',
	right: 'Droitier'
};

export function formatRound(round: string): string {
	return ROUND_LABELS[round] ?? round;
}

export function formatMatchStatus(status: string): string {
	return MATCH_STATUS_LABELS[status] ?? status;
}

export function formatHand(hand: string): string {
	return HAND_LABELS[hand] ?? hand;
}

export function formatScore(sets: MatchSet[]): string {
	return [...sets]
		.sort((a, b) => a.set_number - b.set_number)
		.map((s) => {
			const base = `${s.player_a_games}-${s.player_b_games}`;
			return s.tiebreak_a !== null && s.tiebreak_b !== null
				? `${base}(${Math.min(s.tiebreak_a, s.tiebreak_b)})`
				: base;
		})
		.join(', ');
}
```

(`[...sets].sort(...)` — spread into a new array before sorting, so `formatScore` never mutates the caller's array.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 5: Write the failing test for playersFromMatches**

Create `apps/web/src/lib/tournament.test.ts`:

```ts
import { describe, expect, test } from 'vitest';
import { playersFromMatches } from './tournament';
import type { Match } from './api/types';

function buildMatch(overrides: Partial<Match> = {}): Match {
	return {
		id: 1,
		tour: 'atp',
		round: 'qf',
		status: 'finished',
		scheduled_at: null,
		started_at: null,
		finished_at: null,
		best_of: 3,
		winner_id: null,
		player_a: null,
		player_b: null,
		court: null,
		sets: [],
		...overrides
	};
}

describe('playersFromMatches', () => {
	test('deduplicates a player who appears in multiple matches', () => {
		const alice = { id: 1, first_name: 'Alice', last_name: 'Martin', slug: 'alice-martin' };
		const bob = { id: 2, first_name: 'Bob', last_name: 'Nguyen', slug: 'bob-nguyen' };
		const matches = [
			buildMatch({ id: 1, player_a: alice, player_b: bob }),
			buildMatch({ id: 2, player_a: alice, player_b: null })
		];

		const result = playersFromMatches(matches);

		expect(result).toHaveLength(2);
		expect(result.map((p) => p.id).sort()).toEqual([1, 2]);
	});

	test('sorts by last name', () => {
		const nguyen = { id: 1, first_name: 'Bob', last_name: 'Nguyen', slug: 'bob-nguyen' };
		const martin = { id: 2, first_name: 'Alice', last_name: 'Martin', slug: 'alice-martin' };
		const matches = [buildMatch({ player_a: nguyen, player_b: martin })];

		const result = playersFromMatches(matches);

		expect(result.map((p) => p.last_name)).toEqual(['Martin', 'Nguyen']);
	});

	test('ignores null players (byes)', () => {
		const matches = [buildMatch({ player_a: null, player_b: null })];

		expect(playersFromMatches(matches)).toEqual([]);
	});
});
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./tournament` does not exist yet.

- [ ] **Step 7: Implement playersFromMatches**

Create `apps/web/src/lib/tournament.ts`:

```ts
import type { Match, PlayerRef } from './api/types';

export function playersFromMatches(matches: Match[]): PlayerRef[] {
	const byId = new Map<number, PlayerRef>();

	for (const match of matches) {
		if (match.player_a) byId.set(match.player_a.id, match.player_a);
		if (match.player_b) byId.set(match.player_b.id, match.player_b);
	}

	return [...byId.values()].sort((a, b) => a.last_name.localeCompare(b.last_name));
}
```

- [ ] **Step 8: Run the full suite to verify everything passes**

Run: `docker compose run --rm web pnpm test`
Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/lib/format.ts apps/web/src/lib/format.test.ts apps/web/src/lib/tournament.ts apps/web/src/lib/tournament.test.ts
git commit -m "feat: add round/status/score/hand formatters and playersFromMatches"
```

---

### Task 5: Frontend — tournament list page

**Files:**
- Create: `apps/web/src/lib/pagination.ts`
- Test: `apps/web/src/lib/pagination.test.ts`
- Create: `apps/web/src/lib/components/Pagination.svelte`
- Create: `apps/web/src/lib/components/FilterForm.svelte`
- Modify: `apps/web/src/lib/components/TournamentCard.svelte`
- Create: `apps/web/src/routes/tournaments/+page.server.ts`
- Test: `apps/web/src/routes/tournaments/+page.server.test.ts`
- Create: `apps/web/src/routes/tournaments/+page.svelte`
- Modify: `apps/web/src/lib/components/Nav.svelte`

**Interfaces:**
- Consumes: `listTournaments` (Task 3), `formatCategory`/`formatSurface` (Phase 4, unchanged).
- Produces: `/tournaments` route. `tournamentsHref` (`lib/pagination.ts`) consumed only within this task's own `+page.svelte`. Nothing later depends on this task.

- [ ] **Step 1: Write the failing test for the href builder**

Create `apps/web/src/lib/pagination.test.ts`:

```ts
import { describe, expect, test } from 'vitest';
import { tournamentsHref } from './pagination';

describe('tournamentsHref', () => {
	test('includes the page number', () => {
		expect(tournamentsHref({}, 2)).toBe('/tournaments?page=2');
	});

	test('preserves the surface filter across pages', () => {
		expect(tournamentsHref({ surface: 'clay' }, 3)).toBe('/tournaments?surface=clay&page=3');
	});

	test('preserves both filters across pages', () => {
		expect(tournamentsHref({ surface: 'clay', category: 'grand_slam' }, 1)).toBe(
			'/tournaments?surface=clay&category=grand_slam&page=1'
		);
	});

	test('omits unset filters', () => {
		expect(tournamentsHref({ surface: undefined, category: undefined }, 1)).toBe(
			'/tournaments?page=1'
		);
	});
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./pagination` does not exist yet.

- [ ] **Step 3: Implement tournamentsHref**

Create `apps/web/src/lib/pagination.ts`:

```ts
export function tournamentsHref(
	filters: { surface?: string; category?: string },
	page: number
): string {
	const params = new URLSearchParams();
	if (filters.surface) params.set('surface', filters.surface);
	if (filters.category) params.set('category', filters.category);
	params.set('page', String(page));
	return `/tournaments?${params.toString()}`;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 5: Write the failing test for the list page's load function**

Create `apps/web/src/routes/tournaments/+page.server.test.ts`:

```ts
import { describe, expect, test, vi } from 'vitest';

vi.mock('#lib/api/tournaments', () => ({ listTournaments: vi.fn() }));

import { listTournaments } from '#lib/api/tournaments';
import { load } from './+page.server';

function buildEvent(search: string) {
	return { url: new URL(`http://localhost/tournaments${search}`) } as unknown as Parameters<
		typeof load
	>[0];
}

describe('load', () => {
	test('passes filters and page parsed from the URL to listTournaments', async () => {
		const meta = { page: 2, page_size: 20, total_count: 5, total_pages: 1 };
		vi.mocked(listTournaments).mockResolvedValue({ tournaments: [], meta });

		await load(buildEvent('?surface=clay&category=grand_slam&page=2'));

		expect(listTournaments).toHaveBeenCalledWith({
			surface: 'clay',
			category: 'grand_slam',
			page: 2
		});
	});

	test('passes undefined filters and page when the URL has none', async () => {
		const meta = { page: 1, page_size: 20, total_count: 0, total_pages: 0 };
		vi.mocked(listTournaments).mockResolvedValue({ tournaments: [], meta });

		await load(buildEvent(''));

		expect(listTournaments).toHaveBeenCalledWith({
			surface: undefined,
			category: undefined,
			page: undefined
		});
	});

	test('returns tournaments, meta, and the active filters', async () => {
		const meta = { page: 1, page_size: 20, total_count: 1, total_pages: 1 };
		const tournaments = [
			{ id: 1, name: 'A', slug: 'a', category: 'atp_250', surface: 'hard', venue: null }
		];
		vi.mocked(listTournaments).mockResolvedValue({ tournaments, meta });

		const result = await load(buildEvent('?surface=hard'));

		expect(result).toEqual({
			tournaments,
			meta,
			filters: { surface: 'hard', category: undefined }
		});
	});
});
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./+page.server` does not exist yet.

- [ ] **Step 7: Implement the load function**

Create `apps/web/src/routes/tournaments/+page.server.ts`:

```ts
import { listTournaments } from '#lib/api/tournaments';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ url }) => {
	const surface = url.searchParams.get('surface') ?? undefined;
	const category = url.searchParams.get('category') ?? undefined;
	const pageParam = url.searchParams.get('page');
	const page = pageParam ? Number(pageParam) : undefined;

	const { tournaments, meta } = await listTournaments({ surface, category, page });

	return { tournaments, meta, filters: { surface, category } };
};
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 9: Create the Pagination and FilterForm components**

Create `apps/web/src/lib/components/Pagination.svelte`:

```svelte
<script lang="ts">
	let {
		page,
		totalPages,
		hrefForPage
	}: { page: number; totalPages: number; hrefForPage: (page: number) => string } = $props();
</script>

<nav class="mt-8 flex items-center justify-center gap-4 text-sm">
	{#if page > 1}
		<a href={hrefForPage(page - 1)} class="underline">Précédent</a>
	{:else}
		<span class="text-neutral-400">Précédent</span>
	{/if}

	<span>Page {page} / {Math.max(totalPages, 1)}</span>

	{#if page < totalPages}
		<a href={hrefForPage(page + 1)} class="underline">Suivant</a>
	{:else}
		<span class="text-neutral-400">Suivant</span>
	{/if}
</nav>
```

Create `apps/web/src/lib/components/FilterForm.svelte`:

```svelte
<script lang="ts">
	let { filters }: { filters: { surface?: string; category?: string } } = $props();
</script>

<form method="GET" class="mt-6 flex flex-wrap items-end gap-4">
	<label class="flex flex-col text-sm text-neutral-600">
		Surface
		<select
			name="surface"
			value={filters.surface ?? ''}
			class="mt-1 rounded border border-neutral-300 px-2 py-1"
		>
			<option value="">Toutes</option>
			<option value="clay">Terre battue</option>
			<option value="grass">Gazon</option>
			<option value="hard">Dur</option>
			<option value="indoor">Indoor</option>
		</select>
	</label>

	<label class="flex flex-col text-sm text-neutral-600">
		Catégorie
		<select
			name="category"
			value={filters.category ?? ''}
			class="mt-1 rounded border border-neutral-300 px-2 py-1"
		>
			<option value="">Toutes</option>
			<option value="grand_slam">Grand Chelem</option>
			<option value="masters_1000">Masters 1000</option>
			<option value="atp_500">ATP 500</option>
			<option value="atp_250">ATP 250</option>
			<option value="wta_1000">WTA 1000</option>
			<option value="wta_500">WTA 500</option>
			<option value="wta_250">WTA 250</option>
		</select>
	</label>

	<button type="submit" class="rounded bg-accent px-4 py-1 text-white">Filtrer</button>
</form>
```

- [ ] **Step 10: Make TournamentCard clickable**

Modify `apps/web/src/lib/components/TournamentCard.svelte`:

```svelte
<script lang="ts">
	import { formatCategory, formatSurface } from '#lib/format';
	import type { Tournament } from '#lib/api/types';

	let { tournament }: { tournament: Tournament } = $props();
</script>

<a href="/tournaments/{tournament.slug}" class="block">
	<article
		class="rounded-lg border border-neutral-200 p-5 transition-colors hover:border-neutral-400"
	>
		<h3 class="font-semibold text-neutral-900">{tournament.name}</h3>
		<p class="mt-1 text-sm text-neutral-500">
			{formatCategory(tournament.category)} · {formatSurface(tournament.surface)}
		</p>
	</article>
</a>
```

(The homepage's `FeaturedTournaments` renders `TournamentCard` unchanged — it now links out, which is a correct, expected side effect, not a regression.)

- [ ] **Step 11: Create the list page**

Create `apps/web/src/routes/tournaments/+page.svelte`:

```svelte
<script lang="ts">
	import Pagination from '#lib/components/Pagination.svelte';
	import FilterForm from '#lib/components/FilterForm.svelte';
	import TournamentCard from '#lib/components/TournamentCard.svelte';
	import { tournamentsHref } from '#lib/pagination';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	function hrefForPage(page: number): string {
		return tournamentsHref(data.filters, page);
	}
</script>

<section class="mx-auto max-w-5xl px-4 py-12">
	<h1 class="text-2xl font-semibold text-neutral-900">Tournois</h1>

	<FilterForm filters={data.filters} />

	{#if data.tournaments.length === 0}
		<p class="mt-6 text-neutral-500">Aucun tournoi ne correspond à ces filtres.</p>
	{:else}
		<div class="mt-6 grid gap-4 sm:grid-cols-3">
			{#each data.tournaments as tournament (tournament.id)}
				<TournamentCard {tournament} />
			{/each}
		</div>
		<Pagination page={data.meta.page} totalPages={data.meta.total_pages} {hrefForPage} />
	{/if}
</section>
```

- [ ] **Step 12: Add the Nav link**

Modify `apps/web/src/lib/components/Nav.svelte`:

```svelte
<nav class="border-b border-neutral-200 bg-white">
	<div class="mx-auto flex max-w-5xl items-center gap-6 px-4 py-4">
		<a href="/" class="text-lg font-bold text-neutral-900">Tennis Atlas</a>
		<a href="/tournaments" class="text-sm text-neutral-600 hover:text-neutral-900">Tournois</a>
	</div>
</nav>
```

- [ ] **Step 13: Verify the build and typecheck pass**

Run: `docker compose run --rm web pnpm check`
Expected: exit code 0, no type errors.

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

- [ ] **Step 14: Run the full suite to check for regressions**

Run: `docker compose run --rm web pnpm test`
Expected: all tests pass.

- [ ] **Step 15: Commit**

```bash
git add apps/web/src/lib/pagination.ts apps/web/src/lib/pagination.test.ts apps/web/src/lib/components/Pagination.svelte apps/web/src/lib/components/FilterForm.svelte apps/web/src/lib/components/TournamentCard.svelte apps/web/src/routes/tournaments/+page.server.ts apps/web/src/routes/tournaments/+page.server.test.ts apps/web/src/routes/tournaments/+page.svelte apps/web/src/lib/components/Nav.svelte
git commit -m "feat: add the tournament list page"
```

---

### Task 6: Frontend — tournament detail page

**Files:**
- Create: `apps/web/src/lib/components/MatchRow.svelte`
- Create: `apps/web/src/lib/components/MatchList.svelte`
- Create: `apps/web/src/lib/components/PlayerRow.svelte`
- Create: `apps/web/src/routes/tournaments/[slug]/+page.server.ts`
- Test: `apps/web/src/routes/tournaments/[slug]/+page.server.test.ts`
- Create: `apps/web/src/routes/tournaments/[slug]/+page.svelte`

**Interfaces:**
- Consumes: `getTournament`, `getMatchesForEdition` (Task 3), `ApiError` (Task 2), `formatRound`, `formatMatchStatus`, `formatScore` (Task 4), `playersFromMatches` (Task 4).
- Produces: `/tournaments/[slug]` route. Nothing later depends on this task.

- [ ] **Step 1: Write the failing test for the detail page's load function**

Create `apps/web/src/routes/tournaments/[slug]/+page.server.test.ts`:

```ts
import { describe, expect, test, vi } from 'vitest';

vi.mock('#lib/api/tournaments', () => ({
	getTournament: vi.fn(),
	getMatchesForEdition: vi.fn()
}));

import { ApiError } from '#lib/api/client';
import { getTournament, getMatchesForEdition } from '#lib/api/tournaments';
import { load } from './+page.server';

function buildEvent(slug: string) {
	return { params: { slug } } as unknown as Parameters<typeof load>[0];
}

describe('load', () => {
	test('loads the tournament and its latest edition matches', async () => {
		const tournament = {
			id: 1,
			name: 'Roland Garros',
			slug: 'roland-garros',
			category: 'grand_slam',
			surface: 'clay',
			venue: null,
			description: null,
			logo_url: null,
			hero_image_url: null,
			editions: [
				{ id: 1, year: 2025, start_date: '2025-05-25', end_date: '2025-06-08', status: 'completed' }
			]
		};
		vi.mocked(getTournament).mockResolvedValue(tournament);
		vi.mocked(getMatchesForEdition).mockResolvedValue([]);

		const result = await load(buildEvent('roland-garros'));

		expect(getMatchesForEdition).toHaveBeenCalledWith('roland-garros', 2025);
		expect(result).toEqual({ tournament, edition: tournament.editions[0], matches: [] });
	});

	test('returns an empty match list without calling getMatchesForEdition when there are no editions', async () => {
		const tournament = {
			id: 1,
			name: 'New Tournament',
			slug: 'new-tournament',
			category: 'atp_250',
			surface: 'hard',
			venue: null,
			description: null,
			logo_url: null,
			hero_image_url: null,
			editions: []
		};
		vi.mocked(getTournament).mockResolvedValue(tournament);

		const result = await load(buildEvent('new-tournament'));

		expect(getMatchesForEdition).not.toHaveBeenCalled();
		expect(result).toEqual({ tournament, edition: null, matches: [] });
	});

	test('throws a SvelteKit 404 when the tournament API call returns 404', async () => {
		vi.mocked(getTournament).mockRejectedValue(
			new ApiError('API request failed: 404 /api/tournaments/unknown', 404)
		);

		await expect(load(buildEvent('unknown'))).rejects.toMatchObject({ status: 404 });
	});

	test('re-throws a non-404 ApiError unchanged', async () => {
		const serverError = new ApiError('API request failed: 500 /api/tournaments/x', 500);
		vi.mocked(getTournament).mockRejectedValue(serverError);

		await expect(load(buildEvent('x'))).rejects.toBe(serverError);
	});
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./+page.server` does not exist yet.

- [ ] **Step 3: Implement the load function**

Create `apps/web/src/routes/tournaments/[slug]/+page.server.ts`:

```ts
import { error } from '@sveltejs/kit';
import { ApiError } from '#lib/api/client';
import { getTournament, getMatchesForEdition } from '#lib/api/tournaments';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	let tournament;
	try {
		tournament = await getTournament(params.slug);
	} catch (e) {
		if (e instanceof ApiError && e.status === 404) {
			throw error(404, 'Tournoi introuvable');
		}
		throw e;
	}

	const edition = tournament.editions[0] ?? null;
	const matches = edition ? await getMatchesForEdition(params.slug, edition.year) : [];

	return { tournament, edition, matches };
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 5: Create MatchRow and MatchList**

Create `apps/web/src/lib/components/MatchRow.svelte`:

```svelte
<script lang="ts">
	import { formatMatchStatus, formatScore } from '#lib/format';
	import type { Match, PlayerRef } from '#lib/api/types';

	let { match }: { match: Match } = $props();

	function playerLabel(player: PlayerRef | null): string {
		return player ? `${player.first_name} ${player.last_name}` : 'BYE';
	}
</script>

<div class="flex items-center justify-between border-b border-neutral-100 py-2 text-sm">
	<div class="flex gap-2">
		<span
			class={match.winner_id === match.player_a?.id
				? 'font-semibold text-neutral-900'
				: 'text-neutral-700'}
		>
			{playerLabel(match.player_a)}
		</span>
		<span class="text-neutral-400">vs</span>
		<span
			class={match.winner_id === match.player_b?.id
				? 'font-semibold text-neutral-900'
				: 'text-neutral-700'}
		>
			{playerLabel(match.player_b)}
		</span>
	</div>
	<div class="flex gap-3 text-neutral-500">
		{#if match.sets.length > 0}
			<span>{formatScore(match.sets)}</span>
		{/if}
		<span>{formatMatchStatus(match.status)}</span>
	</div>
</div>
```

Create `apps/web/src/lib/components/MatchList.svelte`:

```svelte
<script lang="ts">
	import { formatRound } from '#lib/format';
	import MatchRow from './MatchRow.svelte';
	import type { Match } from '#lib/api/types';

	let { matches, emptyMessage }: { matches: Match[]; emptyMessage: string } = $props();

	const ROUND_ORDER = ['r128', 'r64', 'r32', 'r16', 'qf', 'sf', 'f'];

	function groupByRound(items: Match[]): Array<{ round: string; matches: Match[] }> {
		const groups = new Map<string, Match[]>();
		for (const match of items) {
			const list = groups.get(match.round) ?? [];
			list.push(match);
			groups.set(match.round, list);
		}
		return ROUND_ORDER.filter((round) => groups.has(round)).map((round) => ({
			round,
			matches: groups.get(round) ?? []
		}));
	}

	let groups = $derived(groupByRound(matches));
</script>

{#if matches.length === 0}
	<p class="mt-4 text-neutral-500">{emptyMessage}</p>
{:else}
	<div class="mt-4 space-y-6">
		{#each groups as group (group.round)}
			<div>
				<h3 class="mb-2 text-sm font-semibold uppercase text-neutral-500">
					{formatRound(group.round)}
				</h3>
				{#each group.matches as match (match.id)}
					<MatchRow {match} />
				{/each}
			</div>
		{/each}
	</div>
{/if}
```

- [ ] **Step 6: Create PlayerRow**

Create `apps/web/src/lib/components/PlayerRow.svelte`:

```svelte
<script lang="ts">
	import type { PlayerRef } from '#lib/api/types';

	let { player }: { player: PlayerRef } = $props();
</script>

<a
	href="/players/{player.slug}"
	class="flex items-center justify-between border-b border-neutral-100 py-2 text-sm hover:text-accent"
>
	<span>{player.first_name} {player.last_name}</span>
</a>
```

- [ ] **Step 7: Create the tournament detail page**

Create `apps/web/src/routes/tournaments/[slug]/+page.svelte`:

```svelte
<script lang="ts">
	import { formatCategory, formatSurface } from '#lib/format';
	import MatchList from '#lib/components/MatchList.svelte';
	import PlayerRow from '#lib/components/PlayerRow.svelte';
	import { playersFromMatches } from '#lib/tournament';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	type Tab = 'schedule' | 'players' | 'results';
	let activeTab = $state<Tab>('results');

	let players = $derived(playersFromMatches(data.matches));
	let scheduledMatches = $derived(
		data.matches.filter((m) => m.status === 'scheduled' || m.status === 'live')
	);
	let finishedMatches = $derived(
		data.matches.filter((m) => m.status !== 'scheduled' && m.status !== 'live')
	);

	function tabClass(tab: Tab): string {
		return activeTab === tab
			? 'border-b-2 border-accent pb-2 font-semibold text-neutral-900'
			: 'pb-2 text-neutral-500';
	}
</script>

<section class="mx-auto max-w-5xl px-4 py-12">
	<h1 class="text-3xl font-bold text-neutral-900">{data.tournament.name}</h1>
	<p class="mt-1 text-neutral-500">
		{formatCategory(data.tournament.category)} · {formatSurface(data.tournament.surface)}
		{#if data.edition}
			· {data.edition.year}
		{/if}
	</p>

	<div class="mt-6 flex gap-4 border-b border-neutral-200 text-sm">
		<button class={tabClass('schedule')} onclick={() => (activeTab = 'schedule')}>
			Calendrier
		</button>
		<button class={tabClass('players')} onclick={() => (activeTab = 'players')}> Joueurs </button>
		<button class={tabClass('results')} onclick={() => (activeTab = 'results')}> Résultats </button>
	</div>

	{#if activeTab === 'schedule'}
		<MatchList matches={scheduledMatches} emptyMessage="Aucun match à venir programmé." />
	{:else if activeTab === 'players'}
		{#if players.length === 0}
			<p class="mt-4 text-neutral-500">Aucun joueur à afficher.</p>
		{:else}
			<div class="mt-4">
				{#each players as player (player.id)}
					<PlayerRow {player} />
				{/each}
			</div>
		{/if}
	{:else if activeTab === 'results'}
		<MatchList matches={finishedMatches} emptyMessage="Aucun résultat pour l'instant." />
	{/if}
</section>
```

- [ ] **Step 8: Verify the build and typecheck pass**

Run: `docker compose run --rm web pnpm check`
Expected: exit code 0, no type errors.

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

- [ ] **Step 9: Run the full suite to check for regressions**

Run: `docker compose run --rm web pnpm test`
Expected: all tests pass.

- [ ] **Step 10: Commit**

```bash
git add apps/web/src/lib/components/MatchRow.svelte apps/web/src/lib/components/MatchList.svelte apps/web/src/lib/components/PlayerRow.svelte apps/web/src/routes/tournaments/\[slug\]/+page.server.ts apps/web/src/routes/tournaments/\[slug\]/+page.server.test.ts apps/web/src/routes/tournaments/\[slug\]/+page.svelte
git commit -m "feat: add the tournament detail page (Schedule/Players/Results)"
```

---

### Task 7: Frontend — player detail page

**Files:**
- Create: `apps/web/src/routes/players/[slug]/+page.server.ts`
- Test: `apps/web/src/routes/players/[slug]/+page.server.test.ts`
- Create: `apps/web/src/routes/players/[slug]/+page.svelte`

**Interfaces:**
- Consumes: `getPlayer` (Task 3), `ApiError` (Task 2), `formatHand` (Task 4).
- Produces: `/players/[slug]` route, linked to from Task 6's `PlayerRow`. Nothing later depends on this task.

- [ ] **Step 1: Write the failing test for the load function**

Create `apps/web/src/routes/players/[slug]/+page.server.test.ts`:

```ts
import { describe, expect, test, vi } from 'vitest';

vi.mock('#lib/api/players', () => ({ getPlayer: vi.fn() }));

import { ApiError } from '#lib/api/client';
import { getPlayer } from '#lib/api/players';
import { load } from './+page.server';

function buildEvent(slug: string) {
	return { params: { slug } } as unknown as Parameters<typeof load>[0];
}

describe('load', () => {
	test('loads the player', async () => {
		const player = {
			id: 1,
			first_name: 'Mateo',
			last_name: 'Rivera',
			slug: 'mateo-rivera',
			country_code: 'ESP',
			current_ranking: 3,
			current_ranking_points: 4500,
			birth_date: '1998-04-02',
			hand: 'right',
			height_cm: 185
		};
		vi.mocked(getPlayer).mockResolvedValue(player);

		const result = await load(buildEvent('mateo-rivera'));

		expect(result).toEqual({ player });
	});

	test('throws a SvelteKit 404 when the player API call returns 404', async () => {
		vi.mocked(getPlayer).mockRejectedValue(
			new ApiError('API request failed: 404 /api/players/unknown', 404)
		);

		await expect(load(buildEvent('unknown'))).rejects.toMatchObject({ status: 404 });
	});

	test('re-throws a non-404 ApiError unchanged', async () => {
		const serverError = new ApiError('API request failed: 500 /api/players/x', 500);
		vi.mocked(getPlayer).mockRejectedValue(serverError);

		await expect(load(buildEvent('x'))).rejects.toBe(serverError);
	});
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./+page.server` does not exist yet.

- [ ] **Step 3: Implement the load function**

Create `apps/web/src/routes/players/[slug]/+page.server.ts`:

```ts
import { error } from '@sveltejs/kit';
import { ApiError } from '#lib/api/client';
import { getPlayer } from '#lib/api/players';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	try {
		const player = await getPlayer(params.slug);
		return { player };
	} catch (e) {
		if (e instanceof ApiError && e.status === 404) {
			throw error(404, 'Joueur introuvable');
		}
		throw e;
	}
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 5: Create the player detail page**

Create `apps/web/src/routes/players/[slug]/+page.svelte`:

```svelte
<script lang="ts">
	import { formatHand } from '#lib/format';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<section class="mx-auto max-w-3xl px-4 py-12">
	<h1 class="text-3xl font-bold text-neutral-900">
		{data.player.first_name} {data.player.last_name}
	</h1>
	<p class="mt-1 text-neutral-500">{data.player.country_code}</p>

	<dl class="mt-6 grid grid-cols-2 gap-4 text-sm">
		{#if data.player.current_ranking}
			<div>
				<dt class="text-neutral-500">Classement</dt>
				<dd class="font-semibold text-neutral-900">#{data.player.current_ranking}</dd>
			</div>
		{/if}
		{#if data.player.hand}
			<div>
				<dt class="text-neutral-500">Main</dt>
				<dd class="font-semibold text-neutral-900">{formatHand(data.player.hand)}</dd>
			</div>
		{/if}
		{#if data.player.height_cm}
			<div>
				<dt class="text-neutral-500">Taille</dt>
				<dd class="font-semibold text-neutral-900">{data.player.height_cm} cm</dd>
			</div>
		{/if}
		{#if data.player.birth_date}
			<div>
				<dt class="text-neutral-500">Date de naissance</dt>
				<dd class="font-semibold text-neutral-900">{data.player.birth_date}</dd>
			</div>
		{/if}
	</dl>
</section>
```

- [ ] **Step 6: Verify the build and typecheck pass**

Run: `docker compose run --rm web pnpm check`
Expected: exit code 0, no type errors.

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

- [ ] **Step 7: Run the full suite to check for regressions**

Run: `docker compose run --rm web pnpm test`
Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add apps/web/src/routes/players/\[slug\]/+page.server.ts apps/web/src/routes/players/\[slug\]/+page.server.test.ts apps/web/src/routes/players/\[slug\]/+page.svelte
git commit -m "feat: add the player detail page"
```

---

### Task 8: Final verification

**Files:**
- None (verification only).

**Interfaces:**
- Consumes: everything built in Tasks 1–7.
- Produces: nothing new — this task verifies.

- [ ] **Step 1: Run the full backend test suite**

Run: `docker compose run --rm api mix test`
Expected: all tests pass. Recount rather than assume a specific total.

- [ ] **Step 2: Run the full frontend test suite**

Run: `docker compose run --rm web pnpm test`
Expected: all tests pass.

- [ ] **Step 3: Typecheck and build**

Run: `docker compose run --rm web pnpm check`
Expected: exit code 0, no type errors.

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

Run: `docker compose run --rm api mix compile --warnings-as-errors`
Expected: exit code 0, no warnings.

- [ ] **Step 4: Smoke-test the running stack end-to-end**

Run: `docker compose up -d`
Then wait for `db`, `api`, and `web` to be healthy/ready, then:

```bash
docker compose run --rm api mix run priv/repo/seeds.exs
curl -s http://localhost:${WEB_PORT:-5173}/tournaments
curl -s http://localhost:${WEB_PORT:-5173}/tournaments/internationaux-fictifs-de-france
curl -s http://localhost:${WEB_PORT:-5173}/players/mateo-rivera
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:${WEB_PORT:-5173}/tournaments/does-not-exist
```

Expected:
- `/tournaments` response contains `Tournois`, the "Filtrer" button, at least one tournament name (e.g. `Internationaux Fictifs de France`), and `Page 1`.
- `/tournaments/internationaux-fictifs-de-france` response contains the tournament name, `Résultats` (the default active tab), a formatted score (e.g. a string matching `\d+-\d+`), and a round label (e.g. `Finale` or `Quart de finale`) — proving the Task 1 backend change actually reached the frontend end-to-end.
- `/players/mateo-rivera` response contains `Mateo Rivera`, `ESP`, and `Droitier` or `Gaucher`.
- The last command (unknown tournament slug) prints `404`.

If the seed script raises on a unique-constraint violation because data already exists from a prior run, that's expected (not a regression) — proceed with the curl checks against the existing data.

Then: `docker compose down`

- [ ] **Step 5: Confirm no stray `$lib` imports**

Run: `grep -rn '\$lib' apps/web/src`
Expected: no matches (grep exits 1, meaning nothing found) — a match would mean a stray `$lib` import slipped in somewhere instead of `#lib`.
