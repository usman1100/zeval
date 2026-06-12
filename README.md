# Zeval Engine

A **Google Zanzibar-inspired authorization engine** with a REST API and a web
dashboard, built in Elixir/Phoenix (LiveView) on PostgreSQL.

Zeval answers one question, fast and consistently:

> **Does subject _X_ have relation _Y_ on object _Z_?**

e.g. *"Can `alice` `view` `doc:readme`?"*

Instead of scattering `if user.admin? or user.id == doc.owner_id` checks across
your app, you model permissions as a graph of **relation tuples** (facts like
"alice is an owner of doc:readme") and **namespace configs** (rules like
"viewers are anyone who is an owner, or a viewer of the parent folder"). Zeval
walks that graph and returns a yes/no plus a full explanation of how it decided.
This is the relationship-based access control (ReBAC) model Google uses for
Drive, Calendar, and Cloud IAM at scale.

> 📖 **New here?** The [Examples & Recipes guide](docs/examples.md) walks through
> real scenarios — role hierarchies, groups, folder inheritance,
> intersection/exclusion — with runnable `curl` commands.

---

## Table of contents

- [Why ReBAC](#why-rebac)
- [Core concepts & entities](#core-concepts--entities)
- [How authorization resolution works](#how-authorization-resolution-works)
- [Architecture](#architecture)
- [Getting started (development)](#getting-started-development)
- [Using the dashboard](#using-the-dashboard)
- [Using the REST API](#using-the-rest-api)
- [Examples & recipes](docs/examples.md)
- [REST API reference](#rest-api-reference)
- [Configuration](#configuration)
- [Security model](#security-model)
- [Project layout](#project-layout)
- [Development workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)

---

## Why ReBAC

Most apps start with role checks (`admin`, `editor`) and end up with a tangle of
special cases: "owners can share", "folder viewers inherit doc access", "billing
admins but not in the EU tenant", and so on. ReBAC reframes every one of those as
a **relationship**:

```
doc:readme#viewer@alice               alice is a viewer of doc:readme
doc:readme#parent@folder:eng          doc:readme's parent is folder:eng
folder:eng#viewer@group:eng#member    members of group:eng can view folder:eng
```

You declare, once per object type, *how* a relation is computed (directly, by
inheriting another relation, by walking to a parent, by union/intersection/
exclusion of other rules). Then every authorization check is a graph traversal
over the stored relationships — no bespoke logic in your application code.

---

## Core concepts & entities

Zeval is **multi-tenant**: every piece of authorization data belongs to a
tenant, and tenants are fully isolated from each other. The entities below form
two layers — the **control plane** (who administers Zeval) and the
**data plane** (the authorization data itself).

```
                    ┌──────────────────┐
                    │  dashboard_users │   humans who log into the web UI
                    └────────┬─────────┘
                             │   tenant_memberships (user ⇄ tenant, role)
                             ▼
                    ┌──────────────────┐
                    │     tenants      │   the isolation boundary
                    └────────┬─────────┘
        ┌───────────────────┼────────────────────┬───────────────┐
        ▼                   ▼                     ▼               ▼
┌─────────────────┐ ┌──────────────────┐ ┌─────────────────┐ ┌──────────┐
│ service_accounts│ │ namespace_configs│ │ relation_tuples │ │ zookies  │
│  (API keys)     │ │ (rewrite rules)  │ │ (the facts)     │ │(consist.)│
└─────────────────┘ └──────────────────┘ └─────────────────┘ └──────────┘
```

Everything under a tenant is removed with it (`ON DELETE CASCADE`).

### Tenant

The top-level isolation unit — think "organization" or "customer". A tenant owns
its own namespaces, relation tuples, and API keys. One Zeval deployment serves
many tenants, and no query ever crosses tenant boundaries.

- Fields: `id` (UUID), `name` (unique), `inserted_at`.

### Dashboard user

A human administrator who signs into the web dashboard with email + password
(bcrypt-hashed; emails are case-insensitive via `citext`). Dashboard users are
**not** the "subjects" your application authorizes — they're the operators who
configure Zeval.

- Fields: `id`, `email`, `name`, `password_hash`, `inserted_at`.

### Tenant membership

The join between a dashboard user and a tenant, with a `role`. This is the
dashboard's **authorization boundary**: a user only sees and manages tenants
they're a member of. Creating a tenant from the dashboard automatically makes
you its `owner`.

- Fields: `user_id → dashboard_users`, `tenant_id → tenants`, `role`
  (`owner` | `member`), unique on `(user_id, tenant_id)`.

### Service account (API key)

A machine credential your application uses to call the Zeval REST API. The key
looks like `perm_dev_<64 hex chars>`; only a **SHA-256 hash** is stored, and the
raw key is shown exactly once at creation. A request authenticates by sending
`Authorization: Bearer <raw_key>`, and Zeval derives the calling tenant from the
key — you never pass a tenant id in the request body.

- Fields: `id`, `tenant_id`, `name` (unique per active tenant), `key_hash`,
  `key_prefix` (first 12 chars, for display), `last_used_at`, `revoked_at`,
  `created_by`/`revoked_by` (audit), `inserted_at`.
- Revocation is a soft-delete (`revoked_at`) so audit history is preserved.

### Namespace config (the rules)

A namespace defines an **object type** (`doc`, `folder`, `group`, …) and, for
each relation on that type, a **rewrite rule** describing how the relation is
computed. Stored as JSON, validated structurally (including cycle detection)
before being accepted, and cached in ETS for fast reads. Namespaces are
versioned — each write bumps `version`.

```json
{
  "name": "doc",
  "relations": {
    "owner":  { "this": {} },
    "editor": { "union": [ { "this": {} }, { "computed_userset": { "relation": "owner" } } ] },
    "viewer": {
      "union": [
        { "this": {} },
        { "computed_userset": { "relation": "editor" } },
        { "tuple_to_userset": { "tupleset_relation": "parent", "computed_userset_relation": "viewer" } }
      ]
    }
  }
}
```

The six rule types are described in [resolution](#how-authorization-resolution-works).

- Fields: `id`, `tenant_id`, `name`, `config` (JSONB), `version`, unique on
  `(tenant_id, name)`.

### Relation tuple (the facts)

A single relationship: **subject** has **relation** on **object**. This is the
core data table. The shorthand notation is:

```
<namespace>:<object_id>#<relation>@<subject>
```

A **subject** is one of:

- a **user** — any opaque string (`alice`, `bob@example.com`, a UUID). The string
  is whatever your app uses to identify a principal.
- a **userset** — `namespace:object_id#relation`, meaning *every subject that has
  that relation on that object*. This is how groups and inheritance work, e.g.
  `group:eng#member` = "all members of group:eng".

Examples:

```
doc:readme#viewer@alice               alice directly views doc:readme
doc:readme#parent@folder:eng#...       doc:readme's parent is folder:eng
folder:eng#viewer@group:eng#member     group:eng members can view folder:eng
```

Tuples are **soft-deleted** (`deleted_at`) so point-in-time reads (see zookies)
can still see historical state. Writes are **idempotent** — re-writing the same
active tuple is a no-op.

- Fields: `id`, `tenant_id`, `namespace`, `object_id`, `relation`,
  `subject_type` (`user`|`userset`), `user_id` *or* (`userset_namespace`,
  `userset_object_id`, `userset_relation`), `inserted_at`, `deleted_at`.
- A DB CHECK constraint enforces that exactly one subject shape is populated.

### Zookie (consistency token)

A "**z**anzibar c**ookie**" — an opaque token representing a point-in-time
snapshot. Every write returns one. Pass it back to a read/check to get
**read-your-writes** consistency: "evaluate as of at least this moment". Zookies
are tenant-scoped (a token only resolves a snapshot for the tenant that minted
it). The snapshot timestamp comes from Postgres `NOW()` to avoid app/DB clock
drift.

- Fields: `token` (PK), `tenant_id`, `snapshot_at`.

---

## How authorization resolution works

Two engines operate over the same data:

| Engine  | Question | Returns |
|---------|----------|---------|
| **Check** (`ZevalCore.Check`) | Does *this specific subject* have the relation? | `{allowed: bool, path: [...]}` |
| **Expand** (`ZevalCore.Expand`) | *Who* has the relation on this object? | a tree of subjects mirroring the rules |

Both recursively evaluate the namespace's rewrite rules against the tuple store.

### Rewrite rule types

| Rule | Meaning | Shape |
|------|---------|-------|
| `this` | A tuple exists directly (`object#relation@subject`). | `{"this": {}}` |
| `computed_userset` | Inherit from another relation on the **same** object. | `{"computed_userset": {"relation": "owner"}}` |
| `tuple_to_userset` | Walk to a related object (e.g. a parent) and check a relation there. | `{"tuple_to_userset": {"tupleset_relation": "parent", "computed_userset_relation": "viewer"}}` |
| `union` | Allowed if **any** child rule allows. | `{"union": [A, B, …]}` |
| `intersection` | Allowed only if **all** child rules allow. | `{"intersection": [A, B, …]}` |
| `exclusion` | Allowed if `base` allows **and** `subtract` does not. | `{"exclusion": {"base": A, "subtract": B}}` |

Empty `union`/`intersection` lists are rejected at validation time (an empty
intersection would otherwise vacuously allow everyone).

### Worked example — folder inheritance

Config:

```json
{ "name": "doc",    "relations": {
    "viewer": { "tuple_to_userset": { "tupleset_relation": "parent", "computed_userset_relation": "viewer" } },
    "parent": { "this": {} } } }
{ "name": "folder", "relations": { "viewer": { "this": {} } } }
```

Facts:

```
doc:readme#parent@folder:root#...     doc:readme lives in folder:root
folder:root#viewer@alice              alice can view folder:root
```

`check(doc, readme, viewer, alice)`:

1. `doc`'s `viewer` rule is `tuple_to_userset(parent → viewer)`.
2. Find `doc:readme#parent@…` → `folder:root`. Recurse: `check(folder, root, viewer, alice)`.
3. `folder`'s `viewer` rule is `this` → tuple `folder:root#viewer@alice` exists → **allowed**.

The result includes the full **resolution path** (each step with its
allow/deny), which the dashboard renders as a tree for debugging.

### Safety guards

- **Cycle detection** at config-write time rejects circular `computed_userset`
  chains; a runtime visited-set also guards check/expand.
- **Max recursion depth** of 25 prevents pathological configs from looping.
- **Per-request read memoization** collapses repeated tuple lookups within a
  single check.

---

## Architecture

An **Elixir umbrella** with two apps:

```
zeval_engine/
├── apps/
│   ├── zeval_core/     # Domain logic + data. No web deps.
│   │   ├── lib/zeval_core/
│   │   │   ├── check.ex / expand.ex        # the engines
│   │   │   ├── namespace.ex + namespace/   # configs, validator, ETS cache
│   │   │   ├── tuples.ex + tuples/         # tuple CRUD, parser, zookies
│   │   │   ├── tenants.ex / memberships.ex # tenants + dashboard authz
│   │   │   ├── service_accounts.ex         # API keys
│   │   │   └── dashboard_users.ex          # admin accounts
│   │   └── priv/repo/migrations/
│   └── zeval_web/      # REST API + LiveView dashboard
│       └── lib/zeval_web/
│           ├── controllers/   # JSON API
│           ├── live/          # dashboard LiveViews + on_mount auth
│           ├── plugs/         # ServiceAuth, DashboardAuth, RateLimit, …
│           ├── layouts.ex     # root + app layouts
│           └── router.ex
├── config/            # config.exs, dev/test/prod, runtime.exs
├── docker-compose.yml # Postgres + engine (dev)
└── Dockerfile         # production release
```

`zeval_core` has no web dependencies — it could be driven from a CLI or another
interface. `zeval_web` exposes two surfaces on the same port:

| Surface | Path | Auth |
|---------|------|------|
| REST API | `/api/v1/*` | API key (`Authorization: Bearer …`) |
| Dashboard | `/dashboard/*` | Session cookie (email/password) |

---

## Getting started (development)

### Prerequisites

- **Elixir 1.19+** on **Erlang/OTP 28+**
- **PostgreSQL 16+** (the `pgcrypto` and `citext` extensions are enabled by
  migrations)
- **Docker** (optional, for running Postgres)

### 1. Clone and install

```bash
git clone <repo-url> zeval_engine
cd zeval_engine
mix deps.get
```

### 2. Start PostgreSQL

Using the bundled compose file (copy `.env.example` to `.env` first and set
`POSTGRES_PASSWORD`):

```bash
cp .env.example .env
docker compose up -d db
```

…or point `config/dev.exs` at any local Postgres (defaults: user `zeval`,
password `zeval`, db `zeval_dev`, localhost:5432).

### 3. Create and migrate the database

```bash
mix ecto.setup     # create + migrate (+ runs seeds.exs, which is a no-op
                   # unless SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD are set)
```

Lower-level equivalents: `mix ecto.create`, `mix ecto.migrate`.

### 4. Run the server

```bash
mix phx.server     # http://localhost:4000
```

### 5. Create your account

Open **http://localhost:4000/dashboard/signup** and create a dashboard user
(passwords must be ≥ 12 characters). There is **no default admin account**.

To seed one non-interactively instead:

```bash
SEED_ADMIN_EMAIL=you@example.com SEED_ADMIN_PASSWORD='a-long-passphrase' \
  mix run apps/zeval_core/priv/repo/seeds.exs
```

You're ready — use the dashboard or the REST API.

---

## Using the dashboard

The dashboard at `/dashboard/*` is a Phoenix LiveView app. After signing in you
only see tenants you belong to.

| Page | Purpose |
|------|---------|
| `/dashboard` | Overview + quick actions |
| `/dashboard/tenants` | List / create / delete your tenants |
| `/dashboard/tenants/:id` | A tenant's keys and namespaces |
| `/dashboard/api-keys` | Create (reveals raw key once) and revoke keys |
| `/dashboard/namespaces` | List, view JSON, edit, delete namespaces |
| `/dashboard/namespaces/new` | Build a namespace — **visual** rule editor or **raw JSON** |
| `/dashboard/namespaces/:id/edit` | Edit an existing namespace |
| `/dashboard/check` · `/expand` · `/tuples` | Interactive tools (in progress) |

**Typical first run:** create a tenant → create an API key for it (copy the raw
key immediately, it won't be shown again) → define a namespace → start writing
tuples and running checks.

The namespace editor's **visual mode** composes rewrite rules with type selectors
and nested child blocks for union/intersection/exclusion; **JSON mode** is a raw
editor with validate + save. You can switch modes without losing state.

---

## Using the REST API

**First, create a tenant and an API key from the dashboard** (this is the only
way to create a tenant — it makes you the owner). Sign in at `/dashboard`,
create a tenant, then on `/dashboard/api-keys` create a key and copy the raw
value (shown once). Everything below uses that key.

```bash
BASE=http://localhost:4000/api/v1
KEY="perm_dev_<paste-raw-key>"     # from /dashboard/api-keys
AUTH="Authorization: Bearer $KEY"

# (Optional) mint additional keys for the SAME tenant via the API — the tenant
# is taken from the calling key, never the request body:
curl -s -X POST $BASE/service-accounts -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name":"my-key"}'
# → {"service_account":{"id":"...","name":"my-key","key_prefix":"perm_dev_abc","raw_key":"perm_dev_<...>"}}

# 1. Define a namespace
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "doc",
  "relations": {
    "owner":  {"this": {}},
    "viewer": {"union": [{"this": {}}, {"computed_userset": {"relation": "owner"}}]}
  }
}'
# → {"namespace":{"name":"doc","version":1}}

# 2. Write tuples (shorthand or expanded form)
curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [
    {"shorthand": "doc:readme#owner@alice"},
    {"shorthand": "doc:readme#viewer@bob"}
  ]
}'
# → {"written":2,"zookie":"zookie:<uuid>"}

# 3. Check access  (alice is owner ⇒ viewer)
curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" -d '{
  "namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"
}'
# → {"allowed":true,"resolution_path":[...]}

# 4. Expand — who can view doc:readme?
curl -s -X POST $BASE/tuples/expand -H "$AUTH" -H "Content-Type: application/json" -d '{
  "namespace":"doc","object_id":"readme","relation":"viewer"
}'
# → {"tree":{"type":"union","users":["alice","bob"],...}}
```

> For deeper, scenario-based walkthroughs — role hierarchies, groups, folder
> inheritance, intersection/exclusion, zookies, watch, and a full "mini Drive"
> model — see **[docs/examples.md](docs/examples.md)**.

---

## REST API reference

Base path: `/api/v1`. Authenticated endpoints require
`Authorization: Bearer <raw_key>`. Errors are JSON:
`{"error": "...", "code": "..."}`.

### Tenants

There is **no tenant-creation API**. Tenants are created from the dashboard,
which makes the creator the owner — so a tenant always has an owner and a way to
mint its first API key. (Unmatched `/api/*` routes return a JSON 404.)

### Service accounts (auth)

| Method | Path | Notes |
|--------|------|-------|
| `POST` | `/service-accounts` | Creates a key for the **authenticated** tenant; body `tenant_id` is ignored. |
| `DELETE` | `/service-accounts/:id` | Only revokes keys in the caller's tenant; else 404. |

```jsonc
// POST /service-accounts  {"name": "my-key"}
//   → 201 {"service_account": {"id","name","key_prefix","raw_key"}}
// DELETE /service-accounts/:id → 200 {"revoked": true}
```

### Namespaces (auth)

| Method | Path | Notes |
|--------|------|-------|
| `POST` | `/namespaces` | Upsert (validates + bumps version). |
| `GET` | `/namespaces` | List `{name, version}` for the tenant. |
| `GET` | `/namespaces/:name` | Returns the full config JSON. |
| `DELETE` | `/namespaces/:name` | |

```jsonc
// POST /namespaces  {"name":"doc","relations":{...}}  → 200 {"namespace":{"name":"doc","version":1}}
// GET  /namespaces                                     → 200 {"namespaces":[{"name":"doc","version":1}]}
// GET  /namespaces/doc                                 → 200 {"namespace":{"name":"doc","relations":{...}}}
// DELETE /namespaces/doc                               → 200 {"deleted":true}
```

### Tuples (auth)

| Method | Path | Notes |
|--------|------|-------|
| `POST` | `/tuples` | Write. Max 500 tuples/request. Idempotent. |
| `DELETE` | `/tuples` | Soft-delete (same body as write). |
| `POST` | `/tuples/read` | Read with optional filter + `zookie`. Bounded (≤ 10000 rows). |
| `POST` | `/tuples/expand` | "Who has this relation?" tree. |

```jsonc
// POST /tuples — shorthand
{"tuples": [{"shorthand": "doc:readme#viewer@alice"}]}
// — or expanded form (lets you express userset subjects explicitly)
{"tuples": [
  {"namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"},
  {"namespace":"doc","object_id":"readme","relation":"parent",
   "subject":{"type":"userset","namespace":"folder","object_id":"eng","relation":"viewer"}}
]}
// → 200 {"written": N, "zookie": "zookie:..."}

// POST /tuples/read   {"namespace":"doc","object_id":"readme"[,"zookie":"..."]}
//   → {"tuples":[...],"zookie":...}
// POST /tuples/expand {"namespace":"doc","object_id":"readme","relation":"viewer"}
//   → {"tree":{"type":"union","users":[...],"children":[...]}}
```

### Check (auth)

```jsonc
// POST /check
{"namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"}
// subject may also be {"type":"userset","namespace":"group","object_id":"eng","relation":"member"}
// → {"allowed": true, "zookie": null,
//    "resolution_path": [ { "rule":"union", "allowed":true, "children":[...] } ]}
```

### Watch (auth, Server-Sent Events)

`GET /watch?namespace=doc` streams tuple-change events as SSE
(`data: {"event":"tuple.written",...}`) with periodic heartbeats. Omit
`namespace` to watch all.

### Health & metrics

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| `GET` | `/health` | none | Liveness — always `200 {"status":"ok"}`. |
| `GET` | `/ready` | none | Readiness — `200` only if the DB is reachable. |
| `GET` | `/metrics` | `METRICS_TOKEN` bearer | Prometheus text. Disabled (404) if token unset. |

### Rate limits

| Scope | Limit |
|-------|-------|
| `/check` | 1000 / min per key |
| `/tuples` write & delete | 500 / min per key |
| Other authenticated endpoints | 200 / min per key |
| `/dashboard/login`, `/signup` | 30 / min per IP |

> Rate-limit state is per-node (Hammer + ETS). In a multi-node deployment, move
> to a shared backend (e.g. Redis) if you need a global limit.

---

## Configuration

In **development** the database and ports come from `config/dev.exs`; the
`METRICS_TOKEN` is `dev-metrics-token`.

In **production** (`MIX_ENV=prod`) everything is read from the environment by
`config/runtime.exs`, and missing required secrets raise at boot. See
`.env.example`.

| Env var | Required (prod) | Description |
|---------|:---:|-------------|
| `DATABASE_URL` | ✓ | `postgres://…` connection string |
| `SECRET_KEY_BASE` | ✓ | Phoenix signing key (≥ 64 chars; `mix phx.gen.secret`) |
| `SESSION_SIGNING_SALT` | ✓ | Dashboard session cookie signing salt |
| `SESSION_ENCRYPTION_SALT` | ✓ | Dashboard session cookie encryption salt |
| `LIVE_VIEW_SIGNING_SALT` | ✓ | LiveView socket signing salt |
| `PHX_HOST` | | Public host; used for URL + `check_origin` (default `localhost`) |
| `DATABASE_SSL` | | `true` to require verified TLS to Postgres (default `false`) |
| `POOL_SIZE` | | DB pool size, 1–100 (default `10`) |
| `METRICS_TOKEN` | | Bearer for `GET /metrics`; endpoint disabled if unset |
| `EXTRA_ALLOWED_ORIGINS` | | Comma-separated extra websocket origins |
| `ENGINE_PORT` | | HTTP port (default `4000`) |
| `LOG_LEVEL` | | `debug` \| `info` \| `warning` \| `error` (default `info`) |

In production the endpoint enables `force_ssl` (HSTS), restricts `check_origin`
to `PHX_HOST`, and sets `secure` session cookies.

### Production build (Docker)

```bash
docker build -t zeval-engine .
# Provide the env vars above; the container runs migrations then starts,
# as a non-root user, with a /health HEALTHCHECK.
```

---

## Security model

- **API auth**: keys are SHA-256-hashed at rest; the tenant is always derived
  from the authenticated key, so one tenant's key can never touch another's
  data. Revocation is atomic and tenant-scoped.
- **Dashboard auth**: session-based with CSRF protection and secure headers; the
  LiveView socket re-verifies the user on every mount (`on_mount` hook), not just
  on the initial HTTP request. Tenant access is gated by membership.
- **Tenant isolation**: every data-plane query is scoped by `tenant_id`, and
  zookies are tenant-scoped so a token can't select a snapshot in another tenant.
- **Input validation**: tuple identifiers are format- and length-checked; rule
  configs are structurally validated with cycle detection.
- **Secrets**: never committed — all session/signing secrets are env-sourced in
  production and the app refuses to boot without them.

Tenant creation is **dashboard-only** (no public API), so every tenant has an
owner from the moment it exists.

---

## Project layout

See [Architecture](#architecture). Quick pointers:

- Engine logic: `apps/zeval_core/lib/zeval_core/{check,expand}.ex`
- Rule validation: `apps/zeval_core/lib/zeval_core/namespace/rule_validator.ex`
- Tuple parser (shorthand): `apps/zeval_core/lib/zeval_core/tuples/parser.ex`
- API routes: `apps/zeval_web/lib/zeval_web/router.ex`
- Auth plugs: `apps/zeval_web/lib/zeval_web/plugs/`
- Migrations: `apps/zeval_core/priv/repo/migrations/`

---

## Development workflow

```bash
# Tests (a local Postgres must be running; test DB is zeval_test)
mix test                         # everything
mix test apps/zeval_core/test    # engine only
mix test apps/zeval_web/test     # web only

# Quality tooling
mix format                       # format
mix credo --strict               # style / refactor suggestions
mix sobelow --root apps/zeval_web --skip   # security scan
mix dialyzer                     # type analysis (builds a PLT on first run)
mix coveralls                    # test coverage

# Database
mix ecto.migrate                 # apply pending migrations
mix ecto.rollback                # roll back the last migration
mix ecto.reset                   # drop, create, migrate, seed
```

CI (GitHub Actions, `.github/workflows/ci.yml`) runs formatting, compile
(warnings-as-errors), Credo, Sobelow, the test suite with coverage, and Dialyzer
on every push/PR.

---

## Troubleshooting

**The dashboard reloads in a loop / I get rate-limited immediately.** The
LiveView WebSocket can't establish a session, so the client keeps reloading. The
`/live` socket must be configured with
`connect_info: [session: {ZevalWeb.Plugs.Session, :options, []}]` in
`endpoint.ex` (it is, by default) and the session options must match the request
plug. If you change session config, keep both in sync.

**`mix phx.server` fails with `:eaddrinuse`.** Another process holds port 4000
(often a previous server). Find it with `lsof -ti :4000` and stop it.

**API calls return 401.** Check the `Authorization: Bearer <raw_key>` header and
that the key hasn't been revoked. The raw key is only shown once at creation.

**How do I create a tenant?** From the dashboard (`/dashboard/tenants`) — there
is no tenant-creation API. The creator becomes the owner, and from there you
create the tenant's first API key on `/dashboard/api-keys`.
