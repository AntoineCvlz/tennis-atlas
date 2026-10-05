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
