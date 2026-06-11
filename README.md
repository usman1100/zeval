# Zeval Engine

A **Google Zanzibar-inspired authorization engine** exposed as a REST API.
Built with Elixir/Phoenix and PostgreSQL.

Zeval answers one question: **does subject X have relation Y on object Z?**
It does this by resolving a graph of namespace configs (rewrite rules) and
relation tuples (data) — the same model Zanzibar uses at Google scale.

## Quick start

```bash
docker compose up --build -d
```

This starts PostgreSQL and the engine on `http://localhost:4000`.

### First request

```bash
# 1. Create a tenant
curl -s -X POST http://localhost:4000/api/v1/tenants \
  -H "Content-Type: application/json" \
  -d '{"name":"my-org"}'

# Save the tenant ID — you'll need it below

# 2. Create an API key
curl -s -X POST http://localhost:4000/api/v1/service-accounts \
  -H "Content-Type: application/json" \
  -d '{"name":"my-key","tenant_id":"<TENANT_ID>"}'

# Save the raw_key — shown once, never again
KEY="perm_dev_abc123..."
AUTH=*** Bearer $KEY"

# 3. Define a namespace
curl -X POST http://localhost:4000/api/v1/namespaces \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "name": "doc",
    "relations": {
      "viewer": {"this": {}},
      "editor": {"this": {}},
      "owner": {"this": {}}
    }
  }'

# 4. Write tuples
curl -X POST http://localhost:4000/api/v1/tuples \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"tuples":[
    {"shorthand":"doc:readme#viewer@alice"},
    {"shorthand":"doc:readme#owner@bob"}
  ]}'

# 5. Check access
curl -X POST http://localhost:4000/api/v1/check \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"}'
# => {"allowed":true,"resolution_path":[...]}
```

## How it works

### The model

Every authorization decision is a **relation tuple**:

```
doc:readme#viewer@alice
```

This says: **alice is a viewer of doc:readme**

The format is `namespace:object_id#relation@subject`. Subjects can be:

- **Direct users**: `alice`, `bob@example.com`
- **Usersets**: `group:eng#member` (all members of group:eng)

Namespaces define how relations resolve through **rewrite rules**:

| Rule | Meaning |
|------|---------|
| `{"this": {}}` | Direct tuple lookup |
| `{"computed_userset": {"relation": "editor"}}` | Inherit from another relation on the same object |
| `{"tuple_to_userset": {"tupleset_relation": "parent", "computed_userset_relation": "viewer"}}` | Delegate to a parent object |
| `{"union": [A, B]}` | Allow if A OR B allows |
| `{"intersection": [A, B]}` | Allow if A AND B allow |
| `{"exclusion": {"base": A, "subtract": B}}` | Allow if A AND NOT B |

### Resolution (simple)

Given `doc:readme#viewer@alice`, the engine:

1. Loads the `doc` namespace config
2. Looks up the `viewer` rewrite rule
3. If `this` — queries `relation_tuples` for `doc:readme#viewer@alice`
4. Returns `allowed: true/false` with a full resolution path

### Resolution (3-level hierarchy)

```
User alice → group:eng (member) → folder:project (viewer) → doc:readme (viewer)
```

1. `check(doc:readme, viewer, alice)` → doc's viewer is `tuple_to_userset(parent, viewer)`
2. Finds tuple `doc:readme#parent@folder:project#viewer` → check `folder:project#viewer@alice`
3. folder's viewer is `tuple_to_userset(parent, member)` → checks `group:eng#member@alice`
4. group's member is `this` → tuple exists → **allowed: true**

### Consistency tokens (zookies)

Every write returns a **zookie** — a consistent snapshot timestamp. Pass it to
read endpoints to guarantee read-your-writes consistency:

```bash
WRITE=$(curl -s -X POST .../tuples -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"tuples":[{"shorthand":"doc:x#viewer@alice"}]}')
ZOOKIE=$(echo $WRITE | grep -o '"zookie":"[^"]*"' | cut -d'"' -f4)

curl -X POST .../tuples/read -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"namespace\":\"doc\",\"object_id\":\"x\",\"zookie\":\"$ZOOKIE\"}"
```

## API reference

All endpoints live under `/api/v1`. Authenticated endpoints require:

```
Authorization: Bearer <raw_key>
```

### Tenants

**POST /tenants** (no auth)

```json
{"name": "my-org"}
→ 201 {"tenant": {"id": "uuid", "name": "my-org"}}
```

### Service accounts

**POST /service-accounts** (no auth, needs tenant_id)

```json
{"name": "my-key", "tenant_id": "<uuid>"}
→ 201 {"service_account": {"id": "...", "name": "...", "raw_key": "perm_dev_...", "key_prefix": "perm_dev"}}
```

**DELETE /service-accounts/:id**

```json
→ 200 {"revoked": true}
```

### Namespaces

**POST /namespaces** (auth)

```json
{"name": "doc", "relations": {"viewer": {"this": {}}}}
→ 200 {"namespace": {"name": "doc", "version": 1}}
```

**GET /namespaces**

```json
→ 200 {"namespaces": [{"name": "doc", "version": 1}]}
```

**GET /namespaces/:name**

```json
→ 200 {"namespace": {"name": "doc", "relations": {...}}}
```

**DELETE /namespaces/:name**

```json
→ 200 {"deleted": true}
```

### Tuples

**POST /tuples** (auth, limit: 500 per request)

```json
{"tuples": [
  {"shorthand": "doc:readme#viewer@alice"},
  {"shorthand": "doc:readme#parent@folder:eng#viewer"}
]}
→ 200 {"written": 2, "zookie": "zookie:uuid"}
```

Also accepts expanded form:

```json
{"tuples": [
  {"namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"},
  {"namespace":"doc","object_id":"readme","relation":"parent",
   "subject":{"type":"userset","namespace":"folder","object_id":"eng","relation":"viewer"}}
]}
```

**DELETE /tuples** (auth, soft-delete)

Same body as write. Returns `{"deleted": N, "zookie": "..."}`.

**POST /tuples/read** (auth)

```json
{"namespace": "doc", "object_id": "readme"}
→ {"tuples": [...], "zookie": null}
```

Optional `"zookie": "..."` for point-in-time reads.

**POST /tuples/expand** (auth)

```json
{"namespace": "doc", "object_id": "readme", "relation": "viewer"}
→ {"tree": {"relation":"viewer","type":"union","users":["alice","bob"],"children":[...]}}
```

### Check

**POST /check** (auth, rate limit: 1000/min)

```json
{"namespace": "doc", "object_id": "readme", "relation": "viewer", "subject": "alice"}
→ {
    "allowed": true,
    "resolution_path": [
      {"rule":"union","relation":"viewer","allowed":true,"children":[
        {"rule":"this","allowed":false},
        {"rule":"computed_userset","relation":"editor","allowed":true}
      ]}
    ]
  }
```

### Metrics

**GET /metrics** (no auth)

Returns Prometheus text format at `/metrics`.

### Watch

**GET /watch?namespace=doc** (auth, SSE)

Streams newline-delimited JSON events for tuple changes.

## Performance

- **Index design**: `idx_tuples_lookup` on `(tenant_id, namespace, object_id, relation)` covers the primary access pattern. `idx_tuples_subject` covers tuple_to_userset resolutions. Both are partial indexes (filter to active tuples only).
- **ETS cache**: Namespace configs are cached in an ETS table. Reads hit the cache on the second call — 0 DB queries for hot configs.
- **Concurrency**: Tuple_to_userset resolution iterates parent tuples using `Enum.reduce_while` for short-circuiting on the first match.
- **Rate limiting**: Three tiers protect the API — `/check` (1000 req/min), `/tuples` writes (500 req/min), general (200 req/min).

## Configuration

| Env var | Default | Description |
|---------|---------|-------------|
| `DATABASE_URL` | (required) | Postgres connection string |
| `SECRET_KEY_BASE` | (required) | Phoenix signing key (64+ chars) |
| `ENGINE_PORT` | `4000` | HTTP port |
| `LOG_LEVEL` | `info` | debug, info, warning, error |
| `POOL_SIZE` | `10` | Ecto connection pool size |

## Development

```bash
# Start DB only
docker compose up -d db

# Start Phoenix
mix phx.server

# Run tests
mix test

# Reset DB
mix ecto.reset
```
