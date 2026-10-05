# Tennis Atlas — Design d'architecture globale

**Date** : 2026-10-05
**Statut** : Validé par l'utilisateur (section 7 de la présentation initiale, réponse "oui ca me convient")
**Portée de ce document** : vision d'ensemble du projet. Chaque phase listée en section 8 aura son propre cycle design → plan → implémentation ; ce document n'est pas un plan d'implémentation détaillé.

## 1. Contexte et objectif

Tennis Atlas est un projet portfolio/CV : une plateforme web d'exploration du tennis mondial (tournois, joueurs, matchs, classements), avec mise à jour en temps réel des scores en direct. L'objectif explicite est double : produire une application fonctionnelle ET une architecture que l'auteur puisse défendre en entretien technique (choix justifiés, compromis assumés, pas de sur-ingénierie gratuite).

Le projet est développé dans `c:\Users\acuvilliez\Desktop\Projets\Perso\sportpulse`, nouveau repo git, vide au démarrage.

## 2. Principe fondamental

PostgreSQL est la **source de vérité locale** de l'application. L'API tennis externe n'est qu'une source d'import/synchronisation, jamais appelée directement par le frontend. Toutes les lectures (REST) et tous les événements temps réel (PubSub/Channels) proviennent de Postgres, pas de l'API externe.

## 3. Architecture globale

```
Tennis API (externe) → Oban (jobs planifiés) → Phoenix (ingestion/normalisation)
                                                        |
                                                  PostgreSQL (vérité canonique)
                                                 /                        \
                                        REST API                   Phoenix PubSub
                                                                           |
                                                                  Phoenix Channels
                                                 \                        /
                                                   SvelteKit (frontend)
```

Trois flux distincts partageant la même source de vérité :
- **Flux froid** (API → Oban → Postgres) : asynchrone, planifié, tolérant aux pannes (retries Oban).
- **Flux de lecture** (Postgres → REST → SvelteKit) : synchrone classique, pour tout ce qui n'a pas besoin d'instantanéité.
- **Flux chaud** (Postgres → PubSub → Channels → SvelteKit) : réservé aux événements métier qui justifient le temps réel (ex. score qui change pendant un match live). Ne pas utiliser le temps réel artificiellement — uniquement quand une information intéressante change réellement.

## 4. Responsabilités par technologie

| Techno | Rôle | Justification (pour l'entretien) |
|---|---|---|
| SvelteKit + TypeScript | UI, routing, SSR/SEO, état local des composants | SSR natif utile pour le SEO des pages tournoi/joueur ; moins de boilerplate qu'un SPA React classique |
| Phoenix / Elixir | API REST, contexts métier, orchestration temps réel | La BEAM supporte nativement des milliers de connexions WebSocket concurrentes avec supervision — c'est l'argument différenciant du projet |
| Ecto + PostgreSQL | Persistance, intégrité relationnelle | Les données tennis sont fortement relationnelles (tournoi → édition → match → set → joueur) ; Postgres comme source de vérité unique évite la dérive de cohérence |
| Oban | Jobs planifiés, synchronisation, retries durables | Les jobs survivent à un redémarrage (stockés en DB), contrairement à un cron applicatif ou un `:timer` en mémoire |
| Phoenix PubSub / Channels | Diffusion des événements métier détectés | Découple la détection d'un changement de sa diffusion aux clients connectés |
| Docker Compose | Environnement de développement reproductible | `docker compose up` comme point d'entrée unique, onboarding instantané |

Redis n'est volontairement **pas** inclus au démarrage (PubSub + Postgres + Oban suffisent) ; il ne sera ajouté que si un besoin réel apparaît (cache distribué, rate limiting, scaling spécifique).

## 5. Flux complet d'une donnée (exemple : mise à jour d'un score)

```
03:00 → Oban déclenche SyncMatchesJob
      → TennisProvider.get_matches(tournament_id)   (couche d'abstraction fournisseur)
      → validation (changeset) puis normalisation vers le schéma interne Match/Set
      → comparaison avec l'état précédent en DB
      → diff détecté → UPDATE Postgres + émission d'un domain event MatchScoreUpdated
      → Phoenix.PubSub.broadcast("match:123", event)
      → le Channel abonné pousse le payload au client concerné
      → le composant Svelte Scoreboard reçoit l'event et se met à jour seul (pas de reload de page)
```

Règle clé : **détection de changement avant diffusion**. Un broadcast n'a lieu que si la donnée a réellement changé par rapport à l'état précédent en base — ça évite le bruit temps réel et garde le PubSub honnête (il reflète un changement métier réel, pas un polling bavard).

### Fréquence de synchronisation par type de donnée

| Donnée | Fréquence |
|---|---|
| Tournois, infos tournoi | 1×/jour |
| Joueurs | 1×/jour ou moins |
| Rankings | 1×/jour |
| Calendrier, Order of Play | plusieurs fois/jour |
| Résultats | plusieurs fois/jour |
| Match live | toutes les X secondes |
| Match terminé | synchronisation immédiate |
| Blessure/retrait | dès disponibilité |

### Domain events prévus (liste non exhaustive, extensible)

`TournamentCreated`, `TournamentUpdated`, `MatchCreated`, `MatchUpdated`, `MatchStarted`, `MatchScoreUpdated`, `MatchFinished`, `MatchDelayed`, `MatchCancelled`, `PlayerUpdated`, `PlayerWithdrew`, `RankingUpdated`, `OrderOfPlayUpdated`.

## 6. Modèle de données initial

Entités principales : `Tournament`, `TournamentEdition`, `Venue`, `Court`, `Player`, `Match`, `Set`, `TournamentEntry`, `Ranking`.

Point de conception important : **`Tournament` et `TournamentEdition` sont deux entités distinctes**, pas une seule table avec des dates. Un `Tournament` porte l'identité stable (nom, slug, pays, ville, venue, catégorie, surface, logo) ; une `TournamentEdition` porte ce qui change chaque année (année, dates, statut). Exemple : "Roland Garros" est un `Tournament`, "Roland Garros 2025" et "Roland Garros 2026" sont deux `TournamentEdition` liées à ce même tournoi. Tout `Match` est rattaché à une `TournamentEdition` (`match.tournament_edition_id`), jamais directement à un `Tournament`. Ce choix rend l'historique multi-années gratuit et évite la duplication d'identité.

Champs détaillés par entité : voir section 14 du brief initial (conservés tels quels — `Tournament`, `TournamentEdition`, `Venue`, `Court`, `Player`, `Match`, `Set`, `TournamentEntry`, `Ranking`).

Surfaces supportées : `CLAY`, `GRASS`, `HARD`, `INDOOR` — chacune avec sa propre identité visuelle (thème, palette, animations), gérée par un système de thème centralisé (`SurfaceTheme`) plutôt que des couleurs codées en dur par composant.

## 7. Organisation du monorepo

```
tennis-atlas/
├── apps/
│   ├── web/        (SvelteKit)
│   └── api/         (Phoenix)
├── packages/
│   └── shared/      (types TS partagés : DTO API, enums Surface/Category...)
├── docker/
├── docs/
│   └── superpowers/specs/   (specs de brainstorming, ce document inclus)
├── .github/workflows/
├── docker-compose.yml
└── .env.example
```

Gestion du monorepo JS : **pnpm workspaces** pour `apps/web` + `packages/shared`, sans Turborepo/Nx. Le monorepo ne compte que deux packages JS ; un orchestrateur dédié serait de la sur-ingénierie pour cette taille de projet.

## 8. Découpage en phases (rappel, chaque phase = son propre cycle)

1. Architecture (repo, Docker, Postgres, SvelteKit, Phoenix — `docker compose up` fonctionnel)
2. Database (migrations, schemas Ecto, seeds)
3. Backend (contexts, REST API, validation, pagination)
4. Frontend (layout, navigation, design system, homepage)
5. Tournament Explorer (liste, page tournoi, schedule, players, results)
6. Surface System (thèmes Clay/Grass/Hard/Indoor)
7. Draw (tableau interactif)
8. Match (page match, scoreboard, stats)
9. Data ingestion (`TennisProvider`, premiers jobs Oban)
10. Synchronisation (fetch → validate → normalize → compare → persist → emit events)
11. Realtime (PubSub, Channels, client WebSocket SvelteKit)
12. Live Center (`/live`)
13. Tests (unit, intégration, E2E)
14. Observabilité (logs, métriques, OpenTelemetry, Grafana)
15. CI/CD (GitHub Actions)
16. Polish (animations, responsive, a11y, perf, SEO, états de chargement/erreur)

Ce document couvre la vision d'ensemble ; **seule la Phase 1 sera détaillée dans un plan d'implémentation immédiatement après validation de ce spec** (via la skill writing-plans).

## 9. Décisions techniques tranchées

- **Svelte 5 (runes)**, pas Svelte 4 — paradigme actuel, plus pertinent à présenter en entretien.
- **Phoenix 1.7/1.8**, Elixir stable récent, OTP 27 — à confirmer contre les versions déjà installées localement au moment de la Phase 1.
- **pnpm workspaces** sans Turborepo/Nx (cf. section 7).
- **Pas de Redis** au démarrage (cf. section 4).
- **Tournament / TournamentEdition séparés** dès le modèle initial (cf. section 6).
- Détection de changement obligatoire avant tout broadcast PubSub (cf. section 5).

## 10. Décisions différées (à trancher plus tard, explicitement hors scope de ce document)

- **Fournisseur de données tennis externe** : non choisi ici. Un fournisseur ne doit pas être sélectionné sur la base de connaissances figées (tarifs/limites/conditions changent) ; un spike de recherche dédié aura lieu juste avant la Phase 9 (Data ingestion). Les Phases 1 à 8 fonctionnent entièrement sur données mock/seed locales, donc ce choix ne bloque rien avant la Phase 9.
- **Tests unitaires frontend (Vitest)** : proposé en complément de Playwright (E2E) pour la logique pure (ex. système de thème par surface), non confirmé par l'utilisateur — à retrancher lors de la Phase 13 (Tests) ou avant si le besoin apparaît plus tôt.
- **Hébergement/déploiement de production** : non tranché. Candidats évoqués : Fly.io (bon fit Elixir + Postgres) vs VPS unique en Docker Compose (plus simple à expliquer en entretien, miroir exact du setup local). Décision différée à la Phase 15 (CI/CD).

## 11. Hors scope

- Authentification / comptes utilisateurs : absents du brief initial, non inclus dans ce design. Pourrait être une évolution v2 (favoris, notifications) mais n'est pas un prérequis des 16 phases listées.
- Choix définitif du fournisseur de données (voir section 10).
