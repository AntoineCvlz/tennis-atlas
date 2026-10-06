# Tennis Atlas — Phase 4 : Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Phase 1 health-check placeholder with a real layout (navigation + footer), a Tailwind v4 design system, and a homepage that server-side-fetches real tournament data from the Phase 3 API. No Tournament Explorer, no surface theming, no detail pages — those are later phases.

**Architecture:** A thin API-client layer (`lib/api/`) wraps `fetch` against a Docker-internal URL and is unit-tested with Vitest (mocked `fetch`, no real network/DB). Presentational Svelte components (`lib/components/`) have no logic of their own — the one piece of non-trivial logic (category/surface enum → French label, with a safe fallback) lives in a plain `lib/format.ts` module so it stays unit-testable without component-rendering tooling. `+page.server.ts`'s `load` function ties the API client to the homepage, catching any failure so the page degrades gracefully instead of crashing to SvelteKit's error page.

**Tech Stack:** SvelteKit 3 (Svelte 5 runes), Tailwind v4 (`@tailwindcss/vite`, no `tailwind.config.ts`), Vitest (`environment: 'node'`, no `@testing-library/svelte` this phase), pnpm.

**Spec:** [docs/superpowers/specs/2026-10-06-phase-4-frontend-design.md](../specs/2026-10-06-phase-4-frontend-design.md) (component list, data flow, Docker-internal URL rationale) and [docs/superpowers/specs/2026-10-05-tennis-atlas-architecture-design.md](../specs/2026-10-05-tennis-atlas-architecture-design.md) (project-wide architecture).

## Global Constraints

- Homepage data fetching is **SSR only**, via `+page.server.ts`'s `load` — never a client-side `onMount` fetch (the Phase 1 pattern being replaced).
- Server-side API calls use the **private** env var `API_INTERNAL_URL` (`http://api:4000`, the Docker Compose service name) — `PUBLIC_API_URL` stays reserved for a future browser-side use and is not touched this phase.
- Navigation is **minimal**: only the "Tennis Atlas" wordmark linking to `/` — no links to pages that don't exist yet (added phase by phase as real pages land).
- The Phase 1 health-check widget and its `onMount`/retry logic are **removed entirely** from the homepage.
- DTO types live in `apps/web/src/lib/api/types.ts` — **no `packages/shared`** this phase (no second TS consumer exists yet).
- Tailwind v4 via its Vite plugin — **no `tailwind.config.ts`/`postcss.config.js`** (both are obsolete in v4's default setup).
- A failed/unreachable API call must **never crash the homepage** — `load()` catches and degrades to an empty tournament list plus a message; the hero still renders.
- Category/surface enum values are shown via a **French label mapping**, never the raw enum string (e.g. `"grand_slam"` must render as `"Grand Chelem"`).
- All commands run via `docker compose run --rm web <cmd>` — no local Node/pnpm install assumed (same convention as the API's `docker compose run --rm api <cmd>`).

## Review Focus

- The API being unreachable or unhealthy during SSR (e.g. the `api` container not yet healthy) must still render the hero and a graceful "indisponible" message, not crash to SvelteKit's error page. Pinned in Task 6.
- The server-side fetch must target `API_INTERNAL_URL` (Docker-internal), never `PUBLIC_API_URL` — the two look equally plausible as a fetch target and mixing them up silently breaks only inside Docker, not in a bare `pnpm dev`. Pinned in Task 2.
- The API returning more than 3 tournaments must still render exactly 3 cards on the homepage, not all of them. Pinned in Task 6.
- An unmapped or future category/surface value (one the French label map doesn't cover) must render its raw string as a fallback, not `undefined` or a crash. Pinned in Task 3.
- A non-2xx API response (a resolved-but-bad `fetch`) and an actual network failure (a rejected `fetch` promise) are two different failure modes — `load()` must catch both, not just one, or a database-down scenario behaves differently from an API 500. Pinned across Task 2 (client throws on both) and Task 6 (load catches both).

---

### Task 1: Tailwind v4 setup

**Files:**
- Modify: `apps/web/package.json`
- Modify: `apps/web/vite.config.ts`
- Create: `apps/web/src/app.css`
- Modify: `apps/web/src/routes/+layout.svelte`

**Interfaces:**
- Consumes: nothing new.
- Produces: a working Tailwind utility-class pipeline and a `--color-accent` theme token, available to every component created in later tasks.

- [ ] **Step 1: Add the Tailwind v4 dependencies**

Run: `docker compose run --rm web pnpm add -D tailwindcss @tailwindcss/vite`
Expected: `package.json` and `pnpm-lock.yaml` updated; exit code 0.

- [ ] **Step 2: Wire the Tailwind Vite plugin**

Modify `apps/web/vite.config.ts`:

```ts
import adapter from '@sveltejs/adapter-auto';
import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit({
			compilerOptions: {
				// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
				runes: ({ filename }) =>
					filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},

			// adapter-auto only supports some environments, see https://svelte.dev/docs/kit/adapter-auto for a list.
			// If your environment is not supported, or you settled on a specific environment, switch out the adapter.
			// See https://svelte.dev/docs/kit/adapters for more information about adapters.
			adapter: adapter()
		})
	]
});
```

- [ ] **Step 3: Create the global stylesheet**

Create `apps/web/src/app.css`:

```css
@import 'tailwindcss';

@theme {
	--color-accent: #1d4ed8;
}

@layer base {
	body {
		@apply bg-neutral-50 text-neutral-900;
	}
}
```

- [ ] **Step 4: Import the stylesheet in the root layout**

Modify `apps/web/src/routes/+layout.svelte` — add the import as the first line of the `<script>` block:

```svelte
<script lang="ts">
	import '../app.css';
	import favicon from '#lib/assets/favicon.svg';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

{@render children()}
```

- [ ] **Step 5: Verify the build succeeds**

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0, no errors mentioning `tailwindcss` or `app.css`.

- [ ] **Step 6: Commit**

```bash
git add apps/web/package.json apps/web/pnpm-lock.yaml apps/web/vite.config.ts apps/web/src/app.css apps/web/src/routes/+layout.svelte
git commit -m "feat: add Tailwind v4"
```

---

### Task 2: Docker-internal API URL + Vitest + API client

**Files:**
- Modify: `apps/web/src/env.ts`
- Modify: `docker-compose.yml`
- Create: `apps/web/vitest.config.ts`
- Modify: `apps/web/package.json`
- Create: `apps/web/src/lib/api/client.ts`
- Test: `apps/web/src/lib/api/client.test.ts`

**Interfaces:**
- Consumes: nothing new.
- Produces: `apiFetch<T>(path: string): Promise<T>` and the `ApiError` class — every later API-facing module (Task 3's `tournaments.ts`, Task 6's `load`) calls `apiFetch` and expects it to throw `ApiError` (or let a network rejection propagate) on failure, never to resolve with bad data.

- [ ] **Step 1: Declare the private env var**

Modify `apps/web/src/env.ts`:

```ts
import { defineEnvVars } from '@sveltejs/kit/env';

export const variables = defineEnvVars({
	PUBLIC_API_URL: {
		public: true,
		static: false
	},
	API_INTERNAL_URL: {
		public: false,
		static: false
	}
});
```

- [ ] **Step 2: Wire the env var in Docker Compose**

Modify `docker-compose.yml` — add `API_INTERNAL_URL` to the `web` service's `environment` block:

```yaml
  web:
    build:
      context: .
      dockerfile: docker/web.Dockerfile
    environment:
      PUBLIC_API_URL: ${PUBLIC_API_URL}
      API_INTERNAL_URL: http://api:4000
    ports:
      - "${WEB_PORT}:5173"
    volumes:
      - ./apps/web:/app
      - web_node_modules:/app/node_modules
    depends_on:
      - api
```

This value is fixed (the Docker Compose service name + the API's in-container port) and never varies per developer, unlike the `*_PORT` variables — it is not templated from `.env`.

- [ ] **Step 3: Add Vitest and the test script**

Run: `docker compose run --rm web pnpm add -D vitest`
Expected: `package.json`/`pnpm-lock.yaml` updated.

Modify `apps/web/package.json` — add a `"test"` script next to the existing ones:

```json
	"scripts": {
		"dev": "vite dev",
		"build": "vite build",
		"preview": "vite preview",
		"test": "vitest run",
		"prepare": "svelte-kit sync || echo ''",
		"check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
		"check:watch": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json --watch"
	},
```

- [ ] **Step 4: Create the Vitest config**

Create `apps/web/vitest.config.ts`:

```ts
import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config';

export default mergeConfig(
	viteConfig,
	defineConfig({
		test: {
			environment: 'node',
			include: ['src/**/*.test.ts']
		}
	})
);
```

Reusing `vite.config.ts` (via `mergeConfig`) keeps the `sveltekit()` plugin active during tests, which is what resolves the `$lib/*` and `$app/env/*` aliases used in Step 6 below and in later tasks' tests.

- [ ] **Step 5: Write the failing test**

Create `apps/web/src/lib/api/client.test.ts`:

```ts
import { beforeEach, describe, expect, test, vi } from 'vitest';

vi.mock('$app/env/private', () => ({ API_INTERNAL_URL: 'http://api:4000' }));

import { apiFetch, ApiError } from './client';

describe('apiFetch', () => {
	beforeEach(() => {
		vi.restoreAllMocks();
	});

	test('returns parsed JSON on a 200 response, fetched from API_INTERNAL_URL', async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn().mockResolvedValue({
				ok: true,
				status: 200,
				json: () => Promise.resolve({ data: ['ok'] })
			})
		);

		const result = await apiFetch<{ data: string[] }>('/api/tournaments');

		expect(result).toEqual({ data: ['ok'] });
		expect(fetch).toHaveBeenCalledWith('http://api:4000/api/tournaments');
	});

	test('throws ApiError on a non-ok response', async () => {
		vi.stubGlobal(
			'fetch',
			vi.fn().mockResolvedValue({ ok: false, status: 500, json: () => Promise.resolve({}) })
		);

		await expect(apiFetch('/api/tournaments')).rejects.toThrow(ApiError);
	});

	test('propagates a network error unchanged', async () => {
		vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network down')));

		await expect(apiFetch('/api/tournaments')).rejects.toThrow('network down');
	});
});
```

- [ ] **Step 6: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./client` (and the module it exports) does not exist yet.

- [ ] **Step 7: Implement the API client**

Create `apps/web/src/lib/api/client.ts`:

```ts
import { API_INTERNAL_URL } from '$app/env/private';

export class ApiError extends Error {}

export async function apiFetch<T>(path: string): Promise<T> {
	const res = await fetch(`${API_INTERNAL_URL}${path}`);

	if (!res.ok) {
		throw new ApiError(`API request failed: ${res.status} ${path}`);
	}

	return res.json() as Promise<T>;
}
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS (3 tests, 0 failures).

- [ ] **Step 9: Commit**

```bash
git add apps/web/src/env.ts docker-compose.yml apps/web/vitest.config.ts apps/web/package.json apps/web/pnpm-lock.yaml apps/web/src/lib/api/client.ts apps/web/src/lib/api/client.test.ts
git commit -m "feat: add Docker-internal API URL, Vitest, and the API client"
```

---

### Task 3: Types, tournaments fetcher, and category/surface labels

**Files:**
- Create: `apps/web/src/lib/api/types.ts`
- Create: `apps/web/src/lib/api/tournaments.ts`
- Test: `apps/web/src/lib/api/tournaments.test.ts`
- Create: `apps/web/src/lib/format.ts`
- Test: `apps/web/src/lib/format.test.ts`

**Interfaces:**
- Consumes: `apiFetch` from Task 2.
- Produces: `Tournament`/`Venue` types, `getTournaments(): Promise<Tournament[]>` (consumed by Task 6's `load`), `formatCategory(category: string): string` and `formatSurface(surface: string): string` (consumed by Task 5's `TournamentCard`).

- [ ] **Step 1: Define the DTO types**

Create `apps/web/src/lib/api/types.ts`:

```ts
export type Venue = {
	id: number;
	name: string;
	city: string;
	country_code: string;
};

export type Tournament = {
	id: number;
	name: string;
	slug: string;
	category: string;
	surface: string;
	venue: Venue | null;
};
```

- [ ] **Step 2: Write the failing test for getTournaments**

Create `apps/web/src/lib/api/tournaments.test.ts`:

```ts
import { describe, expect, test, vi } from 'vitest';

vi.mock('./client', () => ({ apiFetch: vi.fn() }));

import { apiFetch } from './client';
import { getTournaments } from './tournaments';

describe('getTournaments', () => {
	test('fetches /api/tournaments and returns the data array', async () => {
		const tournaments = [
			{
				id: 1,
				name: 'Internationaux Fictifs de France',
				slug: 'internationaux-fictifs-de-france',
				category: 'grand_slam',
				surface: 'clay',
				venue: null
			}
		];
		vi.mocked(apiFetch).mockResolvedValue({ data: tournaments });

		const result = await getTournaments();

		expect(apiFetch).toHaveBeenCalledWith('/api/tournaments');
		expect(result).toEqual(tournaments);
	});
});
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./tournaments` does not exist yet.

- [ ] **Step 4: Implement getTournaments**

Create `apps/web/src/lib/api/tournaments.ts`:

```ts
import { apiFetch } from './client';
import type { Tournament } from './types';

export async function getTournaments(): Promise<Tournament[]> {
	const { data } = await apiFetch<{ data: Tournament[] }>('/api/tournaments');
	return data;
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS.

- [ ] **Step 6: Write the failing test for the label formatters**

Create `apps/web/src/lib/format.test.ts`:

```ts
import { describe, expect, test } from 'vitest';
import { formatCategory, formatSurface } from './format';

describe('formatCategory', () => {
	test.each([
		['grand_slam', 'Grand Chelem'],
		['masters_1000', 'Masters 1000'],
		['atp_500', 'ATP 500'],
		['atp_250', 'ATP 250'],
		['wta_1000', 'WTA 1000'],
		['wta_500', 'WTA 500'],
		['wta_250', 'WTA 250']
	])('maps %s to %s', (input, expected) => {
		expect(formatCategory(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped category', () => {
		expect(formatCategory('future_category')).toBe('future_category');
	});
});

describe('formatSurface', () => {
	test.each([
		['clay', 'Terre battue'],
		['grass', 'Gazon'],
		['hard', 'Dur'],
		['indoor', 'Indoor']
	])('maps %s to %s', (input, expected) => {
		expect(formatSurface(input)).toBe(expected);
	});

	test('falls back to the raw value for an unmapped surface', () => {
		expect(formatSurface('clay_indoor_hybrid')).toBe('clay_indoor_hybrid');
	});
});
```

- [ ] **Step 7: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./format` does not exist yet.

- [ ] **Step 8: Implement the label formatters**

Create `apps/web/src/lib/format.ts`:

```ts
const CATEGORY_LABELS: Record<string, string> = {
	grand_slam: 'Grand Chelem',
	masters_1000: 'Masters 1000',
	atp_500: 'ATP 500',
	atp_250: 'ATP 250',
	wta_1000: 'WTA 1000',
	wta_500: 'WTA 500',
	wta_250: 'WTA 250'
};

const SURFACE_LABELS: Record<string, string> = {
	clay: 'Terre battue',
	grass: 'Gazon',
	hard: 'Dur',
	indoor: 'Indoor'
};

export function formatCategory(category: string): string {
	return CATEGORY_LABELS[category] ?? category;
}

export function formatSurface(surface: string): string {
	return SURFACE_LABELS[surface] ?? surface;
}
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS (all tests across the project, including Task 2's, still green).

- [ ] **Step 10: Commit**

```bash
git add apps/web/src/lib/api/types.ts apps/web/src/lib/api/tournaments.ts apps/web/src/lib/api/tournaments.test.ts apps/web/src/lib/format.ts apps/web/src/lib/format.test.ts
git commit -m "feat: add Tournament types, getTournaments, and category/surface label formatters"
```

---

### Task 4: Navigation and footer shell

**Files:**
- Create: `apps/web/src/lib/components/Nav.svelte`
- Create: `apps/web/src/lib/components/Footer.svelte`
- Modify: `apps/web/src/routes/+layout.svelte`

**Interfaces:**
- Consumes: the `--color-accent` theme token from Task 1.
- Produces: a page shell (nav + main + footer) every route renders inside, starting with this one.

- [ ] **Step 1: Create the navigation bar**

Create `apps/web/src/lib/components/Nav.svelte`:

```svelte
<nav class="border-b border-neutral-200 bg-white">
	<div class="mx-auto max-w-5xl px-4 py-4">
		<a href="/" class="text-lg font-bold text-neutral-900">Tennis Atlas</a>
	</div>
</nav>
```

- [ ] **Step 2: Create the footer**

Create `apps/web/src/lib/components/Footer.svelte`:

```svelte
<footer class="border-t border-neutral-200 py-6 text-center text-sm text-neutral-500">
	<p>
		© 2026 Tennis Atlas — projet portfolio ·
		<a
			href="https://github.com/AntoineCvlz/tennis-atlas"
			target="_blank"
			rel="noopener noreferrer"
			class="underline hover:text-accent"
		>
			GitHub
		</a>
	</p>
</footer>
```

- [ ] **Step 3: Wrap the layout with Nav and Footer**

Modify `apps/web/src/routes/+layout.svelte`:

```svelte
<script lang="ts">
	import '../app.css';
	import favicon from '#lib/assets/favicon.svg';
	import Nav from '$lib/components/Nav.svelte';
	import Footer from '$lib/components/Footer.svelte';
	import type { LayoutProps } from './$types';

	let { children }: LayoutProps = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
</svelte:head>

<div class="flex min-h-screen flex-col">
	<Nav />
	<main class="flex-1">
		{@render children()}
	</main>
	<Footer />
</div>
```

- [ ] **Step 4: Verify the build succeeds and the shell renders**

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

Run: `docker compose up -d web` (brings up `api`/`db` too, via `depends_on`)
Then: `curl -s http://localhost:${WEB_PORT:-5173}/`
Expected: response body contains `Tennis Atlas` (the nav link) and `GitHub` (the footer link), wrapping the still-unchanged Phase 1 homepage content — the homepage itself isn't replaced until Task 6.
Then: `docker compose down`

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/components/Nav.svelte apps/web/src/lib/components/Footer.svelte apps/web/src/routes/+layout.svelte
git commit -m "feat: add Nav and Footer layout shell"
```

---

### Task 5: Hero, TournamentCard, and FeaturedTournaments components

**Files:**
- Create: `apps/web/src/lib/components/Hero.svelte`
- Create: `apps/web/src/lib/components/TournamentCard.svelte`
- Create: `apps/web/src/lib/components/FeaturedTournaments.svelte`

**Interfaces:**
- Consumes: `Tournament` type (Task 3), `formatCategory`/`formatSurface` (Task 3).
- Produces: `FeaturedTournaments` (props: `{ tournaments: Tournament[] }`), consumed by Task 6's homepage. Not wired into any route yet — this task's own verification is build/typecheck only; Task 6 is where these become observably live.

- [ ] **Step 1: Create the hero section**

Create `apps/web/src/lib/components/Hero.svelte`:

```svelte
<section class="mx-auto max-w-3xl px-4 py-16 text-center">
	<h1 class="text-4xl font-bold text-neutral-900">Tennis Atlas</h1>
	<p class="mt-4 text-lg text-neutral-600">
		Explorez le tennis mondial : tournois, joueurs et résultats.
	</p>
</section>
```

- [ ] **Step 2: Create the tournament card**

Create `apps/web/src/lib/components/TournamentCard.svelte`:

```svelte
<script lang="ts">
	import { formatCategory, formatSurface } from '$lib/format';
	import type { Tournament } from '$lib/api/types';

	let { tournament }: { tournament: Tournament } = $props();
</script>

<article class="rounded-lg border border-neutral-200 p-5">
	<h3 class="font-semibold text-neutral-900">{tournament.name}</h3>
	<p class="mt-1 text-sm text-neutral-500">
		{formatCategory(tournament.category)} · {formatSurface(tournament.surface)}
	</p>
</article>
```

- [ ] **Step 3: Create the featured-tournaments section**

Create `apps/web/src/lib/components/FeaturedTournaments.svelte`:

```svelte
<script lang="ts">
	import TournamentCard from './TournamentCard.svelte';
	import type { Tournament } from '$lib/api/types';

	let { tournaments }: { tournaments: Tournament[] } = $props();
</script>

<section class="mx-auto max-w-5xl px-4 py-12">
	<h2 class="text-2xl font-semibold text-neutral-900">Tournois en vedette</h2>

	{#if tournaments.length === 0}
		<p class="mt-4 text-neutral-500">Les tournois ne sont pas disponibles pour le moment.</p>
	{:else}
		<div class="mt-6 grid gap-4 sm:grid-cols-3">
			{#each tournaments as tournament (tournament.id)}
				<TournamentCard {tournament} />
			{/each}
		</div>
	{/if}
</section>
```

- [ ] **Step 4: Verify the build and typecheck pass**

Run: `docker compose run --rm web pnpm check`
Expected: exit code 0, no type errors.

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/components/Hero.svelte apps/web/src/lib/components/TournamentCard.svelte apps/web/src/lib/components/FeaturedTournaments.svelte
git commit -m "feat: add Hero, TournamentCard, and FeaturedTournaments components"
```

---

### Task 6: Homepage — replace the Phase 1 placeholder

**Files:**
- Create: `apps/web/src/routes/+page.server.ts`
- Test: `apps/web/src/routes/+page.server.test.ts`
- Modify: `apps/web/src/routes/+page.svelte`

**Interfaces:**
- Consumes: `getTournaments` (Task 3), `Hero`/`FeaturedTournaments` (Task 5).
- Produces: the live homepage. Nothing later depends on this task.

- [ ] **Step 1: Write the failing test for load()**

Create `apps/web/src/routes/+page.server.test.ts`:

```ts
import { describe, expect, test, vi } from 'vitest';

vi.mock('$lib/api/tournaments', () => ({ getTournaments: vi.fn() }));

import { getTournaments } from '$lib/api/tournaments';
import { load } from './+page.server';
import type { Tournament } from '$lib/api/types';

function buildTournament(id: number): Tournament {
	return {
		id,
		name: `Tournament ${id}`,
		slug: `tournament-${id}`,
		category: 'atp_250',
		surface: 'hard',
		venue: null
	};
}

describe('load', () => {
	test('returns at most 3 tournaments on success', async () => {
		const tournaments = [1, 2, 3, 4, 5].map(buildTournament);
		vi.mocked(getTournaments).mockResolvedValue(tournaments);

		const result = await load({} as unknown as Parameters<typeof load>[0]);

		expect(result.tournaments).toHaveLength(3);
		expect(result.tournaments).toEqual(tournaments.slice(0, 3));
		expect(result.apiError).toBe(false);
	});

	test('returns an empty list and apiError true when getTournaments rejects', async () => {
		vi.mocked(getTournaments).mockRejectedValue(new Error('network down'));

		const result = await load({} as unknown as Parameters<typeof load>[0]);

		expect(result.tournaments).toEqual([]);
		expect(result.apiError).toBe(true);
	});
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `docker compose run --rm web pnpm test`
Expected: FAIL — `./+page.server` does not exist yet.

- [ ] **Step 3: Implement the load function**

Create `apps/web/src/routes/+page.server.ts`:

```ts
import { getTournaments } from '$lib/api/tournaments';
import type { PageServerLoad } from './$types';

const FEATURED_COUNT = 3;

export const load: PageServerLoad = async () => {
	try {
		const tournaments = await getTournaments();
		return { tournaments: tournaments.slice(0, FEATURED_COUNT), apiError: false };
	} catch {
		return { tournaments: [], apiError: true };
	}
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `docker compose run --rm web pnpm test`
Expected: PASS (all tests across the project green).

- [ ] **Step 5: Replace the homepage markup**

Modify `apps/web/src/routes/+page.svelte` — replace the entire file (removing the Phase 1 `onMount`/health-check code):

```svelte
<script lang="ts">
	import Hero from '$lib/components/Hero.svelte';
	import FeaturedTournaments from '$lib/components/FeaturedTournaments.svelte';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
</script>

<Hero />
<FeaturedTournaments tournaments={data.tournaments} />
```

- [ ] **Step 6: Verify the build succeeds**

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

- [ ] **Step 7: Commit**

```bash
git add apps/web/src/routes/+page.server.ts apps/web/src/routes/+page.server.test.ts apps/web/src/routes/+page.svelte
git commit -m "feat: replace Phase 1 placeholder with the real homepage"
```

---

### Task 7: Final verification

**Files:**
- None (verification only).

**Interfaces:**
- Consumes: everything built in Tasks 1–6.
- Produces: nothing new — this task verifies.

- [ ] **Step 1: Run the full test suite**

Run: `docker compose run --rm web pnpm test`
Expected: all tests pass.

- [ ] **Step 2: Typecheck**

Run: `docker compose run --rm web pnpm check`
Expected: exit code 0, no type errors.

- [ ] **Step 3: Production build**

Run: `docker compose run --rm web pnpm build`
Expected: exit code 0.

- [ ] **Step 4: Smoke-test the running stack end-to-end**

Run: `docker compose up -d`
Then wait for `db`, `api`, and `web` to be up, then:

```bash
docker compose run --rm api mix run priv/repo/seeds.exs
curl -s http://localhost:${WEB_PORT:-5173}/
```

Expected: the response body contains:
- `Tennis Atlas` (nav + hero)
- `Explorez le tennis mondial` (hero subtitle)
- `Tournois en vedette` (section heading)
- `Internationaux Fictifs de France` (a real seeded tournament name, proving the SSR fetch reached the real API through `API_INTERNAL_URL` over the Docker network, not a mock)
- `Grand Chelem` and `Terre battue` (proving the label formatters ran, not raw enum values)

Then: `docker compose down`

If the seed script has already been run against this stack before (e.g. a prior phase's manual run left data in the volume), `mix run priv/repo/seeds.exs` will raise on a unique-constraint violation — this is expected per Phase 2's seeding notes, not a Phase 4 regression; if it happens, the tournament data is already present and the curl check can proceed without re-seeding.

- [ ] **Step 5: Confirm no leftover Phase 1 code**

Run: `grep -r "onMount" apps/web/src/routes/+page.svelte`
Expected: no matches (the file was fully replaced in Task 6).
