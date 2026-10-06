# Tennis Atlas — Phase 4 : Frontend — Design

**Date** : 2026-10-06
**Statut** : Validé par l'utilisateur en chat, section par section.
**Portée** : layout de base, navigation, design system (Tailwind), homepage consommant réellement l'API (Phase 3). Pas de Tournament Explorer (Phase 5), pas de thème par surface (Phase 6), pas de pages tournoi/joueur/match détaillées.
**Spec parente** : [2026-10-05-tennis-atlas-architecture-design.md](2026-10-05-tennis-atlas-architecture-design.md)
**Spec précédente** : [2026-10-06-phase-3-backend-design.md](2026-10-06-phase-3-backend-design.md)

## 1. Contexte et décisions de portée

Le frontend actuel (Phase 1) est un squelette SvelteKit nu : une page qui appelle `/api/health` côté client dans `onMount` pour prouver que le stack est branché. La Phase 3 a livré une vraie API REST ; cette phase remplace le placeholder par une vraie homepage, pose le layout (navigation + footer) que toutes les pages futures réutiliseront, et introduit Tailwind comme design system.

Décisions actées en discussion :
- **Homepage = hero statique + tournois en vedette** (appel réel à `GET /api/tournaments`), pas une page de branding pure — pour prouver dès cette phase que le frontend consomme vraiment l'API, sans attendre la Phase 5.
- **Tailwind CSS** comme approche de styling (vs CSS natif + variables) — standard d'industrie, bonne base de tokens pour le `SurfaceTheme` de la Phase 6.
- **Navigation minimale** : seul le logo/nom "Tennis Atlas" (lien vers `/`). Pas de liens vers des pages qui n'existent pas encore (Tournois, Joueurs, Live) — pas de liens morts dans un projet portfolio. Les liens seront ajoutés phase par phase, au fur et à mesure que chaque page existe réellement.
- **Widget de statut API/DB (Phase 1) retiré** de la homepage — son rôle (prouver la connectivité du stack) est maintenant rempli par l'affichage réel des tournois ; le code reste dans l'historique git.
- **Pas de `packages/shared` pour l'instant** : les types TS des DTOs de l'API vivent dans `apps/web/src/lib/api/types.ts`. Le package partagé prévu au spec d'architecture (section 7) n'a aujourd'hui aucun second consommateur TS — le créer maintenant serait une structure prématurée. À migrer dès qu'un second consommateur réel apparaît.
- **Chargement des données en SSR** via une fonction `load` SvelteKit (`+page.server.ts`), pas un fetch client dans `onMount` — cohérent avec la justification SSR/SEO du spec d'architecture (section 4), et pose le pattern que les pages tournoi/joueur réutiliseront.
- **Vitest configuré dès cette phase** (pas différé à la Phase 13) pour tester le client API et la fonction `load()` — cohérent avec la pratique TDD déjà appliquée côté backend (Phases 2-3). Pas de tests de rendu de composants Svelte (`@testing-library/svelte`) cette phase — composants trop simples pour en justifier le coût d'ajout maintenant.

## 2. Problème réseau Docker découvert en investigation

`+page.server.ts` s'exécute exclusivement côté serveur (Node, dans le conteneur `web`), jamais dans le navigateur. `PUBLIC_API_URL` (actuellement `http://localhost:4000`, exposée via l'API env explicite de SvelteKit depuis la Phase 1) est destinée au navigateur — à l'intérieur du conteneur `web`, `localhost` pointe vers le conteneur lui-même, pas vers le conteneur `api`.

**Décision** : ajouter une variable d'environnement **privée** (jamais exposée au bundle client) `API_INTERNAL_URL`, valeur `http://api:4000` (nom du service Docker Compose, port interne du conteneur), utilisée uniquement par le fetch SSR. `PUBLIC_API_URL` reste réservée à un futur usage côté navigateur (aucun composant n'en a besoin dans cette phase). Valeur fixe, non templatée depuis `.env` (contrairement aux ports qui varient par développeur) — elle ne change jamais entre environnements Docker Compose.

## 3. Structure de fichiers

```
apps/web/
  vitest.config.ts
  src/
    app.css                              (directives Tailwind, pas de CSS custom au-delà)
    env.ts                                (+ déclaration API_INTERNAL_URL, public: false)
    lib/
      api/
        client.ts                        (apiFetch<T>(path): Promise<T>)
        client.test.ts
        tournaments.ts                    (getTournaments(): Promise<Tournament[]>)
        tournaments.test.ts
        types.ts                          (Tournament, TournamentEdition, Venue)
      components/
        Nav.svelte
        Footer.svelte
        Hero.svelte
        TournamentCard.svelte
        FeaturedTournaments.svelte
    routes/
      +layout.svelte                      (Nav + <main> + Footer)
      +page.svelte                        (Hero + FeaturedTournaments)
      +page.server.ts                     (load() → tournois en vedette)
      +page.server.test.ts
docker-compose.yml                         (+ API_INTERNAL_URL sur le service web)
```

`src/routes/+page.svelte` (Phase 1) est remplacée entièrement — plus d'appel à `/api/health`, plus de logique de retry.

## 4. Composants et responsabilités

| Composant | Props | Rôle |
|---|---|---|
| `Nav.svelte` | — | Bande supérieure, logo/nom "Tennis Atlas" cliquable vers `/`. Rien d'autre. |
| `Footer.svelte` | — | Copyright + lien vers le repo GitHub du projet. Pas de widget de statut API. |
| `Hero.svelte` | — | Titre + accroche courte. Pas de bouton CTA (aucune page à lier encore). |
| `TournamentCard.svelte` | `tournament: Tournament` | Nom, catégorie et surface affichées via un petit mapping local `{clay: "Terre battue", grass: "Gazon", hard: "Dur", indoor: "Indoor"}` / équivalent pour `category` — pas la valeur brute de l'enum (`"grand_slam"`), pas de couleur (différée à la Phase 6). Pas de lien cliquable (pas de page détail tournoi — Phase 5). |
| `FeaturedTournaments.svelte` | `tournaments: Tournament[]` | Grille de `TournamentCard` ; affiche un message ("Tournois indisponibles pour le moment") si la liste est vide (y compris en cas d'erreur API). |

## 5. Flux de données

`src/lib/api/types.ts` définit les types correspondant au contrat JSON de la Phase 3 (snake_case, tel que renvoyé par l'API — pas de transformation de casse) :

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

`src/lib/api/client.ts` :

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

`src/lib/api/tournaments.ts` :

```ts
import { apiFetch } from './client';
import type { Tournament } from './types';

export async function getTournaments(): Promise<Tournament[]> {
  const { data } = await apiFetch<{ data: Tournament[] }>('/api/tournaments');
  return data;
}
```

`src/routes/+page.server.ts` :

```ts
import type { PageServerLoad } from './$types';
import { getTournaments } from '$lib/api/tournaments';

export const load: PageServerLoad = async () => {
  try {
    const tournaments = await getTournaments();
    return { tournaments: tournaments.slice(0, 3), apiError: false };
  } catch {
    return { tournaments: [], apiError: true };
  }
};
```

Une erreur réseau ou API ne fait jamais crasher la page vers l'écran d'erreur SvelteKit — elle dégrade proprement vers une liste vide avec message, le hero reste affiché.

## 6. Design system (Tailwind)

Tailwind v4, intégration native via son plugin Vite (`@tailwindcss/vite`) — pas de `tailwind.config.ts`/`postcss.config.js` (obsolètes depuis la v4, qui configure tout en CSS).

- `app.css` : `@import "tailwindcss";` puis un bloc `@theme` définissant une palette neutre de base + une couleur d'accent — pas de tokens par surface (différé à la Phase 6, qui étendra ce bloc).
- `vite.config.ts` : ajout du plugin `tailwindcss()` (de `@tailwindcss/vite`) à côté de `sveltekit()`.
- Composants stylés directement en classes utilitaires Tailwind dans le markup, pas de fichiers `.css` séparés par composant.

## 7. Tests (Vitest)

| Fichier | Couvre |
|---|---|
| `client.test.ts` | `apiFetch` retourne les données parsées sur 200 ; lève `ApiError` sur `!res.ok` ou erreur réseau. |
| `tournaments.test.ts` | `getTournaments` appelle le bon chemin et retourne `.data` de l'enveloppe `{data, meta}`. |
| `+page.server.test.ts` | `load()` retourne `{tournaments, apiError: false}` sur succès (avec troncature à 3) ; retourne `{tournaments: [], apiError: true}` si `getTournaments` rejette. |

`fetch` mocké dans les tests (pas d'appel réseau réel, pas de dépendance à l'API ou à la DB pour ces tests — contrairement aux tests Elixir qui tournent contre une vraie Postgres).

## 8. Hors scope (rappel)

- Tournament Explorer (liste paginée, filtres, page détail tournoi) → Phase 5.
- Système de thème par surface (couleurs/animations par `Clay`/`Grass`/`Hard`/`Indoor`) → Phase 6. `TournamentCard` affiche la surface en texte brut cette phase.
- Navigation complète (liens Tournois/Joueurs/Live) → ajoutée phase par phase.
- `packages/shared` → créé quand un second consommateur TS réel apparaît.
- Tests de rendu de composants Svelte (`@testing-library/svelte`) → différés, pas de besoin identifié pour des composants aussi simples cette phase.
- Usage côté navigateur de `PUBLIC_API_URL` → aucun composant n'en a besoin encore (tout le data-fetching de cette phase est SSR).
