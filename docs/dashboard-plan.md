# Zeval Engine — Dashboard UI Plan

## Architecture

The dashboard is a **Phoenix LiveView** application served from the same
`zeval_web` app on the same port (4000) as the API. No React, no separate
build step. Pure Elixir, Phoenix, and server-rendered HTML with LiveView
for interactivity.

```
Browser ──→ Phoenix (port 4000)
               │
               ├── /api/v1/*          ← REST API (Bearer token auth)
               │
               └── /dashboard/*       ← LiveView routes (session auth)
                    │
                    ├── dashboard_user/login
                    ├── dashboard_user/logout
                    └── dashboard/ ← Phoenix LiveView routes
```

All dashboard pages are LiveView modules under `zeval_web`. The API
endpoints remain unchanged — the dashboard calls them internally via
Ecto queries, not HTTP.

---

## 2. Repository layout

```
apps/zeval_web/
├── lib/zeval_web/
│   ├── controllers/
│   │   ├── ...                     # existing API controllers (unchanged)
│   │   └── dashboard_session_controller.ex   # login/logout
│   ├── live/                       # NEW — all LiveView modules
│   │   ├── dashboard_live.ex       # shared layout + sidebar
│   │   ├── home_live.ex            # overview stats
│   │   ├── tenant_live.ex          # list tenants
│   │   ├── tenant_detail_live.ex   # single tenant view
│   │   ├── api_key_live.ex         # list/create/revoke keys
│   │   ├── namespace_live.ex       # list namespaces
│   │   ├── namespace_editor_live.ex # visual config editor
│   │   ├── tuple_live.ex           # write/read/delete tuples
│   │   ├── check_live.ex           # interactive check tool
│   │   └── expand_live.ex          # expand viewer
│   ├── templates/                  # NEW — HEEx templates
│   │   ├── layout/
│   │   │   └── dashboard.html.heex  # dashboard layout with sidebar
│   │   ├── dashboard/
│   │   │   ├── home.html.heex
│   │   │   ├── tenant.html.heex
│   │   │   ├── tenant_detail.html.heex
│   │   │   ├── api_key.html.heex
│   │   │   ├── namespace.html.heex
│   │   │   ├── namespace_editor.html.heex
│   │   │   ├── tuple.html.heex
│   │   │   ├── check.html.heex
│   │   │   └── expand.html.heex
│   │   └── session/
│   │       └── login.html.heex
│   └── plugs/
│       ├── ...                     # existing plugs (unchanged)
│       └── dashboard_auth.ex       # NEW — session-based auth for /dashboard/*
├── lib/zeval_web/router.ex         # updated — dashboard routes
└── priv/static/
    └── assets/                     # CSS + minimal JS
        ├── css/
        │   ├── app.css             # Core styles
        │   └── dashboard.css       # Dashboard-specific styles
        └── js/
            └── dashboard.js        # Minimal JS (copy buttons, etc.)
```

---

## 3. Pages & LiveView modules

### 3.1 Login (`/dashboard/login`)

**Flow:**
1. Admin creates a dashboard user via seed script
2. User visits `/dashboard/login` — standard form
3. `DashboardSessionController` validates credentials, sets session
4. Redirect to `/dashboard`

**Components:**
- Email + password form
- Error display (invalid credentials)
- Redirect if already logged in

**Backend additions:**
- `dashboard_users` table
- Phoenix session-based auth (Plug.Conn session, not JWT)
- `DashboardAuth` plug that checks `conn.assigns.current_user`

### 3.2 Dashboard Home (`/dashboard`)

**Stats cards:**
- Total tenants count
- Total namespaces across all tenants
- Total relation tuples
- Recent activity (last 10 check results from telemetry)

**Quick actions:**
- "New Namespace" button → namespace_editor
- "Check Access" → check_live
- "Create API Key" → api_key_live with tenant selector

### 3.3 Tenants (`/dashboard/tenants`)

**Table:** name, created date, service account count, namespace count.

**Actions:**
- Create tenant (modal or inline form)
- Click row → Tenant Detail page
- Delete tenant (confirmation modal)

**Tenant Detail (`/dashboard/tenants/:id`):**
- Tenant info card
- Service accounts table (filtered to this tenant)
- Namespaces table (filtered to this tenant)
- Quick actions: new key, new namespace

### 3.4 API Keys (`/dashboard/api-keys`)

**Table:** name, key_prefix, tenant, last_used, created, status (active/revoked).

**Create key:** Modal with:
- Tenant dropdown
- Key name input
- **Raw key shown once** in a highlighted `<pre>` box with copy button
- Warning text: "This key will not be shown again"

**Revoke key:** Button with confirmation dialog.

**Filter:** By tenant.

### 3.5 Namespaces (`/dashboard/namespaces`)

**Table:** name, tenant, version, created date.

**Actions:**
- Click row → open config in JSON viewer (collapsible `<pre>`)
- "Edit" button → Namespace Editor
- "Delete" button → confirmation

### 3.6 Namespace Editor (`/dashboard/namespaces/:id/edit`)

**This is the most complex page.** Two modes:

**Mode A: Visual form (default)**
```
┌─ Namespace: doc ─────────────────────────────┐
│                                               │
│  Relations:                                   │
│                                               │
│  ┌─ viewer ───────────────────────────────┐  │
│  │  Type: [union]                         │  │
│  │  Children:                             │  │
│  │  ┌─ [this] ────────────────────┐       │  │
│  │  │  (no parameters)            │       │  │
│  │  └─────────────────────────────┘       │  │
│  │  ┌─ [computed_userset] ────────┐       │  │
│  │  │  Relation: [editor]         │       │  │
│  │  └─────────────────────────────┘       │  │
│  │  [+ Add child]                        │  │
│  └────────────────────────────────────────┘  │
│                                               │
│  ┌─ editor ──────────────────────────────┐  │
│  │  Type: [union]                         │  │
│  │  └─ ...                                │  │
│  └────────────────────────────────────────┘  │
│                                               │
│  [+ Add relation]                             │
│                                               │
│  [JSON] [Cancel] [Save]                       │
└───────────────────────────────────────────────┘
```

Each relation is a card with:
- Relation name input
- Rule type selector dropdown
- Parameters that change based on type:

| Rule type | Parameters |
|-----------|-----------|
| `this` | None |
| `computed_userset` | Relation name text input |
| `tuple_to_userset` | tupleset_relation + computed_userset_relation inputs |
| `union` | List of child rule blocks (+ add / remove) |
| `intersection` | List of child rule blocks (+ add / remove) |
| `exclusion` | Two child rule blocks: base and subtract |

**Mode B: Raw JSON editor (toggle)**
- `<textarea>` with the raw JSON
- Syntax highlighting via CSS (no JS library)
- "Validate" button → shows errors inline

**Switch between modes** preserves state.

### 3.7 Tuples (`/dashboard/tuples`)

**Three tabs: Write / Read / Delete**

**Write tab:**
- Dynamic row-based form
- Each row: namespace, object_id, relation, subject
- Subject mode toggle: user (single input) vs userset (3 inputs)
- Add/remove rows button
- "Write" button → calls API → shows result (count + zookie)

**Read tab:**
- Filter form (namespace, object_id, relation, subject)
- Results in a table
- Optional zookie field
- JSON export button

**Delete tab:**
- Same form as Write
- Confirmation: "Delete N tuples?"

### 3.8 Check Tool (`/dashboard/check`)

**Purpose:** Interactive permission testing.

**Form:** namespace, object_id, relation, subject (with user/userset toggle).

**Results — Resolution Tree:**

```
┌─ Result: ✅ ALLOWED ───────────────────┐
│  Duration: 4ms  |  Depth: 3            │
│                                         │
│  viewer ── union ── ✅                  │
│  ├── this ───────────── ❌              │
│  └── computed_userset(editor) ── ✅     │
│      └── editor ── union ── ✅          │
│          ├── this ──────── ❌            │
│          └── computed_userset(owner) ✅  │
│              └── owner ── this ── ✅    │
└─────────────────────────────────────────┘
```

Each node:
- Indented based on depth
- Rule type as a badge (`this`, `computed_userset`, `union`, etc.)
- Relation name
- Green checkmark / red X
- Expandable children (nested `<ul>`)

**Implementation:** A recursive HEEx component that renders the path as nested lists with CSS styling. No JS needed — all data is in the resolution path returned by the check API.

### 3.9 Expand Tool (`/dashboard/expand`)

**Form:** namespace, object_id, relation.

**Results:** Tree view of users grouped by rule branch (same recursive HEEx component as check, different data shape).

---

## 4. CSS-only UI (no JS frameworks)

### Design: Dark theme

- Background: `#0d1117` (GitHub dark)
- Surface: `#161b22`
- Border: `#30363d`
- Text: `#e6edf3`
- Muted text: `#8b949e`
- Blue accent: `#58a6ff`
- Green: `#3fb950`
- Red: `#f85149`

### CSS patterns

Use utility-first CSS (custom, not Tailwind):

```css
/* Layout */
.dashboard-layout { display: grid; grid-template-columns: 260px 1fr; }
.sidebar { background: #161b22; border-right: 1px solid #30363d; }
.main { padding: 24px; }

/* Cards */
.card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 16px; }

/* Tables */
table { width: 100%; border-collapse: collapse; }
th { text-align: left; padding: 8px 12px; border-bottom: 2px solid #30363d; color: #8b949e; }
td { padding: 8px 12px; border-bottom: 1px solid #21262d; }

/* Forms */
input, select, textarea {
  background: #0d1117; border: 1px solid #30363d; border-radius: 6px;
  padding: 8px 12px; color: #e6edf3; width: 100%;
}

/* Buttons */
.btn { padding: 8px 16px; border-radius: 6px; border: none; cursor: pointer; }
.btn-primary { background: #238636; color: white; }
.btn-primary:hover { background: #2ea043; }
.btn-danger { background: #da3633; color: white; }
.btn-ghost { background: transparent; color: #e6edf3; border: 1px solid #30363d; }

/* Resolution tree */
.resolution-tree { font-family: monospace; font-size: 14px; }
.resolution-node { padding: 4px 0; }
.resolution-node .allowed { color: #3fb950; }
.resolution-node .denied { color: #f85149; }
.resolution-children { padding-left: 24px; border-left: 1px solid #30363d; }
```

### Static files

- `priv/static/assets/css/dashboard.css` — all dashboard styles
- `priv/static/assets/js/dashboard.js` — minimal vanilla JS:
  - Copy-to-clipboard
  - Raw key reveal timeout
  - Tab switching (CSS class toggle)
  - Confirmation dialogs

No npm, no webpack, no build step. CSS and JS served directly by Phoenix.

---

## 5. Backend additions

### 5.1 Dashboard user auth

**Migration:**
```sql
CREATE TABLE dashboard_users (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email       TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

**Schema:**
```
apps/zeval_core/lib/zeval_core/dashboard_user.ex
```

**Controller:**
```
apps/zeval_web/lib/zeval_web/controllers/dashboard_session_controller.ex
```
- `GET /dashboard/login` — render login form
- `POST /dashboard/login` — validate credentials, set session
- `GET /dashboard/logout` — clear session, redirect

**Plug:**
```
apps/zeval_web/lib/zeval_web/plugs/dashboard_auth.ex
```
- Matches on `/dashboard/*` paths
- Checks `Plug.Conn.get_session(conn, :current_user_id)`
- Loads user from DB, assigns `conn.assigns.current_user`
- Redirects to `/dashboard/login` if not authenticated

### 5.2 Tenant listing endpoint

Add a `GET /api/v1/dashboard/tenants` endpoint (or reuse the existing
`POST /api/v1/tenants` pattern — but for listing, need a new GET route).

Or simpler: the LiveView modules call the existing Ecto context modules
directly (ZevalCore.Tenants, ZevalCore.ServiceAccounts, etc.) rather
than going through HTTP. This is cleaner — no duplicate request path.

### 5.3 Stats aggregation

Add helper functions in zeval_core for dashboard stats:
- `ZevalCore.Stats.counts()` → `%{tenants: N, namespaces: N, tuples: N}`

---

## 6. Implementation phases

### Phase D1 — Auth & layout (2-3 days)

- [ ] Create `dashboard_users` migration + Ecto schema + context
- [ ] Implement DashboardSessionController (login form, POST login, logout)
- [ ] Implement DashboardAuth plug
- [ ] Seed script for initial admin user
- [ ] Dashboard layout (HTML + CSS): sidebar, top bar, main area
- [ ] Add `/dashboard/*` route to Phoenix router
- [ ] 404 handler for unknown dashboard routes

### Phase D2 — Tenants & API Keys (2 days)

- [ ] Tenant LiveView: table, create modal, delete confirmation
- [ ] Tenant Detail LiveView: info card, linked keys, linked namespaces
- [ ] Key LiveView: table with status, create modal with raw key reveal
- [ ] Revoke key flow
- [ ] Tenant filter on keys page

### Phase D3 — Namespace editor (3-4 days)

- [ ] Namespace LiveView: table, JSON viewer, delete
- [ ] Namespace Editor LiveView — visual form mode:
  - Relation list (add/remove)
  - Rule type selector
  - Dynamic form fields per rule type
  - Recursive child rule blocks for union/intersection/exclusion
- [ ] Raw JSON mode: textarea + validate button
- [ ] Toggle between modes preserving state
- [ ] Save button → calls Namespace.write()

### Phase D4 — Tuples & Check tool (2-3 days)

- [ ] Tuple LiveView: tabs (write/read/delete)
- [ ] Dynamic multi-row tuple form
- [ ] Tuple read results table
- [ ] Check LiveView: form + resolution tree
- [ ] Recursive HEEx resolution tree component
- [ ] Color-coded allow/deny nodes

### Phase D5 — Expand & polish (1-2 days)

- [ ] Expand LiveView: form + tree output
- [ ] Dashboard home: stats cards + quick actions
- [ ] CSS polish, responsive sidebar
- [ ] Copy-to-clipboard on IDs, zookies, keys
- [ ] Loading states (phx-disable-with, phx-throttle)

---

## 7. Total estimated effort

| Phase | Days | Focus |
|-------|------|-------|
| D1 | 2-3 | Auth scaffolding + layout |
| D2 | 2 | Tenants + API Keys |
| D3 | 3-4 | Namespace editor (hardest) |
| D4 | 2-3 | Tuples + Check tool |
| D5 | 1-2 | Expand + polish |
| **Total** | **10-14** | |

The namespace visual editor (D3) is the most complex — it needs a
recursive rule block form handler with dynamic fields per type. The check
tool's resolution tree (D4) is straightforward since the API already
returns the full path — it's just rendering nested HTML.
