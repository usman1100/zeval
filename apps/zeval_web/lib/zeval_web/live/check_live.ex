defmodule ZevalWeb.DashboardLive.CheckLive do
  use ZevalWeb, :live_view
  import Phoenix.Component

  alias ZevalCore.{Check, Tenants}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     assign(socket,
       active: "check",
       page_title: "Zeval Engine — Check Tool",
       tenants: Tenants.list_for_user(user_id),
       selected_tenant_id: "",
       namespace: "",
       object_id: "",
       relation: "",
       subject: "",
       subject_type: "user",
       userset_namespace: "",
       userset_object_id: "",
       userset_relation: "",
       result: nil,
       error: nil,
       loading: false
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div>
        <nav class="flex items-center gap-2 font-label-mono text-label-mono mb-stack-xs">
          <span class="text-text-muted">Zeval Engine</span>
          <span class="text-text-muted">/</span>
          <span class="text-text-primary">Check Tool</span>
        </nav>
        <h2 class="font-headline-lg text-headline-lg text-text-primary">Permission Checker</h2>
        <p class="text-text-secondary font-body-md text-body-md mt-1">Interactive permission testing with resolution tree.</p>
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

        <div class="mb-stack-md">
          <div class="flex items-center justify-between mb-0.5">
            <label class="font-label-mono text-label-mono text-text-muted">Subject</label>
            <button phx-click="toggle_subject_type"
              class="font-label-mono text-[10px] text-text-muted hover:text-text-primary border border-border-subtle px-1.5 py-0.5 transition-colors">
              {@subject_type}
            </button>
          </div>
          <%= if @subject_type == "user" do %>
            <input type="text" name="subject" phx-keyup="update_field" phx-value-field="subject" phx-debounce="200"
              value={@subject}
              class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
              placeholder="user:alice" />
          <% else %>
            <div class="grid grid-cols-3 gap-stack-sm">
              <input type="text" name="userset_ns" phx-keyup="update_field" phx-value-field="userset_namespace" phx-debounce="200"
                value={@userset_namespace}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="Namespace" />
              <input type="text" name="userset_oid" phx-keyup="update_field" phx-value-field="userset_object_id" phx-debounce="200"
                value={@userset_object_id}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="Object ID" />
              <input type="text" name="userset_rel" phx-keyup="update_field" phx-value-field="userset_relation" phx-debounce="200"
                value={@userset_relation}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="Relation" />
            </div>
          <% end %>
        </div>

        <button phx-click="run_check" phx-disable-with="Checking..."
          class="bg-emerald-success text-background px-stack-md py-2 font-label-mono text-label-mono font-bold flex items-center gap-2 hover:opacity-90 transition-opacity">
          <span class="material-symbols-outlined">fact_check</span>
          Run Check
        </button>
      </div>

      <%= if @error do %>
        <div class="bg-ruby-error/10 border border-ruby-error/30 text-ruby-error px-stack-md py-stack-sm font-label-mono text-label-mono">{@error}</div>
      <% end %>

      <%= if @result do %>
        <.result_card result={@result} />
      <% end %>
    </div>
    """
  end

  attr(:result, :map, required: true)

  def result_card(assigns) do
    ~H"""
    <div class="bg-surface border border-border-subtle p-stack-md">
      <div class="flex items-center gap-stack-md mb-stack-md">
        <%= if @result.allowed do %>
          <span class="inline-flex items-center gap-2 bg-emerald-success/10 text-emerald-success px-stack-md py-1 font-label-mono text-label-mono">
            <span class="material-symbols-outlined">check_circle</span>
            ALLOWED
          </span>
        <% else %>
          <span class="inline-flex items-center gap-2 bg-ruby-error/10 text-ruby-error px-stack-md py-1 font-label-mono text-label-mono">
            <span class="material-symbols-outlined">cancel</span>
            DENIED
          </span>
        <% end %>
      </div>

      <div class="font-label-mono text-label-mono text-text-muted mb-stack-md">
        Resolution path ({length(@result.path)} steps)
      </div>

      <div class="font-mono text-sm">
        <.resolution_tree path={@result.path} />
      </div>
    </div>
    """
  end

  attr(:path, :list, required: true)

  def resolution_tree(assigns) do
    ~H"""
    <ul class="space-y-1">
      <%= for step <- @path do %>
        <.tree_node step={step} depth={0} />
      <% end %>
    </ul>
    """
  end

  attr(:step, :map, required: true)
  attr(:depth, :integer, required: true)

  def tree_node(assigns) do
    ~H"""
    <li class="border-l-2 border-border-subtle" style={"padding-left: #{@depth * 20 + 8}px"}>
      <div class="flex items-center gap-2 py-0.5">
        <%= if @step.allowed do %>
          <span class="text-emerald-success font-medium"><span class="material-symbols-outlined text-sm">check_circle</span></span>
        <% else %>
          <span class="text-ruby-error font-medium"><span class="material-symbols-outlined text-sm">cancel</span></span>
        <% end %>

        <%= cond do %>
          <% @step.rule in ["this", "computed_userset", "tuple_to_userset", "tuple_to_userset_child"] -> %>
            <span class="text-text-primary">{@step.relation || @step.relation}</span>
            <span class="bg-surface-container-high text-text-muted px-2 py-0.5 rounded text-[10px] font-label-mono uppercase">{@step.rule}</span>
            <%= if @step.rule == "tuple_to_userset" do %>
              <span class="text-text-muted text-[10px] font-label-mono">via {@step.via_relation} ({@step.parents_found} parents)</span>
            <% end %>
            <%= if @step.rule == "tuple_to_userset_child" do %>
              <span class="text-text-muted text-[10px] font-label-mono">via {@step.via_relation}</span>
            <% end %>

          <% @step.rule in ["union", "intersection", "exclusion"] -> %>
            <span class="text-text-primary">{@step.relation}</span>
            <span class="bg-surface-container-high text-text-muted px-2 py-0.5 rounded text-[10px] font-label-mono uppercase">{@step.rule}</span>
            <%= if @step.rule == "exclusion" do %>
              <span class="text-text-muted text-[10px] font-label-mono">base / subtract</span>
            <% end %>

          <% @step.rule == "undefined_relation" -> %>
            <span class="text-text-primary">{@step.relation}</span>
            <span class="bg-ruby-error/10 text-ruby-error px-2 py-0.5 rounded text-[10px] font-label-mono">undefined relation</span>

          <% @step.rule == "undefined_namespace" -> %>
            <span class="text-text-primary">{@step.namespace}</span>
            <span class="bg-ruby-error/10 text-ruby-error px-2 py-0.5 rounded text-[10px] font-label-mono">undefined namespace</span>

          <% @step.rule == "cycle" -> %>
            <span class="text-text-primary">{@step.relation}</span>
            <span class="bg-ruby-error/10 text-ruby-error px-2 py-0.5 rounded text-[10px] font-label-mono">cycle detected</span>

          <% @step.rule == "max_depth_exceeded" -> %>
            <span class="bg-ruby-error/10 text-ruby-error px-2 py-0.5 rounded text-[10px] font-label-mono">max depth ({@step.depth}) exceeded</span>

          <% true -> %>
            <span class="text-text-muted">{@step.rule}</span>
        <% end %>
      </div>

      <%= if Map.has_key?(@step, :children) and is_list(@step.children) and @step.children != [] do %>
        <ul class="space-y-0.5 mt-0.5">
          <%= for child <- @step.children do %>
            <li class="border-l-2 border-border-subtle" style={"padding-left: #{(@depth + 1) * 20 + 8}px"}>
              <div class="flex items-center gap-2 py-0.5">
                <%= if child.allowed do %>
                  <span class="text-emerald-success font-medium"><span class="material-symbols-outlined text-sm">check_circle</span></span>
                <% else %>
                  <span class="text-ruby-error font-medium"><span class="material-symbols-outlined text-sm">cancel</span></span>
                <% end %>
                <span class="bg-surface-container-high text-text-muted px-2 py-0.5 rounded text-[10px] font-label-mono uppercase">{child.rule}</span>
              </div>
            </li>
          <% end %>
        </ul>
      <% end %>
    </li>
    """
  end

  def handle_event("select_tenant", %{"tenant_id" => id}, socket) do
    {:noreply, assign(socket, selected_tenant_id: id, result: nil, error: nil)}
  end

  def handle_event("update_field", %{"field" => field, "value" => value}, socket) do
    socket = assign(socket, String.to_existing_atom(field), value)
    {:noreply, assign(socket, result: nil, error: nil)}
  end

  def handle_event("toggle_subject_type", _, socket) do
    current = socket.assigns.subject_type
    new_type = if current == "user", do: "userset", else: "user"

    {:noreply,
     assign(socket,
       subject_type: new_type,
       subject: "",
       userset_namespace: "",
       userset_object_id: "",
       userset_relation: ""
     )}
  end

  def handle_event("run_check", _, socket) do
    %{
      selected_tenant_id: tid,
      namespace: ns,
      object_id: oid,
      relation: rel,
      subject: subj,
      subject_type: subj_type
    } = socket.assigns

    cond do
      tid == "" ->
        {:noreply, assign(socket, error: "Select a tenant first")}

      ns == "" or oid == "" or rel == "" ->
        {:noreply, assign(socket, error: "Namespace, object ID, and relation are required")}

      subj == "" and subj_type == "user" ->
        {:noreply, assign(socket, error: "Subject is required")}

      true ->
        subject = build_subject(subj, subj_type, socket.assigns)

        if subject == nil do
          {:noreply, assign(socket, error: "Complete all subject fields")}
        else
          result = Check.check(tid, ns, oid, rel, subject)
          {:noreply, assign(socket, result: result, error: nil)}
        end
    end
  end

  defp build_subject(subj, "user", _assigns) do
    if String.contains?(subj, ":"), do: {:user, subj}, else: subj
  end

  defp build_subject(_subj, "userset", assigns) do
    if assigns.userset_namespace != "" and assigns.userset_object_id != "" and
         assigns.userset_relation != "" do
      {:userset, assigns.userset_namespace, assigns.userset_object_id, assigns.userset_relation}
    else
      nil
    end
  end

  defp build_subject(_, _, _), do: nil
end
