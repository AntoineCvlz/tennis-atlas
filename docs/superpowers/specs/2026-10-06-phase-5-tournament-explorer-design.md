# Tennis Atlas — Phase 5 : Tournament Explorer — Design

**Date** : 2026-10-06
**Statut** : Validé par l'utilisateur en chat, section par section.
**Portée** : liste des tournois (paginée, filtrable), page tournoi (calendrier/joueurs/résultats), page détail joueur. Un petit ajout backend ciblé (sets dans la liste des matchs). Pas de thème par surface (Phase 6), pas de tableau interactif (Phase 7), pas de page match détaillée (Phase 8).
**Spec parente** : [2026-10-05-tennis-atlas-architecture-design.md](2026-10-05-tennis-atlas-architecture-design.md)
**Spec précédente** : [2026-10-06-phase-4-frontend-design.md](2026-10-06-phase-4-frontend-design.md)

## 1. Décisions de portée actées en discussion

- **Joueurs d'une édition dérivés des matchs** (dédoublonnage `player_a`/`player_b` sur les matchs déjà récupérés), pas un appel séparé à un endpoint `tournament_entries` — cet endpoint n'existe pas dans l'API Phase 3 et n'est pas ajouté ici. Limite acceptée : pas de seed/statut d'engagement (qualifié, wildcard...), juste "qui a joué cette édition".
- **Page tournoi à onglets** (`/tournaments/[slug]`), pas de sous-routes dédiées par onglet — un seul `load()` SSR, changement d'onglet côté client sans navigation.
- **Liste des tournois avec pagination et filtres** (`surface`, `category`) via query params d'URL, formulaire HTML natif en `GET` — l'API Phase 3 les supporte déjà nativement, aucun travail backend.
- **Édition la plus récente uniquement** — pas de sélecteur d'année cette phase (les données de seed n'ont qu'une édition par tournoi ; un sélecteur serait invisible/inutile aujourd'hui).
- **Page détail joueur ajoutée** (`/players/[slug]`) — l'API Phase 3 l'expose déjà entièrement ; laisser les joueurs non cliquables serait une impasse frustrante alors que la donnée existe.
- **Matchs non cliquables** — la page match est la Phase 8, hors scope ici (contrairement aux joueurs, aucune donnée de détail match supplémentaire n'est nécessaire cette phase au-delà de ce que la liste expose déjà).

## 2. Ajout backend ciblé : sets dans la liste des matchs

L'endpoint `GET /api/tournaments/:slug/editions/:year/matches` (Phase 3) ne renvoie pas les sets — seul `GET /api/matches/:id` (détail, Phase 8) les inclut. L'onglet "Résultats" a besoin du score ("6-4, 7-6") pour chaque match sans faire un appel par match (évite le N+1).

**Changement** (petit, ciblé, dans des fichiers déjà existants) :
- `apps/api/lib/tennis_atlas_api_web/controllers/match_json.ex` : `summary/1` inclut désormais `sets: for(s <- m.sets, do: set_ref(s))` (déjà implémenté dans `detail/1`, factorisé pour être partagé par les deux).
- `apps/api/lib/tennis_atlas_api/tournaments.ex` : `list_matches_for_edition/3` ajoute `:sets` à son `preload` (ligne 37, actuellement `preload([:player_a, :player_b, :court])` → `preload([:player_a, :player_b, :court, :sets])`).

Pas de changement de route, pas de changement de schema/migration — uniquement la liste des matchs d'une édition gagne un champ `sets` qu'elle n'avait pas. Tests Elixir à mettre à jour en conséquence (le test existant de `list_matches_for_edition` et son controller test).

## 3. Routes

```
/tournaments                    — liste paginée/filtrable
/tournaments/[slug]             — détail : onglets Calendrier / Joueurs / Résultats
/players/[slug]                 — détail joueur
```

## 4. Correction nécessaire : `ApiError` doit porter le code HTTP

`apiFetch` (Phase 4) lève `ApiError` pour toute réponse non-2xx, mais le message est une chaîne libre (`API request failed: ${res.status} ${path}`) — rien de structuré pour distinguer un 404 d'un 500. Sans ça, le `load()` de `/tournaments/[slug]` et `/players/[slug]` ne peut pas rendre la vraie page 404 de SvelteKit pour un slug inconnu ; l'erreur non interceptée deviendrait une page d'erreur 500 générique.

Modification de `apps/web/src/lib/api/client.ts` (ajout d'un champ, aucun changement de comportement pour les appelants existants) :

```ts
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

## 5. Client API (extension de `apps/web/src/lib/api/`)

`types.ts` — ajout de :

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

`tournaments.ts` — ajout de (gardant `getTournaments()` de la Phase 4 inchangée pour la homepage) :

```ts
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

`page_size=100` sur `getMatchesForEdition` : un tournoi complet a au plus ~127 matchs (tableau à 128), la pagination par défaut (20) couperait le tableau — 100 suffit pour toute la donnée de seed actuelle (7 matchs/tournoi) et reste raisonnable tant qu'un vrai Draw paginé n'existe pas (Phase 7).

Nouveau fichier `apps/web/src/lib/api/players.ts` :

```ts
import { apiFetch } from './client';
import type { Player } from './types';

export async function getPlayer(slug: string): Promise<Player> {
	const { data } = await apiFetch<{ data: Player }>(`/api/players/${slug}`);
	return data;
}
```

## 6. Chargement des données (SSR, cohérent avec la Phase 4)

`/tournaments/+page.server.ts` : lit `url.searchParams` (`surface`, `category`, `page`), appelle `listTournaments(...)`, retourne `{tournaments, meta, filters}`.

`/tournaments/[slug]/+page.server.ts` et `/players/[slug]/+page.server.ts` : appellent respectivement `getTournament(slug)`/`getPlayer(slug)` et traduisent explicitement un `ApiError` de statut 404 en la vraie page 404 de SvelteKit via `error(404, 'Tournoi introuvable')`/`error(404, 'Joueur introuvable')` (import `error` de `@sveltejs/kit`) :

```ts
import { error } from '@sveltejs/kit';
import { ApiError } from '$lib/api/client'; // #lib/api/client dans ce projet, cf. Phase 4
import { getTournament, getMatchesForEdition } from '#lib/api/tournaments';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ params }) => {
	let tournament;
	try {
		tournament = await getTournament(params.slug);
	} catch (e) {
		if (e instanceof ApiError && e.status === 404) error(404, 'Tournoi introuvable');
		throw e;
	}

	const edition = tournament.editions[0] ?? null;
	const matches = edition ? await getMatchesForEdition(params.slug, edition.year) : [];

	return { tournament, edition, matches };
};
```

(`$lib`/`#lib` : écrit ici en `$lib` dans le texte explicatif par lisibilité, mais rappel du constat de la Phase 4 — ce projet utilise réellement `#lib`, le plan d'implémentation doit écrire `#lib/...` partout.)

Une erreur non-404 (ex. API indisponible) n'est volontairement pas interceptée : elle remonte et SvelteKit affiche sa page d'erreur générique — contrairement à la homepage (Phase 4), une page tournoi/joueur individuelle n'a pas de dégradation gracieuse définie cette phase (pas de version "partielle" sensée d'une page qui n'a pas pu charger sa ressource principale).

## 7. Composants

| Composant | Rôle |
|---|---|
| `TournamentCard.svelte` (Phase 4, modifié) | Devient cliquable : tout l'article est enveloppé dans `<a href="/tournaments/{slug}">`. |
| `Pagination.svelte` | Liens « Précédent »/« Suivant » + « Page X / Y », désactivés en bout de liste. Props : `meta: PageMeta`, `baseUrl: string` (pour construire les liens avec les filtres actifs préservés). |
| `FilterForm.svelte` | `<form method="GET">` avec deux `<select>` (surface, catégorie), valeurs actuelles pré-sélectionnées, soumission = navigation native. |
| `MatchList.svelte` | Groupe les matchs par `round` (ordre : qf, sf, f, et r16/r32/r64/r128 avant si présents), affiche un `MatchRow` par match sous un titre de round. Message "Aucun match à venir programmé." si la liste filtrée est vide. |
| `MatchRow.svelte` | `player_a` vs `player_b`, score via `formatScore(sets)`, nom du vainqueur en gras (`font-semibold`) si `winner_id` correspond, badge de statut via `formatMatchStatus(status)`. |
| `PlayerRow.svelte` | Nom + pays, lien vers `/players/{slug}`. |

## 8. Nouvelles fonctions pures testables

`lib/format.ts` (étendu) :

```ts
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

export function formatRound(round: string): string {
	return ROUND_LABELS[round] ?? round;
}

export function formatMatchStatus(status: string): string {
	return MATCH_STATUS_LABELS[status] ?? status;
}

export function formatScore(sets: MatchSet[]): string {
	return sets
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

Nouveau fichier `apps/web/src/lib/tournament.ts` :

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

## 9. États vides

- Onglet "Calendrier" : vide avec les données de seed actuelles (tous les matchs sont `finished`) — message prévu et testé, pas un bug à corriger.
- Liste des tournois avec un filtre ne retournant rien : message "Aucun tournoi ne correspond à ces filtres."

## 10. Tests

| Fichier | Couvre |
|---|---|
| `lib/api/client.test.ts` (étendu) | `ApiError` porte bien `status` (le test existant "throws ApiError on a non-ok response" vérifie désormais aussi `error.status`). |
| `lib/format.test.ts` (étendu) | `formatRound`, `formatMatchStatus` (toutes les valeurs + fallback), `formatScore` (set simple, tie-break, plusieurs sets). |
| `lib/tournament.test.ts` | `playersFromMatches` : dédoublonnage, tri, matchs avec `player_a`/`player_b` null (bye) ignorés. |
| `lib/api/tournaments.test.ts` (étendu) | `listTournaments` (query params construits correctement), `getTournament`, `getMatchesForEdition`. |
| `lib/api/players.test.ts` | `getPlayer`. |
| `routes/tournaments/+page.server.test.ts` | lecture des query params, passage à `listTournaments`. |
| `routes/tournaments/[slug]/+page.server.test.ts` | sélection de la dernière édition, agrégation matches, **traduction d'un `ApiError` 404 en `error(404, ...)` de SvelteKit** (le test vérifie qu'appeler `load()` avec un mock rejetant en 404 lève bien une erreur SvelteKit de statut 404, pas autre chose). |
| `routes/players/[slug]/+page.server.test.ts` | passage direct à `getPlayer`, même traduction 404. |

Toujours pas de tests de rendu de composants Svelte (cohérent avec la Phase 4).

Côté backend (Elixir) : mise à jour de `apps/api/test/tennis_atlas_api/tournaments_test.exs` (le test de `list_matches_for_edition` doit vérifier que `sets` est bien préchargé) et `apps/api/test/tennis_atlas_api_web/controllers/tournament_edition_match_controller_test.exs` (le payload JSON doit inclure `sets`).

## 11. Hors scope (rappel)

- Sélecteur d'année/édition → à ajouter quand des données multi-éditions existeront.
- Entrées de tournoi (`tournament_entries`, seeds, statuts qualifié/wildcard) → pas d'endpoint, pas ajouté ici.
- Matchs cliquables / page détail match → Phase 8.
- Thème par surface → Phase 6.
- Tableau interactif (Draw) → Phase 7.
- Modification du classement joueur affiché au-delà de ce que `GET /api/players/:slug` expose déjà → rien à ajouter, l'endpoint couvre déjà le besoin.
