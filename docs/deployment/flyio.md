# Fly.io Deployment

## Prerequisites

- [flyctl](https://fly.io/docs/hands-on/install-flyctl/) installed and logged in (`flyctl auth login`)
- Dockerfile and `fly.toml` at project root (already committed)

## One-time setup

```bash
# 1. Create the app
flyctl apps create zeval-engine

# 2. Create a Postgres cluster (skip if re-attaching to an existing cluster)
flyctl postgres create --name zeval-engine-db \
  --region ord \
  --initial-cluster-size 1 \
  --vm-size shared-cpu-1x \
  --volume-size 10

# 3. Attach the database to the app
flyctl postgres attach zeval-engine-db --app zeval-engine

# 4. Generate and set secrets
SECRET_KEY_BASE=$(mix phx.gen.secret)
SESSION_SIGNING_SALT=$(openssl rand -hex 16)
SESSION_ENCRYPTION_SALT=$(openssl rand -hex 16)
LIVE_VIEW_SIGNING_SALT=$(openssl rand -hex 16)

flyctl secrets set \
  SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  SESSION_SIGNING_SALT="$SESSION_SIGNING_SALT" \
  SESSION_ENCRYPTION_SALT="$SESSION_ENCRYPTION_SALT" \
  LIVE_VIEW_SIGNING_SALT="$LIVE_VIEW_SIGNING_SALT" \
  PHX_HOST="zeval-engine.fly.dev" \
  SEED_ADMIN_EMAIL="admin@zeval.local" \
  SEED_ADMIN_PASSWORD="changethis123" \
  LOG_LEVEL="info" \
  --app zeval-engine

# 5. Allocate a dedicated IPv4 for the database
#    (Erlang's inet module cannot resolve Fly.io private .internal / .flycast DNS)
flyctl ips allocate-v4 --app zeval-engine-db

# 6. Update DATABASE_URL with the database's public IPv4
#    Get the IP from: flyctl ips list --app zeval-engine-db
DATABASE_IP="<ip-from-step-5>"
flyctl secrets set \
  DATABASE_URL="postgres://zeval_engine:<password>@$DATABASE_IP:5432/zeval_engine?sslmode=disable" \
  --app zeval-engine
```

> **Note on `DATABASE_URL`:** Fly.io's private DNS (`.internal`, `.flycast`) does not resolve
> inside the Erlang VM. The connection must use either the database's public IPv4 address
> (as above) or an `/etc/hosts` entry baked into the Dockerfile.

## Deploy

```bash
flyctl deploy --app zeval-engine
```

This will:
1. Build the Docker image using the project Dockerfile (multi-stage Elixir release)
2. Push it to Fly.io's registry
3. Roll out a rolling update to all app machines (2 by default)
4. Run migrations via `bin/zeval_engine eval "ZevalCore.Release.migrate()"`
5. Start the Phoenix server

## Secrets reference

| Secret | Source | Required |
|---|---|---|
| `DATABASE_URL` | Set by `flyctl postgres attach`, then overridden with public IPv4 | Yes |
| `SECRET_KEY_BASE` | `mix phx.gen.secret` | Yes |
| `SESSION_SIGNING_SALT` | `openssl rand -hex 16` | Yes |
| `SESSION_ENCRYPTION_SALT` | `openssl rand -hex 16` | Yes |
| `LIVE_VIEW_SIGNING_SALT` | `openssl rand -hex 16` | Yes |
| `PHX_HOST` | Your fly.dev domain (e.g. `zeval-engine.fly.dev`) | Yes |
| `SEED_ADMIN_EMAIL` | Admin dashboard email | Optional |
| `SEED_ADMIN_PASSWORD` | Admin dashboard password | Optional |
| `LOG_LEVEL` | `info`, `debug`, `warn`, `error` | No (default: `info`) |
| `POOL_SIZE` | Ecto connection pool size | No (default: `10`) |
| `DATABASE_SSL` | `true` or `false` | No (default: `false`) |
| `METRICS_TOKEN` | Bearer token for `/metrics` | No (disabled if unset) |

## Inspecting

```bash
# Stream logs
flyctl logs --app zeval-engine

# Open a remote console
flyctl ssh console --app zeval-engine

# Run a one-shot eval (e.g. migrations)
flyctl ssh console --app zeval-engine --command \
  "bin/zeval_engine eval \"ZevalCore.Release.migrate()\""

# Check machine status
flyctl machine list --app zeval-engine
```

## Scaling

Edit `fly.toml`:

```toml
[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 1024
```

Then deploy again.

To change the number of machines, update `min_machines_running` in the `[http_service]` section.

## Troubleshooting

### App not listening on 0.0.0.0:4000
Check logs (`flyctl logs`). The most common cause is the app failing to connect to the
database. Verify `DATABASE_URL` is reachable from within the Fly.io network.

### DNS / nxdomain errors
If you see `tcp connect (...): non-existing domain - :nxdomain`, the Erlang VM cannot
resolve the database hostname. The fix is to use a raw IPv4 address (see step 5-6 above)
or to configure Erlang's inet module via `ERL_INET6=true` (works on OTP < 27 only).

### Database not found / migration fails
The `flyctl postgres attach` command creates a database and user automatically. If you
need to create them manually:

```bash
flyctl ssh console --app zeval-engine-db --command \
  "psql -U postgres -c \"CREATE DATABASE zeval_engine;\""
```

### Rolling back a migration
```bash
flyctl ssh console --app zeval-engine --command \
  "bin/zeval_engine eval \"ZevalCore.Release.rollback(ZevalCore.Repo, 0)\""
```
