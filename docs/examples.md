# Zeval Engine — Examples & Recipes

A hands-on, scenario-driven guide to modeling real authorization problems with
Zeval. Every example is runnable with `curl`. For the conceptual model and the
full endpoint reference, see the [README](../README.md).

Each recipe follows the same shape: **the goal → the namespace (rules) → the
tuples (facts) → the checks**.

---

## Contents

- [0. Setup](#0-setup)
- [1. Direct permissions](#1-direct-permissions-this)
- [2. Role hierarchy](#2-role-hierarchy-computed_userset)
- [3. Groups](#3-groups-usersets)
- [4. Folder inheritance](#4-folder-inheritance-tuple_to_userset)
- [5. "Must be both" — intersection](#5-must-be-both--intersection)
- [6. "Everyone except" — exclusion](#6-everyone-except--exclusion)
- [7. Who has access? — expand](#7-who-has-access--expand)
- [8. Read-your-writes — zookies](#8-read-your-writes--zookies)
- [9. Revoking access](#9-revoking-access)
- [10. Watching for changes](#10-watching-for-changes-sse)
- [11. Putting it together — a mini Drive](#11-putting-it-together--a-mini-drive)
- [Tips & gotchas](#tips--gotchas)

---

## 0. Setup

Start the stack, then create a tenant and an API key **from the dashboard** —
that's the only way to create a tenant, and it makes you the owner.

```bash
# Terminal: start DB + server
docker compose up -d db
mix phx.server                     # http://localhost:4000
```

1. Open **http://localhost:4000/dashboard/signup** and create an account.
2. Go to **/dashboard/tenants** and create a tenant (you become its owner).
3. Go to **/dashboard/api-keys**, create a key for that tenant, and copy the raw
   key — it's shown only once.

Then export it for the commands below:

```bash
export KEY="perm_dev_<paste-raw-key>"
export AUTH="Authorization: Bearer $KEY"
export BASE=http://localhost:4000/api/v1
```

> All commands below assume `$AUTH` and `$BASE` are set. The tenant is derived
> from the key, so you never pass a tenant id. (Once you have one key, you can
> mint more for the same tenant with `POST $BASE/service-accounts`.)

---

## 1. Direct permissions (`this`)

**Goal:** a document type where access is granted directly to users.

**Namespace** — three independent relations, each a direct grant:

```bash
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "doc",
  "relations": {
    "owner":  {"this": {}},
    "editor": {"this": {}},
    "viewer": {"this": {}}
  }
}'
# → {"namespace":{"name":"doc","version":1}}
```

**Tuples** — grant alice owner, bob viewer of `doc:readme`:

```bash
curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [
    {"shorthand": "doc:readme#owner@alice"},
    {"shorthand": "doc:readme#viewer@bob"}
  ]
}'
# → {"written":2,"zookie":"zookie:..."}
```

**Checks:**

```bash
curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"readme","relation":"owner","subject":"alice"}'
# → {"allowed":true,...}

curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"}'
# → {"allowed":false,...}    # alice is owner, but viewer is a SEPARATE relation
```

Note that with plain `this` rules, being an `owner` does **not** make you a
`viewer`. The next recipe fixes that.

---

## 2. Role hierarchy (`computed_userset`)

**Goal:** owners are also editors, and editors are also viewers — a classic
permission ladder where higher roles subsume lower ones.

**Namespace** — each level unions its own direct grants with the level above:

```bash
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "doc",
  "relations": {
    "owner":  {"this": {}},
    "editor": {"union": [
      {"this": {}},
      {"computed_userset": {"relation": "owner"}}
    ]},
    "viewer": {"union": [
      {"this": {}},
      {"computed_userset": {"relation": "editor"}}
    ]}
  }
}'
```

**Tuples** — only grant the top role:

```bash
curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [{"shorthand": "doc:readme#owner@alice"}]
}'
```

**Checks** — one grant, three permissions:

```bash
for rel in owner editor viewer; do
  curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"namespace\":\"doc\",\"object_id\":\"readme\",\"relation\":\"$rel\",\"subject\":\"alice\"}" \
    | grep -o '"allowed":[a-z]*'
done
# → "allowed":true   (owner)
# → "allowed":true   (editor — via computed_userset → owner)
# → "allowed":true   (viewer — via computed_userset → editor → owner)
```

`computed_userset` resolves _on the same object_. The `resolution_path` in the
check response shows the chain it walked.

---

## 3. Groups (usersets)

**Goal:** grant access to a whole group instead of listing every user. This is
the **userset** subject in action.

**Namespaces** — a `group` type with `member`, and a `doc` that grants `viewer`:

```bash
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "group", "relations": {"member": {"this": {}}}
}'
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "doc", "relations": {"viewer": {"this": {}}}
}'
```

**Tuples** — put carol in the group, then grant the _group_ viewer access:

```bash
curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [
    {"shorthand": "group:eng#member@carol"},
    {"shorthand": "doc:spec#viewer@group:eng#member"}
  ]
}'
```

The second tuple's subject is the **userset** `group:eng#member` — "everyone who
is a member of group:eng".

**Check** — carol can view `doc:spec` even though she was never granted it
directly:

```bash
curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"spec","relation":"viewer","subject":"carol"}'
# → {"allowed":true,...}
```

Add or remove `group:eng#member@<user>` tuples to manage access for everyone at
once.

---

## 4. Folder inheritance (`tuple_to_userset`)

**Goal:** documents inherit viewers from the folder they live in — the
hierarchical pattern at the heart of Drive-like products.

**Namespaces:**

```bash
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "folder", "relations": {"viewer": {"this": {}}}
}'
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "doc",
  "relations": {
    "parent": {"this": {}},
    "viewer": {"union": [
      {"this": {}},
      {"tuple_to_userset": {"tupleset_relation": "parent", "computed_userset_relation": "viewer"}}
    ]}
  }
}'
```

`tuple_to_userset` means: _find the objects this doc is linked to via `parent`,
then check `viewer` on each of them._

**Tuples** — place the doc in a folder, grant the folder to dave:

```bash
curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [
    {"shorthand": "doc:roadmap#parent@folder:product#..."},
    {"shorthand": "folder:product#viewer@dave"}
  ]
}'
```

> The `#...` relation on the parent tuple is a conventional placeholder — for
> `tuple_to_userset`, Zeval reads the parent **object** (`folder:product`) from
> the tuple and ignores the subject relation. Any relation name works there.

**Check** — dave can view the doc through the folder:

```bash
curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"roadmap","relation":"viewer","subject":"dave"}'
# → {"allowed":true,...}
```

Move the doc to another folder (delete the old `parent` tuple, write a new one)
and its inherited access follows automatically.

---

## 5. "Must be both" — intersection

**Goal:** you may view a sensitive doc only if you are **both** an employee
**and** assigned to the project.

```bash
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "doc",
  "relations": {
    "employee": {"this": {}},
    "on_project": {"this": {}},
    "viewer": {"intersection": [
      {"computed_userset": {"relation": "employee"}},
      {"computed_userset": {"relation": "on_project"}}
    ]}
  }
}'

curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [
    {"shorthand": "doc:secret#employee@erin"},
    {"shorthand": "doc:secret#employee@frank"},
    {"shorthand": "doc:secret#on_project@erin"}
  ]
}'
```

```bash
# erin: employee AND on_project → allowed
curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"secret","relation":"viewer","subject":"erin"}'
# → {"allowed":true,...}

# frank: employee but NOT on_project → denied
curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"secret","relation":"viewer","subject":"frank"}'
# → {"allowed":false,...}
```

---

## 6. "Everyone except" — exclusion

**Goal:** all members can view, except anyone explicitly banned.

```bash
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "channel",
  "relations": {
    "member": {"this": {}},
    "banned": {"this": {}},
    "viewer": {"exclusion": {
      "base":     {"computed_userset": {"relation": "member"}},
      "subtract": {"computed_userset": {"relation": "banned"}}
    }}
  }
}'

curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [
    {"shorthand": "channel:general#member@grace"},
    {"shorthand": "channel:general#member@heidi"},
    {"shorthand": "channel:general#banned@heidi"}
  ]
}'
```

```bash
# grace: member, not banned → allowed
# heidi: member but banned    → denied
```

---

## 7. Who has access? — expand

**Goal:** list _everyone_ who can view an object (the inverse of check). Uses the
namespace from [recipe 2](#2-role-hierarchy-computed_userset).

```bash
curl -s -X POST $BASE/tuples/expand -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"namespace":"doc","object_id":"readme","relation":"viewer"}'
```

```jsonc
{
  "tree": {
    "relation": "viewer",
    "object": "doc:readme",
    "type": "union",
    "users": ["alice"], // flattened set of everyone who qualifies
    "children": [
      /* a subtree per branch, mirroring the rewrite rules */
    ],
  },
}
```

`users` is the de-duplicated set of direct user subjects who hold the relation.
`children` mirrors the rule structure so you can see _why_ each user is included.

---

## 8. Read-your-writes — zookies

**Goal:** after a write, guarantee a subsequent read reflects it (handy across
replicas / caches). Every write returns a `zookie`; pass it to a read or check.

```bash
WRITE=$(curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"tuples":[{"shorthand":"doc:notes#viewer@ivan"}]}')
ZOOKIE=$(echo "$WRITE" | grep -o '"zookie":"[^"]*"' | cut -d'"' -f4)
echo "zookie = $ZOOKIE"

# Read "as of at least this write"
curl -s -X POST $BASE/tuples/read -H "$AUTH" -H "Content-Type: application/json" \
  -d "{\"namespace\":\"doc\",\"object_id\":\"notes\",\"zookie\":\"$ZOOKIE\"}"
# → {"tuples":[{"namespace":"doc","object_id":"notes","relation":"viewer","subject":"ivan"}],"zookie":"..."}
```

A zookie minted by one tenant is not honored for another — it only resolves a
snapshot for the tenant that created it.

---

## 9. Revoking access

Deleting a tuple is a soft-delete; it stops counting toward checks immediately.
The body matches the write body (shorthand or expanded form).

```bash
curl -s -X DELETE $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"tuples":[{"shorthand":"doc:readme#owner@alice"}]}'
# → {"deleted":1,"zookie":"..."}
```

Delete is precise about subjects: deleting `doc:x#viewer@group:eng#member`
removes **only** that userset grant, leaving any user grants or other usersets on
`doc:x#viewer` intact.

```bash
# Revoke a whole group's access in one call:
curl -s -X DELETE $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"tuples":[{"shorthand":"doc:spec#viewer@group:eng#member"}]}'
```

---

## 10. Watching for changes (SSE)

Stream tuple writes/deletes as Server-Sent Events — useful for cache
invalidation or audit pipelines.

```bash
curl -N -H "$AUTH" "$BASE/watch?namespace=doc"
# data: {"event":"connected"}
# data: {"event":"tuple.written","namespace":"doc","object_id":"readme","relation":"viewer","subject":"alice"}
# : ping          (heartbeat every 30s)
```

`-N` disables curl buffering so events print as they arrive. Omit `?namespace=`
to watch all namespaces for your tenant.

---

## 11. Putting it together — a mini Drive

A realistic model combining groups, role hierarchy, and folder inheritance.

```bash
# --- group: members ---
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "group", "relations": {"member": {"this": {}}}
}'

# --- folder: owners ⊆ viewers ---
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "folder",
  "relations": {
    "owner":  {"this": {}},
    "viewer": {"union": [{"this": {}}, {"computed_userset": {"relation": "owner"}}]}
  }
}'

# --- doc: owners ⊆ editors ⊆ viewers, and viewers inherit from the parent folder ---
curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{
  "name": "doc",
  "relations": {
    "parent": {"this": {}},
    "owner":  {"this": {}},
    "editor": {"union": [{"this": {}}, {"computed_userset": {"relation": "owner"}}]},
    "viewer": {"union": [
      {"this": {}},
      {"computed_userset": {"relation": "editor"}},
      {"tuple_to_userset": {"tupleset_relation": "parent", "computed_userset_relation": "viewer"}}
    ]}
  }
}'

# --- facts ---
curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{
  "tuples": [
    {"shorthand": "group:eng#member@alice"},
    {"shorthand": "group:eng#member@bob"},
    {"shorthand": "folder:eng-docs#viewer@group:eng#member"},
    {"shorthand": "doc:design#parent@folder:eng-docs#..."},
    {"shorthand": "doc:design#owner@carol"}
  ]
}'
```

Now the access picture is:

```bash
# carol: direct owner ⇒ editor ⇒ viewer
check doc:design viewer carol   # → true

# alice & bob: group:eng members ⇒ folder viewers ⇒ doc viewers (inherited)
check doc:design viewer alice   # → true
check doc:design viewer bob     # → true

# dan: no path ⇒ denied
check doc:design viewer dan     # → false
```

(where `check ns obj rel subj` is shorthand for the `POST /check` call above.)

One namespace change or one group-membership tuple ripples through every
affected check — no application redeploy, no migration.

---

## Tips & gotchas

- **`this` doesn't imply other relations.** Use `computed_userset` (or `union`)
  to build role ladders — see [recipe 2](#2-role-hierarchy-computed_userset).
- **Subjects are opaque strings.** `alice`, `user:123`, and `bob@example.com`
  are all valid user ids; Zeval doesn't interpret them. Pick one convention.
- **Usersets are how you do groups and inheritance.** A userset subject
  (`group:eng#member`) expands transitively at check time.
- **`tuple_to_userset` reads the parent object from the tuple**, ignoring the
  tuple's subject relation — the `#...` is just a placeholder.
- **Identifiers are validated.** Namespaces/relations are lowercase
  `[a-z][a-z0-9_]*`; object/user ids allow `[A-Za-z0-9_.\-@]` up to 256 chars.
  Malformed tuples are rejected with a 400.
- **Empty `union`/`intersection` are rejected** at namespace-write time.
- **Cycles are caught.** A `computed_userset` loop is rejected when you save the
  namespace; runtime recursion is also depth- and cycle-guarded.
- **Writes are idempotent**, deletes are soft, and both are bounded
  (max 500 tuples per write; reads return at most 10,000 rows).
- **Debug with the `resolution_path`** (check) and the `tree` (expand) — they
  show exactly which rules fired.

For the conceptual model, entity reference, and full endpoint list, see the
[README](../README.md).
