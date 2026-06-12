defmodule ZevalWeb.DashboardLive.ExpandLive do
  use ZevalWeb, :live_view
  import Phoenix.Component

  alias ZevalCore.{Expand, Tenants}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     assign(socket,
       active: "expand",
       page_title: "Zeval Engine — Expand Tool",
       tenants: Tenants.list_for_user(user_id),
       selected_tenant_id: "",
       namespace: "",
       object_id: "",
       relation: "",
       result: nil,
       error: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div>
        <nav class="flex items-center gap-2 font-label-mono text-label-mono mb-stack-xs">
          <span class="text-text-muted">Zeval Engine</span>
          <span class="text-text-muted">/</span>
          <span class="text-text-primary">Expand Tool</span>
        </nav>
        <h2 class="font-headline-lg text-headline-lg text-text-primary">Expand Tool</h2>
        <p class="text-text-secondary font-body-md text-body-md mt-1">View all users with access to a resource.</p>
      </div>

      <div class="bg-surface border border-border-subtle p-stack-md">
        <div class="mb-stack-md">
          <label class="block font-label-mono text-label-mono text-text-muted mb-stack-xs">Tenant</label>
          <form id="tenant-form" phx-change="select_tenant" class="relative">
            <select
              name="tenant_id"
              class="w-full bg-surface-container-lowest border border-border-subtle text-text-primary font-label-mono text-label-mono py-2 px-3 focus:border-white transition-all outline-none appearance-none"
            >
              <option value="">Select a tenant</option>
              <%= for t <- @tenants do %>
                <option value={t.id} selected={@selected_tenant_id == t.id}>{t.name}</option>
              <% end %>
            </select>
            <span class="material-symbols-outlined absolute right-2 top-1/2 -translate-y-1/2 text-text-muted pointer-events-none">expand_more</span>
          </form>
        </div>

        <div class="grid grid-cols-3 gap-stack-sm mb-stack-md">
          <div>
            <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Namespace</label>
            <input type="text" name="namespace" phx-keyup="update_field" phx-value-field="namespace" phx-debounce="200"
              value={@namespace}
              class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
              placeholder="doc" />
          </div>
          <div>
            <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Object ID</label>
            <input type="text" name="object_id" phx-keyup="update_field" phx-value-field="object_id" phx-debounce="200"
              value={@object_id}
              class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
              placeholder="doc-1" />
          </div>
          <div>
            <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Relation</label>
            <input type="text" name="relation" phx-keyup="update_field" phx-value-field="relation" phx-debounce="200"
              value={@relation}
              class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
              placeholder="viewer" />
          </div>
        </div>

        <button phx-click="run_expand" phx-disable-with="Expanding..."
          class="bg-emerald-success text-background px-stack-md py-2 font-label-mono text-label-mono font-bold flex items-center gap-2 hover:opacity-90 transition-opacity">
          <span class="material-symbols-outlined">unfold_more</span>
          Expand
        </button>
      </div>

      <%= if @error do %>
        <div class="bg-ruby-error/10 border border-ruby-error/30 text-ruby-error px-stack-md py-stack-sm font-label-mono text-label-mono">{@error}</div>
      <% end %>

      <%= if @result do %>
        <.expand_result_tree tree={@result} depth={0} />
      <% end %>
    </div>
    """
  end

  attr(:tree, :map, required: true)
  attr(:depth, :integer, required: true)

  def expand_result_tree(assigns) do
    ~H"""
    <div class="bg-surface border border-border-subtle p-stack-md">
      <div class="font-label-mono text-label-mono text-text-muted mb-stack-md uppercase">
        <span class="bg-surface-container-high text-text-primary px-2 py-0.5 rounded text-[10px] font-label-mono uppercase mr-2">{@tree.type}</span>
        {@tree.relation} <span class="text-text-muted">on</span> {@tree.object}
      </div>

      <%= if @tree.users != [] do %>
        <div class="mb-stack-sm">
          <span class="font-label-mono text-label-mono text-text-muted uppercase text-xs">Users ({length(@tree.users)})</span>
          <div class="flex flex-wrap gap-1 mt-1">
            <%= for user <- @tree.users do %>
              <span class="inline-flex items-center px-2 py-0.5 bg-emerald-success/10 text-emerald-success font-code-block text-[11px]">{user}</span>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @tree.children and @tree.children != [] do %>
        <div class="mt-stack-sm space-y-1">
          <%= for child <- @tree.children do %>
            <.expand_child_tree tree={child} depth={@depth + 1} />
          <% end %>
        </div>
      <% end %>

      <%= if @tree.users == [] and (!@tree.children or @tree.children == []) do %>
        <p class="font-body-md text-body-md text-text-muted">No users found.</p>
      <% end %>
    </div>
    """
  end

  attr(:tree, :map, required: true)
  attr(:depth, :integer, required: true)

  def expand_child_tree(assigns) do
    ~H"""
    <div class="border-l-2 border-border-subtle" style={"padding-left: #{@depth * 16 + 8}px; margin-left: 0"}>
      <div class="flex items-center gap-2 py-1">
        <span class="bg-surface-container-high text-text-muted px-2 py-0.5 rounded text-[10px] font-label-mono uppercase">{@tree.type}</span>
        <span class="font-code-block text-code-block text-text-primary">{@tree.relation}</span>
        <span class="text-text-muted font-label-mono text-label-mono">on</span>
        <span class="font-code-block text-code-block text-text-secondary">{@tree.object}</span>
      </div>

      <%= if @tree.users != [] do %>
        <div class="flex flex-wrap gap-1 ml-4 mt-0.5 mb-1">
          <%= for user <- @tree.users do %>
            <span class="inline-flex items-center px-2 py-0.5 bg-emerald-success/10 text-emerald-success font-code-block text-[11px]">{user}</span>
          <% end %>
        </div>
      <% end %>

      <%= if @tree.children and @tree.children != [] do %>
        <div class="space-y-0.5">
          <%= for child <- @tree.children do %>
            <.expand_child_tree tree={child} depth={@depth + 1} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("select_tenant", %{"tenant_id" => id}, socket) do
    {:noreply, assign(socket, selected_tenant_id: id, result: nil, error: nil)}
  end

  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    socket = assign(socket, String.to_existing_atom(field), value)
    {:noreply, assign(socket, result: nil, error: nil)}
  end

  def handle_event("run_expand", _, socket) do
    %{
      selected_tenant_id: tid,
      namespace: ns,
      object_id: oid,
      relation: rel
    } = socket.assigns

    cond do
      tid == "" ->
        {:noreply, assign(socket, error: "Select a tenant first")}

      ns == "" or oid == "" or rel == "" ->
        {:noreply, assign(socket, error: "Namespace, object ID, and relation are required")}

      true ->
        result = Expand.expand(tid, ns, oid, rel)
        {:noreply, assign(socket, result: result, error: nil)}
    end
  end
end
