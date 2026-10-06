# Tennis Atlas — Phase 3 : Backend — Design

**Date** : 2026-10-06
**Statut** : Validé par l'utilisateur en chat, section par section.
**Portée** : contexts Phoenix (fonctions de requête publiques), endpoints REST en lecture, pagination, validation des paramètres de requête, gestion d'erreurs. Pas de frontend consommant ces endpoints (Phase 4+), pas d'ingestion externe (Phase 9), pas de temps réel (Phase 11).
**Spec parente** : [2026-10-05-tennis-atlas-architecture-design.md](2026-10-05-tennis-atlas-architecture-design.md)
**Spec précédente** : [2026-10-05-phase-2-database-design.md](2026-10-05-phase-2-database-design.md)

## 1. Décision de portée : API en lecture seule

Le spec d'architecture (section 2) établit que Postgres est la source de vérité et que le frontend ne lit que via REST, jamais directement l'API externe. L'ingestion (Oban, Phase 9) écrira en base directement via les fonctions de context, sans passer par HTTP.

**Conséquence pour cette phase** : les endpoints REST exposés sont exclusivement des lectures (`GET` — list/show). Les contexts exposent par ailleurs des fonctions d'écriture (`create_*`, `update_*`, `delete_*` si nécessaire) pour un usage interne futur (seeds, Oban), mais aucun endpoint REST ne les expose. Pas de `POST`/`PUT`/`PATCH`/`DELETE` dans le router pour l'instant.

## 2. Ressources exposées

Quatre ressources ont des endpoints dédiés : `Tournament` (avec `TournamentEdition` imbriqué), `Player`, `Match`, `Ranking`. `Venue` et `Court` n'ont pas d'endpoint propre — ils apparaissent uniquement comme objets imbriqués dans les réponses `Tournament`/`Match`, cohérent avec le fait qu'ils n'ont pas de page dédiée prévue dans les phases frontend (5, 7, 8).

## 3. Modules de context

Pas de nouveau découpage de contexts : chaque module de requête publique est ajouté dans le dossier de context déjà créé en Phase 2 (`venues/`, `tournaments/`, `players/`, `matches/`), cohérent avec la frontière métier déjà posée par les schemas.

```
TennisAtlasApi.Tournaments
  list_tournaments(filters \\ %{}, page \\ 1, page_size \\ 20)
    # filters: :surface, :category
    # preload: :venue
  get_tournament_by_slug!(slug)
    # preload: :venue, :tournament_editions
  get_edition!(tournament_slug, year)
    # preload: :tournament
  list_matches_for_edition(edition_id, filters \\ %{}, page \\ 1, page_size \\ 20)
    # filters: :tour, :status
    # preload: :player_a, :player_b, :court

TennisAtlasApi.Players
  list_players(filters \\ %{}, page \\ 1, page_size \\ 20)
    # filters: :country_code
  get_player_by_slug!(slug)
  list_rankings(filters, page \\ 1, page_size \\ 20)
    # filters: :ranking_type (obligatoire — une erreur 422 est renvoyée si absent)
    # retourne un snapshot par joueur : la ligne la plus récente (as_of_date max)
    # par (player_id, ranking_type), triée par position croissante
    # preload: :player

TennisAtlasApi.Matches
  get_match!(id)
    # preload: :sets, :player_a, :player_b, :court,
    #          tournament_edition: :tournament
```

`Ranking` reste sous `Players` (c'est déjà là que vit le schema depuis la Phase 2) plutôt que de créer un context `Rankings` séparé pour une seule fonction de requête.

## 4. Routes

```
GET /api/tournaments
GET /api/tournaments/:slug
GET /api/tournaments/:slug/editions/:year/matches
GET /api/players
GET /api/players/:slug
GET /api/matches/:id
GET /api/rankings
```

Toutes dans le scope `/api` existant (`router.ex`, déjà en place depuis la Phase 1 pour `/api/health`).

## 5. Filtres par ressource

| Endpoint | Query params acceptés | Obligatoire ? |
|---|---|---|
| `GET /api/tournaments` | `surface`, `category` | non |
| `GET /api/players` | `country_code` | non |
| `GET /api/tournaments/:slug/editions/:year/matches` | `tour`, `status` | non |
| `GET /api/rankings` | `ranking_type` | **oui** — 422 si absent |

Les valeurs de filtre correspondant à un `Ecto.Enum` (`surface`, `category`, `tour`, `status`, `ranking_type`) sont validées contre les valeurs autorisées de leur enum respectif ; une valeur hors enum renvoie 422 (voir section 7).

## 6. Pagination

Helper maison `TennisAtlasApi.Pagination` (pas de lib externe type Scrivener — cohérent avec le refus déjà acté de dépendances non justifiées, cf. spec d'architecture section 4/9). Prend une `Ecto.Query` de base plus `page`/`page_size`, retourne :

```elixir
%{
  entries: [...],
  page: 1,
  page_size: 20,
  total_count: 87,
  total_pages: 5
}
```

Query params : `page` (défaut 1), `page_size` (défaut 20, max 100 — une valeur supérieure est silencieusement plafonnée à 100, pas une erreur). `page`/`page_size` non numériques ou `page` < 1 renvoient 422.

## 7. Contrat de réponse et gestion d'erreurs

**Succès — liste** :
```json
{
  "data": [ { "...": "..." } ],
  "meta": { "page": 1, "page_size": 20, "total_count": 87, "total_pages": 5 }
}
```

**Succès — détail** :
```json
{ "data": { "...": "..." } }
```

Clés JSON en `snake_case`, identiques aux noms de colonnes Ecto — aucune transformation de casse.

Vues JSON natives Phoenix (`*_json.ex`), une par ressource exposée (`TournamentJSON`, `PlayerJSON`, `MatchJSON`, `RankingJSON`), suivant le pattern déjà en place (`ErrorJSON` depuis la Phase 1). Chaque vue gère ses associations imbriquées : `TournamentJSON` inclut `venue` et un résumé des `editions` ; `MatchJSON` inclut `sets`, `player_a`/`player_b` (résumé), `court`.

**Erreur — 404 (ressource introuvable)** :
```json
{ "errors": { "detail": "Not Found" } }
```
Déclenché quand `get_*_by_slug!`/`get_match!`/`get_edition!` lève `Ecto.NoResultsError`. Centralisé via un `FallbackController` (pattern Phoenix standard) plutôt que du `try/rescue` dupliqué dans chaque action.

**Erreur — 422 (paramètres de requête invalides)** :
```json
{ "errors": { "ranking_type": ["is invalid"] } }
```
Chaque controller valide ses query params via un changeset sans schema (`Ecto.Changeset.cast({%{}, types}, params, keys) |> Ecto.Changeset.validate_...`) avant d'appeler le context. Un changeset invalide est renvoyé au `FallbackController`, qui le sérialise en 422 avec les erreurs par champ (même format que les erreurs de changeset déjà vues en Phase 2 sur les schemas métier).

## 8. Tests

- **Tests de context** (`TennisAtlasApi.DataCase`) : un fichier par context, couvrant pour chaque fonction publique le cas de base, les filtres, la pagination (page vide, dernière page, `page_size` plafonné), les preloads attendus.
- **Fixtures** : module maison par schema (`TennisAtlasApi.TournamentsFixtures`, etc.), fonctions `tournament_fixture/1` type `insert avec valeurs par défaut + overrides`, pas de lib externe (ExMachina) — cohérent avec l'absence de dépendance de test ajoutée en Phase 2.
- **Tests de controller** (`TennisAtlasApiWeb.ConnCase`) : un fichier par ressource, couvrant pour chaque endpoint le succès (200, forme de la réponse), les filtres, la pagination aux bornes, le 404, et le 422 sur paramètre invalide.

## 9. Hors scope (rappel)

- Tout endpoint d'écriture REST (`POST`/`PUT`/`PATCH`/`DELETE`) → différé à une phase ultérieure si un besoin réel apparaît (aucun n'est anticipé avant Phase 9, et Phase 9 écrit directement via les contexts, pas via HTTP).
- Endpoints dédiés `Venue`/`Court` → pas de besoin identifié dans les phases frontend planifiées.
- Authentification/autorisation → hors scope du projet entier (cf. spec d'architecture section 11).
- Consommation de ces endpoints par le frontend → Phase 4 et suivantes.
- Temps réel (PubSub/Channels) → Phase 11.
