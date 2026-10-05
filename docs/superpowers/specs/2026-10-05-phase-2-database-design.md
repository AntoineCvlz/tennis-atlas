# Tennis Atlas — Phase 2 : Database — Design

**Date** : 2026-10-05
**Statut** : Validé par l'utilisateur en chat (ERD haut niveau) ; ce document formalise le détail champ par champ avant l'écriture du plan d'implémentation.
**Portée** : migrations Ecto, schemas, changesets, seeds. Pas de contexts Phoenix (fonctions publiques de requête) ni d'API REST — ça, c'est la Phase 3.
**Spec parente** : [2026-10-05-tennis-atlas-architecture-design.md](2026-10-05-tennis-atlas-architecture-design.md)

## 1. Décisions qui s'écartent du brief original

Le brief original (section 14 du prompt maître) décrivait les champs de façon informelle, pas comme un schéma normalisé. Trois corrections ont été nécessaires :

1. **`Tournament` référence `Venue` via `venue_id`** plutôt que de dupliquer `country`/`city`/`venue` en texte libre. Le brief avait les deux représentations en parallèle, ce qui aurait créé une désynchronisation dès la première modification de l'une sans l'autre.
2. **Pas de champ `score` texte libre sur `Match`** — la table `Set` est l'unique source de vérité pour le score, stocké de façon structurée (jeux par set, tie-breaks). Un champ texte parallèle n'aurait eu aucune valeur et aurait pu diverger.
3. **Ajout d'un champ `tour` (`:atp` / `:wta`) sur `Match` et `TournamentEntry`**, absent du brief original. Nécessaire parce qu'un Grand Slam (ex. Roland Garros) est **un seul** `Tournament`/`TournamentEdition` qui héberge simultanément un tableau ATP et un tableau WTA — sans ce champ, impossible de savoir à quel tableau un match ou un engagement appartient. Pour les tournois non-Slam (1000/500/250), qui ne sont historiquement que sur un seul circuit, toutes les lignes `Match`/`TournamentEntry` d'une même édition partageront naturellement la même valeur de `tour` (non forcé au niveau base de données — simplification volontaire pour cette phase).

Ce dernier point n'avait pas été mentionné lors de la présentation en chat de l'ERD — je le signale explicitement ici plutôt que de le glisser silencieusement dans le code.

## 2. Schéma détaillé

### `venues`
| Colonne | Type | Contraintes |
|---|---|---|
| name | `:string` | `null: false` |
| city | `:string` | `null: false` |
| country_code | `:string` | `null: false`, ISO 3166-1 alpha-3 (ex. `"FRA"`) |
| latitude | `:float` | nullable |
| longitude | `:float` | nullable |

### `courts`
| Colonne | Type | Contraintes |
|---|---|---|
| venue_id | `references(:venues)` | `null: false`, `on_delete: :delete_all` |
| name | `:string` | `null: false` |
| surface | `:string` (`Ecto.Enum`) | `[:clay, :grass, :hard, :indoor]`, `null: false` |
| capacity | `:integer` | nullable |
| indoor | `:boolean` | `null: false`, `default: false` |

### `tournaments`
| Colonne | Type | Contraintes |
|---|---|---|
| name | `:string` | `null: false` |
| slug | `:string` | `null: false`, index unique |
| category | `:string` (`Ecto.Enum`) | `[:grand_slam, :masters_1000, :atp_500, :atp_250, :wta_1000, :wta_500, :wta_250]`, `null: false` |
| surface | `:string` (`Ecto.Enum`) | `[:clay, :grass, :hard, :indoor]`, `null: false` |
| venue_id | `references(:venues)` | nullable, `on_delete: :nilify_all` |
| description | `:text` | nullable |
| logo_url | `:string` | nullable |
| hero_image_url | `:string` | nullable |

### `tournament_editions`
| Colonne | Type | Contraintes |
|---|---|---|
| tournament_id | `references(:tournaments)` | `null: false`, `on_delete: :delete_all` |
| year | `:integer` | `null: false` |
| start_date | `:date` | `null: false` |
| end_date | `:date` | `null: false` |
| status | `:string` (`Ecto.Enum`) | `[:upcoming, :ongoing, :completed, :cancelled]`, `null: false`, `default: :upcoming` |

Index unique sur `(tournament_id, year)`.

### `players`
| Colonne | Type | Contraintes |
|---|---|---|
| first_name | `:string` | `null: false` |
| last_name | `:string` | `null: false` |
| slug | `:string` | `null: false`, index unique |
| country_code | `:string` | `null: false`, ISO 3166-1 alpha-3 |
| birth_date | `:date` | nullable |
| hand | `:string` (`Ecto.Enum`) | `[:left, :right]`, nullable |
| height_cm | `:integer` | nullable |
| current_ranking | `:integer` | nullable (cache dénormalisé, source de vérité = `rankings`) |
| current_ranking_points | `:integer` | nullable |

### `matches`
| Colonne | Type | Contraintes |
|---|---|---|
| tournament_edition_id | `references(:tournament_editions)` | `null: false`, `on_delete: :delete_all` |
| tour | `:string` (`Ecto.Enum`) | `[:atp, :wta]`, `null: false` |
| round | `:string` (`Ecto.Enum`) | `[:r128, :r64, :r32, :r16, :qf, :sf, :f]`, `null: false` |
| player_a_id | `references(:players)` | nullable (bye/TBD), `on_delete: :nilify_all` |
| player_b_id | `references(:players)` | nullable, `on_delete: :nilify_all` |
| court_id | `references(:courts)` | nullable, `on_delete: :nilify_all` |
| scheduled_at | `:utc_datetime` | nullable |
| started_at | `:utc_datetime` | nullable |
| finished_at | `:utc_datetime` | nullable |
| status | `:string` (`Ecto.Enum`) | `[:scheduled, :live, :finished, :retired, :walkover, :cancelled]`, `null: false`, `default: :scheduled` |
| winner_id | `references(:players)` | nullable, `on_delete: :nilify_all` |
| best_of | `:integer` | `null: false`, `default: 3` |

Index sur `tournament_edition_id`, `player_a_id`, `player_b_id`, `status` (ce dernier anticipe les requêtes du Live Center en Phase 12).

### `sets`
| Colonne | Type | Contraintes |
|---|---|---|
| match_id | `references(:matches)` | `null: false`, `on_delete: :delete_all` |
| set_number | `:integer` | `null: false` |
| player_a_games | `:integer` | `null: false` |
| player_b_games | `:integer` | `null: false` |
| tiebreak_a | `:integer` | nullable |
| tiebreak_b | `:integer` | nullable |

Index unique sur `(match_id, set_number)`.

### `tournament_entries`
| Colonne | Type | Contraintes |
|---|---|---|
| tournament_edition_id | `references(:tournament_editions)` | `null: false`, `on_delete: :delete_all` |
| player_id | `references(:players)` | `null: false`, `on_delete: :delete_all` |
| tour | `:string` (`Ecto.Enum`) | `[:atp, :wta]`, `null: false` |
| seed | `:integer` | nullable |
| entry_type | `:string` (`Ecto.Enum`) | `[:direct, :qualifier, :wildcard, :lucky_loser]`, `null: false`, `default: :direct` |
| status | `:string` (`Ecto.Enum`) | `[:active, :withdrawn]`, `null: false`, `default: :active` |

Index unique sur `(tournament_edition_id, player_id)`.

### `rankings`
| Colonne | Type | Contraintes |
|---|---|---|
| player_id | `references(:players)` | `null: false`, `on_delete: :delete_all` |
| ranking_type | `:string` (`Ecto.Enum`) | `[:atp, :wta]`, `null: false` |
| position | `:integer` | `null: false` |
| points | `:integer` | `null: false` |
| as_of_date | `:date` | `null: false` |

Index unique sur `(player_id, ranking_type, as_of_date)`.

Toutes les tables ont `id` (bigserial) et `timestamps()` (non listés ci-dessus par souci de concision).

## 3. Organisation des modules

Les schemas sont namespacés par contexte métier anticipé (les fonctions publiques de requête arrivent en Phase 3, mais la frontière de contexte se décide maintenant) :

```
lib/tennis_atlas_api/
  venues/
    venue.ex
    court.ex
  tournaments/
    tournament.ex
    tournament_edition.ex
    tournament_entry.ex
  players/
    player.ex
    ranking.ex
  matches/
    match.ex
    set.ex
  repo.ex   (déjà généré en Phase 1)
```

## 4. Seeds

Les données de seed sont **fictives**, explicitement marquées comme telles en commentaire dans `priv/repo/seeds.exs` (conformément à la section 43 du brief : pas de données réelles sans source API réelle, qui n'arrive qu'en Phase 9).

Contenu :
- **3 venues** : un par surface (clay/grass/hard) — ex. "Stade Fictif de Paris" (clay), "All England Fictif Club" (grass), "Fictif National Tennis Center" (hard).
- **1-2 courts** par venue.
- **3 tournaments** : un par surface, catégories mixtes pour la variété (`grand_slam`, `grand_slam`, `atp_500`) — rattachés à leur venue respective.
- **1 tournament_edition** par tournoi (année courante, `status: :completed`, dates passées pour rester cohérent dans le temps).
- **~16 players** fictifs (noms inventés, pas de joueurs professionnels réels), `country_code` variés.
- **Un mini-tableau par tournoi** : quarts → demies → finale (7 matchs, 8 joueurs), tous `status: :finished`, avec scores de sets plausibles et `winner_id` renseigné. Les 3 tournois utilisent des sous-ensembles différents des 16 joueurs.
- **tournament_entries** correspondantes (seeds 1-8) pour les joueurs engagés dans chaque tournoi.
- **1 ranking snapshot** par joueur (`as_of_date` fixe, `ranking_type` cohérent avec le tableau où il/elle apparaît).

Volume volontairement modeste (section 53 : "créer quelques données réalistes", pas le dataset complet de la section 43) — suffisant pour valider le schéma et donner une base visuelle aux phases 5-7, extensible plus tard sans migration supplémentaire.

## 5. Tests

Pour chaque schema : tests de changeset (cas valide, champs requis manquants, contraintes d'unicité) via `TennisAtlasApi.DataCase` (déjà généré en Phase 1). Pas de tests de contexte (pas de fonctions de requête publiques encore) — ça viendra avec les contexts en Phase 3.

## 6. Hors scope (rappel)

- Contexts Phoenix / fonctions de requête publiques → Phase 3.
- Endpoints REST exposant ces données → Phase 3.
- Oban / synchronisation externe → Phase 9.
- Validation stricte que tous les `Match`/`TournamentEntry` d'une même `TournamentEdition` partagent le même `tour` (actuellement non contrainte en base) → à revisiter si un vrai besoin apparaît.
