

## Zeval Engine — Usage Guide

### 1. Start the server

```bash
cd ~/repos/zeval_engine
docker compose up -d db       # PostgreSQL on :5432
mix phx.server                # API on :4000
```

### 2. Create a tenant (no auth required)

```bash
curl -s -X POST http://localhost:4000/api/v1/tenants \
  -H "Content-Type: application/json" \
  -d '{"name":"my-org"}'
```

Returns:
```json
{"tenant":{"id":"03f00a3f-...","name":"my-org"}}
```

### 3. Create an API key (no auth required, needs tenant_id)

```bash
curl -s -X POST http://localhost:4000/api/v1/service-accounts \
  -H "Content-Type: application/json" \
  -d '{"name":"default-key","tenant_id":"<PASTE_TENANT_ID_HERE>"}'
```

Returns the `raw_key` once — **save it**:
```json
{"service_account":{"id":"...","name":"default-key","key_prefix":"perm_dev_d4","raw_key":"perm_dev_abc123..."}}
```

All subsequent calls use this key:
```bash
KEY="perm_dev_abc123..."
AUTH="Authorization: Bearer $KEY"
```

### 4. Define a namespace config

A namespace config defines which relations exist and how they resolve:

```bash
curl -s -X POST http://localhost:4000/api/v1/namespaces \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "name": "doc",
    "relations": {
      "owner": {"this": {}},
      "editor": {
        "union": [
          {"this": {}},
          {"computed_userset": {"relation": "owner"}}
        ]
      },
      "viewer": {
        "union": [
          {"this": {}},
          {"computed_userset": {"relation": "editor"}},
          {"tuple_to_userset": {
            "tupleset_relation": "parent",
            "computed_userset_relation": "viewer"
          }}
        ]
      }
    }
  }'
```

**Relation types:**
- `{"this": {}}` — direct tuple lookup
- `{"computed_userset": {"relation": "editor"}}` — inherit from another relation
- `{"union": [A, B]}` — allow if A OR B allows
- `{"intersection": [A, B]}` — allow if A AND B allow
- `{"exclusion": {"base": A, "subtract": B}}` — allow if A AND NOT B
- `{"tuple_to_userset": {"tupleset_relation": "parent", "computed_userset_relation": "viewer"}}` — delegate to parent object

### 5. Write relation tuples

Shorthand form (one per JSON object):

```bash
curl -s -X POST http://localhost:4000/api/v1/tuples \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "tuples": [
      {"shorthand": "doc:readme#owner@alice"},
      {"shorthand": "doc:readme#viewer@bob"},
      {"shorthand": "doc:readme#parent@folder:eng#viewer"},
      {"shorthand": "folder:eng#viewer@carol"}
    ]
  }'
```

Expanded form:
```json
{"tuples": [
  {"namespace":"doc","object_id":"readme","relation":"owner","subject":"alice"},
  {"namespace":"doc","object_id":"readme","relation":"parent",
   "subject":{"type":"userset","namespace":"folder","object_id":"eng","relation":"viewer"}}
]}
```

Returns:
```json
{"written": 4, "zookie": "zookie:abc-..."}
```

### 6. Read relation tuples

```bash
curl -s -X POST http://localhost:4000/api/v1/tuples/read \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"readme"}'
```

### 7. Check access

```bash
curl -s -X POST http://localhost:4000/api/v1/check \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "namespace": "doc",
    "object_id": "readme",
    "relation": "viewer",
    "subject": "alice"
  }'
```

Returns the resolution path:
```json
{
  "allowed": true,
  "resolution_path": [
    {"rule":"union","relation":"viewer","allowed":true,"children":[...]},
    {"rule":"computed_userset","relation":"editor","allowed":true,"children":[...]},
    {"rule":"this","relation":"owner","allowed":true}
  ]
}
```

### 8. Expand (who has access?)

```bash
curl -s -X POST http://localhost:4000/api/v1/tuples/expand \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"readme","relation":"viewer"}'
```

Returns a tree with all users:
```json
{"tree": {
  "relation":"viewer","type":"union","users":["alice","bob","carol"],"children":[...]
}}
```

### 9. Consistency tokens (zookies)

Pass a `zookie` to read as-of a point in time:

```bash
# Get a zookie from a write
WRITE_RESULT=$(curl -s -X POST http://localhost:4000/api/v1/tuples \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"tuples":[{"shorthand":"doc:x#viewer@alice"}]}')
ZOOKIE=$(echo $WRITE_RESULT | grep -o '"zookie":"[^"]*"' | cut -d'"' -f4)

# Read with that zookie — sees tuples that existed at that snapshot
curl -s -X POST http://localhost:4000/api/v1/tuples/read \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"namespace\":\"doc\",\"object_id\":\"x\",\"zookie\":\"$ZOOKIE\"}"
```

### Full example: 3-level hierarchy

```bash
# 1. Define namespace configs
curl -s -X POST .../namespaces -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name":"group","relations":{"member":{"this":{}}}}'
curl -s -X POST .../namespaces -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name":"folder","relations":{"viewer":{"tuple_to_userset":{"tupleset_relation":"parent","computed_userset_relation":"member"}}}}'
curl -s -X POST .../namespaces -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name":"doc","relations":{"viewer":{"tuple_to_userset":{"tupleset_relation":"parent","computed_userset_relation":"viewer"}}}}'

# 2. Write tuples: alice → group:eng → folder:project → doc:readme
curl -s -X POST .../tuples -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"tuples":[
    {"shorthand":"group:eng#member@alice"},
    {"shorthand":"folder:project#parent@group:eng#member"},
    {"shorthand":"doc:readme#parent@folder:project#viewer"}
  ]}'

# 3. Check: can alice view doc:readme?
curl -s -X POST .../check -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"}'
# => {"allowed":true,...}
```
