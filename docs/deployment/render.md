# Render Deployment

## Prerequisites

- [Render CLI](https://render.com/docs/cli) installed and logged in (`render login`)
- `render.yaml` at project root (already committed)
- Dockerfile at project root (already committed)
- GitHub repo connected to Render (`git@github.com:usman1100/zeval.git`)

## One-time setup

### Option A: Blueprint deploy (recommended)

The `render.yaml` at the project root defines both a web service and a Posgres
database. To deploy it, push the file to GitHub and use the Render Dashboard:

1. Push `render.yaml`:
   ```bash
   git add render.yaml && git commit -m "add render blueprint" && git push
   ```
2. Go to [dashboard.render.com](https://dashboard.render.com) → **New +** →
   **Blueprint** → connect your `usman1100/zeval` repo.
3. Render reads `render.yaml` and creates both resources.
4. Set the **secrets** (`SECRET_KEY_BASE`, `SESSION_SIGNING_SALT`,
   `SESSION_ENCRYPTION_SALT`, `LIVE_VIEW_SIGNING_SALT`, `METRICS_TOKEN`) in the
   Render Dashboard under each service's **Environment** tab, then re-deploy.

### Option B: CLI (manual, step-by-step)

```bash
# 1. Create the Posgres database
render ea pg create --confirm \
  --name zeval-db \
  --database-name zeval \
  --plan free \
  --region oregon

# 2. Get the internal connection string
render ea pg get zeval-db --include-sensitive-connection-info --output json

# 3. Generate Phoenix secrets
SECRET_KEY_BASE=$(openssl rand -base64 64)
SESSION_SIGNING_SALT=$(openssl rand -base64 32)
SESSION_ENCRYPTION_SALT=$(openssl rand -base64 32)
LIVE_VIEW_SIGNING_SALT=$(openssl rand -base64 32)

# 4. Create the web service
render services create \
  --type web_service \
  --runtime docker \
  --name zeval-engine \
  --repo https://github.com/usman1100/zeval.git \
  --health-check-path /health \
  --plan free \
  --env-var "DATABASE_URL=<internal-connection-string-from-step-2>" \
  --env-var "DATABASE_SSL=false" \
  --env-var "POOL_SIZE=10" \
  --env-var "ENGINE_PORT=4000" \
  --env-var "PHX_HOST=zeval-engine.onrender.com" \
  --env-var "LOG_LEVEL=info" \
  --env-var "SECRET_KEY_BASE=$SECRET_KEY_BASE" \
  --env-var "SESSION_SIGNING_SALT=$SESSION_SIGNING_SALT" \
  --env-var "SESSION_ENCRYPTION_SALT=$SESSION_ENCRYPTION_SALT" \
  --env-var "LIVE_VIEW_SIGNING_SALT=$LIVE_VIEW_SIGNING_SALT" \
  --output json \
  --confirm

# 5. Trigger an initial deploy
render deploys create srv-<service-id> --confirm
```

## Deploy

Deploys happen **automatically** on every push to the `main` branch (auto-deploy
is enabled by default). To manually trigger a deploy:

```bash
# List services to get the service ID
render services --output json

# Trigger a deploy
render deploys create srv-<service-id> --confirm
```

This will:
1. Build the Docker image using the project Dockerfile (multi-stage Elixir release)
2. Run database migrations via `bin/zeval_engine eval "ZevalCore.Release.migrate()"`
3. Start the Phoenix server
4. Pass the health check at `/health`

## Secrets reference

| Secret | Source | Required |
|---|---|---|
| `DATABASE_URL` | Provided by Render Postgres (`render ea pg get --include-sensitive-connection-info`) | Yes |
| `SECRET_KEY_BASE` | `openssl rand -base64 64` | Yes |
| `SESSION_SIGNING_SALT` | `openssl rand -base64 32` | Yes |
| `SESSION_ENCRYPTION_SALT` | `openssl rand -base64 32` | Yes |
| `LIVE_VIEW_SIGNING_SALT` | `openssl rand -base64 32` | Yes |
| `PHX_HOST` | Your onrender.com domain (e.g. `zeval-engine.onrender.com`) | Yes |
| `SEED_ADMIN_EMAIL` | Admin dashboard email | Optional |
| `SEED_ADMIN_PASSWORD` | Admin dashboard password | Optional |
| `LOG_LEVEL` | `info`, `debug`, `warn`, `error` | No (default: `info`) |
| `POOL_SIZE` | Ecto connection pool size | No (default: `10`) |
| `DATABASE_SSL` | `true` or `false` | No (default: `false` for internal, `true` for external) |
| `METRICS_TOKEN` | Bearer token for `/metrics` | No (disabled if unset) |

## Inspecting

```bash
# Stream logs
render logs srv-<service-id>

# List deploys
render deploys list srv-<service-id>

# Open a psql session to the database
render psql zeval-db

# SSH into a running instance
render ssh srv-<service-id>

# Restart the service
render restart srv-<service-id>
```

## Updating the blueprint

Edit `render.yaml` and push to `main`. Then from the Dashboard, go to your
Blueprint → **Sync** to apply changes. To re-validate locally first:

```bash
render blueprints validate render.yaml
```

## Scaling

From the Render Dashboard, select your service → **Settings** → **Plan** to
change the instance size and number of instances. Render also supports
[autoscaling](https://render.com/docs/blueprint-spec#autoscaling) via the
blueprint.

## Troubleshooting

### Build fails
Check the build logs in the Render Dashboard. Common issues:
- Elixir/OTP version mismatch — verify the Dockerfile base image is correct
- Depedency resolution failure — check `mix.lock` is committed
- Insufficient memory on the free plan — upgrade to a paid plan

### Crashing at startup
Stream logs to see the error:
```bash
render logs srv-<service-id>
```

The most common cause is a database connection failure. Verify `DATABASE_URL` is
correct and accessible from Render's network.

### Health check failing
The app must listen on `0.0.0.0:4000` (or whatever `ENGINE_PORT` is set to).
Verify the health check path matches the Dockerfile's `HEALTHCHECK` instruction
(`/health`). Check logs for application-level errors.

### Migration rollback
```bash
render ssh srv-<service-id> --command \
  "bin/zeval_engine eval \"ZevalCore.Release.rollback(ZevalCore.Repo, 0)\""
```
