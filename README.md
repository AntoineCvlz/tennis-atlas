# Tennis Atlas

Plateforme d'exploration du tennis mondial — projet portfolio démontrant une architecture full-stack avec SvelteKit, Phoenix/Elixir et PostgreSQL.

## Stack

- **Frontend** : SvelteKit 3 + Svelte 5 (runes) + TypeScript
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

Pour charger des données de démonstration (fictives) :

```bash
docker compose run --rm api mix run priv/repo/seeds.exs
```

- API : http://localhost:4000 (health check : `/api/health`)
- Web : http://localhost:5173

Le premier démarrage après un `docker compose up` propre peut prendre environ
une minute : l'API compile ~30 dépendances et exécute les migrations depuis
zéro. La page web réessaie automatiquement la connexion à l'API pendant ce
temps, inutile de la rafraîchir manuellement.

Si un port est déjà utilisé sur votre machine (5432, 4000 ou 5173), modifiez
la variable `*_PORT` correspondante dans `.env`.

### Lancer les tests de l'API

```bash
docker compose run --rm api mix test
```

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
