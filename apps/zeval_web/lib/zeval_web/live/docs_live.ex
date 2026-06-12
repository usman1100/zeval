defmodule ZevalWeb.DashboardLive.DocsLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active: "docs",
       page_title: "Zeval Engine — API Reference"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div>
        <nav class="flex items-center gap-stack-xs font-label-mono text-label-mono mb-stack-xs">
          <span class="text-text-muted">Engine</span>
          <span class="text-text-muted">/</span>
          <span class="text-text-primary">API Reference</span>
        </nav>
        <h2 class="font-headline-lg text-headline-lg text-text-primary">REST API Reference</h2>
        <p class="font-body-md text-body-md text-text-secondary mt-stack-sm max-w-2xl">
          Complete reference for all REST API endpoints. Base path: <code class="text-emerald-success">/api/v1</code>.
          All authenticated endpoints require <code class="text-emerald-success">Authorization: Bearer &lt;raw_key&gt;</code>.
        </p>
      </div>

      <div class="flex flex-col gap-stack-md">
        <h3 class="font-headline-md text-headline-md text-text-primary" id="setup">Setup</h3>
        <.code_block>
          export KEY="perm_dev_&lt;paste-raw-key&gt;"
          export AUTH="Authorization: Bearer $KEY"
          export BASE=http://localhost:4000/api/v1
        </.code_block>
      </div>

      <.section title="Service Accounts" icon="vpn_key" id="service-accounts">
        <p class="font-body-md text-body-md text-text-secondary mb-stack-md">
          API key management — scoped to the authenticated tenant. The tenant is derived from the calling key.
        </p>
        <.endpoint
          method="POST" path="/service-accounts"
          body={~s({"name": "my-key"})}
          response={~s({"service_account": {"id": "...", "name": "my-key", "key_prefix": "perm_dev_abc", "raw_key": "perm_dev_<...>"}})}
          curl={~s(curl -s -X POST $BASE/service-accounts -H "$AUTH" -H "Content-Type: application/json" -d '{"name": "my-key"}')}
        >
          Create a new API key for the authenticated tenant.
        </.endpoint>
        <.endpoint
          method="DELETE" path="/service-accounts/:id"
          response={~s({"revoked": true})}
          curl={~s(curl -s -X DELETE $BASE/service-accounts/<id> -H "$AUTH")}
        >
          Revoke a key. Only keys in the caller's tenant can be revoked; others return 404.
        </.endpoint>
      </.section>

      <.section title="Namespaces" icon="dns" id="namespaces">
        <p class="font-body-md text-body-md text-text-secondary mb-stack-md">
          Define object types and their permission rules. Namespaces are upserted — writing the same name
          bumps the version after validation (including cycle detection).
        </p>
        <.endpoint
          method="POST" path="/namespaces"
          body={~s({"name": "doc", "relations": {"owner": {"this": {}}, "viewer": {"union": [{"this": {}}, {"computed_userset": {"relation": "owner"}}]}}})}
          response={~s({"namespace": {"name": "doc", "version": 1}})}
          curl={~s(curl -s -X POST $BASE/namespaces -H "$AUTH" -H "Content-Type: application/json" -d '{"name": "doc", "relations": {"owner": {"this": {}}, "viewer": {"union": [{"this": {}}, {"computed_userset": {"relation": "owner"}}]}}}')}
        >
          Create or update a namespace.
        </.endpoint>
        <.endpoint
          method="GET" path="/namespaces"
          response={~s({"namespaces": [{"name": "doc", "version": 1}]})}
          curl={~s(curl -s $BASE/namespaces -H "$AUTH")}
        >
          List all namespaces for the tenant.
        </.endpoint>
        <.endpoint
          method="GET" path="/namespaces/:name"
          response={~s({"namespace": {"name": "doc", "relations": {...}}})}
          curl={~s(curl -s $BASE/namespaces/doc -H "$AUTH")}
        >
          Get the full config for a specific namespace.
        </.endpoint>
        <.endpoint
          method="DELETE" path="/namespaces/:name"
          response={~s({"deleted": true})}
          curl={~s(curl -s -X DELETE $BASE/namespaces/doc -H "$AUTH")}
        >
          Delete a namespace and all its tuples.
        </.endpoint>
      </.section>

      <.section title="Tuples" icon="database" id="tuples">
        <p class="font-body-md text-body-md text-text-secondary mb-stack-md">
          Write, read, and delete relationship tuples — the facts that drive authorization.
        </p>
        <.endpoint
          method="POST" path="/tuples"
          body={~s({"tuples": [{"shorthand": "doc:readme#viewer@alice"}, {"shorthand": "doc:readme#viewer@bob"}]})}
          response={~s({"written": 2, "zookie": "zookie:<uuid>"})}
          curl={~s(curl -s -X POST $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{"tuples": [{"shorthand": "doc:readme#viewer@alice"}]}')}
        >
          Write tuples (max 500 per request). Supports shorthand or expanded form. Idempotent.
        </.endpoint>
        <.endpoint
          method="DELETE" path="/tuples"
          body={~s({"tuples": [{"shorthand": "doc:readme#viewer@alice"}]})}
          response={~s({"deleted": 1, "zookie": "zookie:<uuid>"})}
          curl={~s(curl -s -X DELETE $BASE/tuples -H "$AUTH" -H "Content-Type: application/json" -d '{"tuples": [{"shorthand": "doc:readme#viewer@alice"}]}')}
        >
          Soft-delete tuples. Same body shape as write. Returns a zookie.
        </.endpoint>
        <.endpoint
          method="POST" path="/tuples/read"
          body={~s({"namespace": "doc", "object_id": "readme", "zookie": "zookie:<uuid>"})}
          response={~s({"tuples": [...], "zookie": "zookie:<uuid>"})}
          curl={~s(curl -s -X POST $BASE/tuples/read -H "$AUTH" -H "Content-Type: application/json" -d '{"namespace": "doc", "object_id": "readme"}')}
        >
          Read tuples with optional namespace/object/relation filter and zookie for point-in-time reads. Bounded to 10,000 rows.
        </.endpoint>
        <.endpoint
          method="POST" path="/tuples/expand"
          body={~s({"namespace": "doc", "object_id": "readme", "relation": "viewer"})}
          response={~s({"tree": {"type": "union", "users": ["alice", "bob"], "children": [...]}})}
          curl={~s(curl -s -X POST $BASE/tuples/expand -H "$AUTH" -H "Content-Type: application/json" -d '{"namespace": "doc", "object_id": "readme", "relation": "viewer"}')}
        >
          Expand — list everyone who has a relation on an object. Returns a tree mirroring the rule structure.
        </.endpoint>
      </.section>

      <.section title="Check" icon="fact_check" id="check">
        <p class="font-body-md text-body-md text-text-secondary mb-stack-md">
          The core authorization query: does this subject have this relation on this object?
        </p>
        <.endpoint
          method="POST" path="/check"
          response={~s({"allowed": true, "zookie": null, "resolution_path": [{"rule": "union", "allowed": true, "children": [...]}]})}
          curl={~s(curl -s -X POST $BASE/check -H "$AUTH" -H "Content-Type: application/json" -d '{"namespace": "doc", "object_id": "readme", "relation": "viewer", "subject": "alice"}')}
        >
          Check access. Returns a boolean and a full resolution path showing how the decision was reached.
        </.endpoint>
      </.section>

      <.section title="Watch (SSE)" icon="notifications" id="watch">
        <p class="font-body-md text-body-md text-text-secondary mb-stack-md">
          Stream tuple changes as Server-Sent Events. Useful for cache invalidation or audit pipelines.
        </p>
        <.endpoint
          method="GET" path="/watch?namespace=doc"
          response={~s|data: {"event": "connected"}\ndata: {"event": "tuple.written", "namespace": "doc", "object_id": "readme", "relation": "viewer", "subject": "alice"}\n: ping (heartbeat every 30s)|}
          curl={~s|curl -N -H "$AUTH" "$BASE/watch?namespace=doc"|}
        >
          Subscribe to tuple change events. Omit <code class="text-emerald-success">?namespace=</code> to watch all namespaces.
        </.endpoint>
      </.section>

      <.section title="Health & Metrics" icon="monitor_heart" id="health">
        <.endpoint
          method="GET" path="/health"
          response={~s({"status": "ok"})}
          curl={~s(curl -s http://localhost:4000/health)}
        >
          Liveness probe — always returns 200.
        </.endpoint>
        <.endpoint
          method="GET" path="/ready"
          response={~s({"status": "ok"})}
          curl={~s(curl -s http://localhost:4000/ready)}
        >
          Readiness probe — 200 only if the database is reachable.
        </.endpoint>
        <.endpoint
          method="GET" path="/metrics"
          curl={~s(curl -s http://localhost:4000/metrics -H "Authorization: Bearer <metrics_token>")}
        >
          Prometheus-formatted metrics. Requires <code class="text-emerald-success">METRICS_TOKEN</code> bearer auth. Disabled (404) if token is not configured.
        </.endpoint>
      </.section>

      <.section title="Rate Limits" icon="speed" id="rate-limits">
        <div class="bg-surface-container-low border border-border-subtle overflow-hidden">
          <table class="w-full font-body-md text-body-md">
            <thead>
              <tr class="bg-surface-container-high border-b border-border-subtle">
                <th class="text-left px-stack-md py-stack-sm font-label-mono text-label-mono text-text-secondary uppercase">Scope</th>
                <th class="text-left px-stack-md py-stack-sm font-label-mono text-label-mono text-text-secondary uppercase">Limit</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-border-subtle">
              <tr>
                <td class="px-stack-md py-stack-sm text-text-primary font-code-block text-code-block">/check</td>
                <td class="px-stack-md py-stack-sm text-text-secondary">1,000 / min per key</td>
              </tr>
              <tr>
                <td class="px-stack-md py-stack-sm text-text-primary font-code-block text-code-block">/tuples (write & delete)</td>
                <td class="px-stack-md py-stack-sm text-text-secondary">500 / min per key</td>
              </tr>
              <tr>
                <td class="px-stack-md py-stack-sm text-text-primary font-code-block text-code-block">Other authenticated endpoints</td>
                <td class="px-stack-md py-stack-sm text-text-secondary">200 / min per key</td>
              </tr>
              <tr>
                <td class="px-stack-md py-stack-sm text-text-primary font-code-block text-code-block">/dashboard/login, /signup</td>
                <td class="px-stack-md py-stack-sm text-text-secondary">30 / min per IP</td>
              </tr>
            </tbody>
          </table>
        </div>
      </.section>

      <.section title="Error Format" icon="error" id="errors">
        <p class="font-body-md text-body-md text-text-secondary mb-stack-md">
          All API errors return a consistent JSON shape:
        </p>
        <.code_block>
          &#123;"error": "description of the problem", "code": "error_code"&#125;
        </.code_block>
        <p class="font-body-md text-body-md text-text-secondary mt-stack-md">
          HTTP status codes: <code class="text-ruby-error">400</code> validation error,
          <code class="text-ruby-error">401</code> missing/invalid auth,
          <code class="text-ruby-error">404</code> resource not found,
          <code class="text-ruby-error">429</code> rate limited.
        </p>
      </.section>

      <.section title="Concepts" icon="info" id="concepts">
        <div class="grid grid-cols-1 gap-stack-md">
          <.concept_card title="Relation Tuple" icon="database">
            A single fact: subject has relation on object. Written as shorthand:
            <code class="block mt-stack-sm text-emerald-success font-code-block text-code-block bg-surface-container-low p-stack-sm">namespace:object_id#relation@subject</code>
          </.concept_card>
          <.concept_card title="Subject" icon="person">
            Can be a user (opaque string like <code class="text-emerald-success">alice</code>) or a userset
            (<code class="text-emerald-success">group:eng#member</code> = "everyone who is a member of group:eng").
          </.concept_card>
          <.concept_card title="Zookie" icon="cookie">
            A consistency token. Pass it to reads/checks to guarantee read-your-writes semantics.
            Tenant-scoped — a token from one tenant won't work for another.
          </.concept_card>
          <.concept_card title="Rewrite Rules" icon="alt_route">
            Six rule types: <code class="text-emerald-success">this</code>, <code class="text-emerald-success">computed_userset</code>,
            <code class="text-emerald-success">tuple_to_userset</code>, <code class="text-emerald-success">union</code>,
            <code class="text-emerald-success">intersection</code>, <code class="text-emerald-success">exclusion</code>.
          </.concept_card>
        </div>
      </.section>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:icon, :string, required: true)
  attr(:id, :string, default: "")
  slot(:inner_block, required: true)

  def section(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col gap-stack-md bg-surface border border-border-subtle p-stack-md">
      <h3 class="font-headline-md text-headline-md text-text-primary flex items-center gap-stack-sm">
        <span class="material-symbols-outlined text-text-muted">{@icon}</span>
        {@title}
      </h3>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr(:method, :string, required: true)
  attr(:path, :string, required: true)
  attr(:body, :string, default: nil)
  attr(:body_alt, :string, default: nil)
  attr(:body_title, :string, default: nil)
  attr(:response, :string, default: nil)
  attr(:curl, :string, default: nil)
  slot(:inner_block, required: true)

  def endpoint(assigns) do
    ~H"""
    <div class="bg-surface-container-lowest border border-border-subtle p-stack-md">
      <div class="flex items-center gap-stack-sm mb-stack-md">
        <span class={
          "font-label-mono text-label-mono font-bold px-stack-sm py-0.5 " <>
          case @method do
            "GET" -> "bg-emerald-success/20 text-emerald-success"
            "POST" -> "bg-blue-500/20 text-blue-400"
            "DELETE" -> "bg-ruby-error/20 text-ruby-error"
            _ -> "bg-text-muted/20 text-text-muted"
          end
        }>{@method}</span>
        <code class="font-code-block text-code-block text-text-primary">{@path}</code>
      </div>
      <div class="font-body-md text-body-md text-text-secondary mb-stack-md">
        <%= render_slot(@inner_block) %>
      </div>
      <div :if={@body} class="mb-stack-md">
        <h5 class="font-label-mono text-label-mono text-text-muted mb-stack-xs">{@body_title || "Request body:"}</h5>
        <pre class="bg-background border border-border-subtle p-stack-sm overflow-x-auto"><code class="font-code-block text-code-block text-emerald-success"><%= @body %></code></pre>
      </div>
      <div :if={@body_alt} class="mb-stack-md">
        <h5 class="font-label-mono text-label-mono text-text-muted mb-stack-xs">{@body_title || "Alternative form:"}</h5>
        <pre class="bg-background border border-border-subtle p-stack-sm overflow-x-auto"><code class="font-code-block text-code-block text-emerald-success"><%= @body_alt %></code></pre>
      </div>
      <div :if={@response} class="mb-stack-md">
        <h5 class="font-label-mono text-label-mono text-text-muted mb-stack-xs">Response:</h5>
        <pre class="bg-background border border-border-subtle p-stack-sm overflow-x-auto"><code class="font-code-block text-code-block text-emerald-success"><%= @response %></code></pre>
      </div>
      <div :if={@curl}>
        <h5 class="font-label-mono text-label-mono text-text-muted mb-stack-xs">curl:</h5>
        <pre class="bg-background border border-border-subtle p-stack-sm overflow-x-auto"><code class="font-code-block text-code-block text-text-primary"><%= @curl %></code></pre>
      </div>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:icon, :string, default: "info")
  slot(:inner_block, required: true)

  def concept_card(assigns) do
    ~H"""
    <div class="bg-surface-container-low border border-border-subtle p-stack-md">
      <h4 class="font-label-mono text-label-mono text-text-primary flex items-center gap-stack-sm mb-stack-sm">
        <span class="material-symbols-outlined text-text-muted">{@icon}</span>
        {@title}
      </h4>
      <p class="font-body-md text-body-md text-text-secondary"><%= render_slot(@inner_block) %></p>
    </div>
    """
  end

  slot(:inner_block, required: true)

  def code_block(assigns) do
    ~H"""
    <pre class="bg-background border border-border-subtle p-stack-md overflow-x-auto"><code class="font-code-block text-code-block text-text-primary"><%= render_slot(@inner_block) %></code></pre>
    """
  end
end
