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

## 4. Tailwind CSS styling

### Setup

Tailwind is already available in the Phoenix project — it's included in
`mix.exs` as `{:tailwind, "~> 0.2"}`. The `config.exs` configures the
Tailwind CLI to watch `apps/zeval_web/lib/zeval_web/**/*.heex` and output
to `priv/static/assets/app.css`.

No additional setup needed. The dashboard templates live under
`apps/zeval_web/lib/zeval_web/live/` and `apps/zeval_web/lib/zeval_web/templates/dashboard/`,
which are already in the Tailwind content paths.

### Design: Dark theme

The Phoenix app's `root.html.heex` layout already includes the dark
theme setup via CSS custom properties. The dashboard uses the same
Tailwind dark classes.

Key Tailwind classes used:

| Element | Classes |
|---------|---------|
| Layout grid | `grid grid-cols-[260px_1fr] h-screen` |
| Sidebar | `bg-gray-900 border-r border-gray-700 p-4` |
| Main content | `bg-gray-950 p-6 overflow-y-auto` |
| Card | `bg-gray-900 border border-gray-700 rounded-lg p-4` |
| Table header | `text-left px-3 py-2 text-xs font-medium text-gray-400 uppercase tracking-wider` |
| Table cell | `px-3 py-2 text-sm border-b border-gray-800` |
| Button primary | `bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium` |
| Button danger | `bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded-lg text-sm font-medium` |
| Button ghost | `bg-transparent border border-gray-600 text-gray-300 hover:text-white px-3 py-1.5 rounded-lg text-sm` |
| Input | `bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm w-full text-white` |
| Badge | `inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium` |
| Success badge | `bg-green-900 text-green-300` |
| Danger badge | `bg-red-900 text-red-300` |

### Resolution tree styling

The check tool's resolution tree uses a nested `<ul>` with Tailwind:

```html
<ul class="font-mono text-sm space-y-1">
  <li class="pl-0 border-l-2 border-gray-700 pl-4">
    <span class="text-green-400 font-medium">✅</span>
    <span class="text-gray-400">viewer</span>
    <span class="bg-gray-700 text-gray-300 px-2 py-0.5 rounded text-xs">union</span>
    <ul class="mt-1 space-y-1">
      <li class="border-l-2 border-gray-700 pl-4">
        <span class="text-red-400">❌</span>
        <span class="text-gray-500">viewer</span>
        <span class="bg-gray-800 text-gray-400 px-2 py-0.5 rounded text-xs">this</span>
      </li>
    </ul>
  </li>
</ul>
```

### Minimal JavaScript

A single small JS file at `priv/static/assets/js/dashboard.js` for:

- Copy-to-clipboard (no library — uses `navigator.clipboard.writeText()`)
- Tab switching (CSS class toggle via data attributes)
- Raw key reveal timeout (hide after 30 seconds)
- Confirmation dialogs (uses `confirm()`)

Loaded via a `<script>` tag in the dashboard layout. No npm, no webpack,
no build step.

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

**⚠️ Critical: avoid redirect loop on login page.**

The auth plug must skip `/dashboard/login` and `/dashboard/logout`.
The cleanest approach is to apply it via **router `pipe_through`** so
public routes are explicitly excluded:

```elixir
# In router.ex

scope "/dashboard", ZevalWeb do
  # Public routes — no auth
  get "/login", DashboardSessionController, :new
  post "/login", DashboardSessionController, :create
  get "/logout", DashboardSessionController, :delete

  # Protected routes — requires session
  scope "/", ZevalWeb do
    pipe_through [:dashboard_auth]

    live "/", DashboardLive.HomeLive, :index
    live "/tenants", DashboardLive.TenantLive, :index
    live "/tenants/:id", DashboardLive.TenantDetailLive, :show
    live "/api-keys", DashboardLive.ApiKeyLive, :index
    live "/namespaces", DashboardLive.NamespaceLive, :index
    live "/namespaces/:id/edit", DashboardLive.NamespaceEditorLive, :edit
    live "/tuples", DashboardLive.TupleLive, :index
    live "/check", DashboardLive.CheckLive, :index
    live "/expand", DashboardLive.ExpandLive, :index
  end
end
```

The plug itself is straightforward — if no session, redirect:

```elixir
defmodule ZevalWeb.Plugs.DashboardAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :current_user_id) do
      nil ->
        conn
        |> put_session(:return_to, conn.request_path)
        |> redirect(to: "/dashboard/login")
        |> halt()

      user_id ->
        case ZevalCore.DashboardUsers.get(user_id) do
          nil ->
            conn
            |> delete_session(:current_user_id)
            |> redirect(to: "/dashboard/login")
            |> halt()

          user ->
            assign(conn, :current_user, user)
        end
    end
  end
end
```

### 5.2 Session security

```elixir
# In endpoint.ex
plug Plug.Session,
  store: :cookie,
  key: "_zeval_dashboard",
  signing_salt: "change-me-in-prod",
  encryption_salt: "change-me-in-prod",
  http_only: true,
  secure: Application.get_env(:zeval_web, :env) == :prod,
  same_site: "Lax"
```

Consider adding:
- Idle timeout (re-auth after inactivity)
- Absolute timeout (max 12h session lifetime)
- Session regeneration on login (prevents session fixation)

### 5.3 Login hardening

- Rate limit login attempts using Hammer (same ETS backend)
- Show last login time on the dashboard home page
- Log all failed login attempts

### 5.4 Future-proofing permissions

Dashboard users are super-admin for v1. For v2, the system can dogfood
its own Zanzibar model:

```elixir
# Store dashboard_users as subjects
# Check access using the engine itself
ZevalCore.Check.check(
  "global",                # system namespace
  "dashboard_access",       # resource
  "view",                  # action
  {:user, "user:123"}      # current dashboard user
)
```

This would allow tenant-scoped dashboard users, read-only auditors,
and granular permission levels without changing the auth framework.

### 5.5 Audit logging

Every dashboard write operation (create namespace, write tuples, revoke
key) should log:

```elixir
Logger.info("namespace.created", %{
  actor_id: current_user.id,
  actor_email: current_user.email,
  action: "namespace.created",
  target: namespace_id,
  tenant_id: tenant_id
})

### 5.6 Tenant listing endpoint

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
