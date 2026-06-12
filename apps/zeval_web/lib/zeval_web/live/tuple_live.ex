defmodule ZevalWeb.DashboardLive.TupleLive do
  use ZevalWeb, :live_view

  alias ZevalCore.{Tuples, Tenants}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id

    {:ok,
     assign(socket,
       active: "tuples",
       page_title: "Zeval Engine — Tuples",
       tab: :write,
       tenants: Tenants.list_for_user(user_id),
       selected_tenant_id: "",
       rows: [new_row()],
       read_filter: %{
         namespace: "",
         object_id: "",
         relation: "",
         subject: "",
         subject_type: "user"
       },
       subject_type: "user",
       zookie: "",
       results: nil,
       result_tuples: [],
       error: nil,
       json_export: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div>
        <nav class="flex items-center gap-2 font-label-mono text-label-mono mb-stack-xs">
          <span class="text-text-muted">Zeval Engine</span>
          <span class="text-text-muted">/</span>
          <span class="text-text-primary">Tuples</span>
        </nav>
        <h2 class="font-headline-lg text-headline-lg text-text-primary">Tuples</h2>
        <p class="text-text-secondary font-body-md text-body-md mt-1">Read, write, and delete relationship tuples.</p>
      </div>

      <div class="bg-surface border border-border-subtle p-stack-md">
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

      <div class="flex bg-surface-container-low p-0.5 border border-border-subtle w-fit">
        <button phx-click="set_tab" phx-value-tab="write"
          class={"px-stack-md py-1.5 font-label-mono text-label-mono transition-all " <> if @tab == :write, do: "bg-secondary-container text-on-secondary-container", else: "text-text-muted hover:text-text-primary"}>
          Write
        </button>
        <button phx-click="set_tab" phx-value-tab="read"
          class={"px-stack-md py-1.5 font-label-mono text-label-mono transition-all " <> if @tab == :read, do: "bg-secondary-container text-on-secondary-container", else: "text-text-muted hover:text-text-primary"}>
          Read
        </button>
        <button phx-click="set_tab" phx-value-tab="delete"
          class={"px-stack-md py-1.5 font-label-mono text-label-mono transition-all " <> if @tab == :delete, do: "bg-secondary-container text-on-secondary-container", else: "text-text-muted hover:text-text-primary"}>
          Delete
        </button>
      </div>

      <%= if @error do %>
        <div class="bg-ruby-error/10 border border-ruby-error/30 text-ruby-error px-stack-md py-stack-sm font-label-mono text-label-mono">{@error}</div>
      <% end %>

      <%= if @tab == :write do %>
        <.write_tab rows={@rows} />
      <% end %>

      <%= if @tab == :read do %>
        <.read_tab filter={@read_filter} subject_type={@subject_type} zookie={@zookie} results={@results} result_tuples={@result_tuples} json_export={@json_export} />
      <% end %>

      <%= if @tab == :delete do %>
        <.delete_tab rows={@rows} results={@results} />
      <% end %>
    </div>
    """
  end

  attr(:rows, :list, required: true)

  def write_tab(assigns) do
    ~H"""
    <div class="bg-surface border border-border-subtle p-stack-md">
      <h3 class="font-headline-md text-headline-md text-text-primary mb-stack-md">Write Tuples</h3>
      <div class="space-y-stack-sm">
        <%= for {row, idx} <- Enum.with_index(@rows) do %>
          <.tuple_row row={row} idx={idx} />
        <% end %>
      </div>
      <div class="flex gap-stack-sm mt-stack-md">
        <button phx-click="add_row"
          class="border border-border-subtle text-text-secondary px-stack-md py-1.5 font-label-mono text-label-mono flex items-center gap-1 hover:text-text-primary hover:bg-surface-container-high transition-colors">
          <span class="material-symbols-outlined">add</span>
          Add Row
        </button>
        <button phx-click="write_tuples" phx-disable-with="Writing..."
          class="bg-emerald-success text-background px-stack-md py-2 font-label-mono text-label-mono font-bold flex items-center gap-2 hover:opacity-90 transition-opacity">
          <span class="material-symbols-outlined">upload</span>
          Write Tuples
        </button>
      </div>
    </div>
    """
  end

  attr(:row, :map, required: true)
  attr(:idx, :integer, required: true)

  def tuple_row(assigns) do
    ~H"""
    <div class="bg-surface-container-low border border-border-subtle p-stack-md relative group">
      <%= if @idx > 0 do %>
        <button phx-click="remove_row" phx-value-idx={@idx}
          class="absolute -top-2 -right-2 bg-surface-container-highest border border-border-subtle text-text-muted hover:text-ruby-error w-6 h-6 flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity">
          <span class="material-symbols-outlined text-sm">close</span>
        </button>
      <% end %>
      <div class="grid grid-cols-4 gap-stack-sm">
        <div>
          <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Namespace</label>
          <input type="text" name="namespace" phx-keyup="update_row" phx-value-idx={@idx} phx-value-field="namespace" phx-debounce="200"
            value={@row.namespace}
            class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
            placeholder="doc" />
        </div>
        <div>
          <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Object ID</label>
          <input type="text" name="object_id" phx-keyup="update_row" phx-value-idx={@idx} phx-value-field="object_id" phx-debounce="200"
            value={@row.object_id}
            class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
            placeholder="doc-1" />
        </div>
        <div>
          <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Relation</label>
          <input type="text" name="relation" phx-keyup="update_row" phx-value-idx={@idx} phx-value-field="relation" phx-debounce="200"
            value={@row.relation}
            class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
            placeholder="viewer" />
        </div>
        <div>
          <div class="flex items-center justify-between mb-0.5">
            <label class="font-label-mono text-label-mono text-text-muted">Subject</label>
            <button phx-click="toggle_subject_type" phx-value-idx={@idx}
              class="font-label-mono text-[10px] text-text-muted hover:text-text-primary border border-border-subtle px-1.5 py-0.5 transition-colors">
              {@row.subject_type}
            </button>
          </div>
          <%= if @row.subject_type == "user" do %>
            <input type="text" name="subject" phx-keyup="update_row" phx-value-idx={@idx} phx-value-field="subject" phx-debounce="200"
              value={@row.subject}
              class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
              placeholder="user:alice" />
          <% else %>
            <div class="grid grid-cols-3 gap-1">
              <input type="text" name="userset_ns" phx-keyup="update_row_userset" phx-value-idx={@idx} phx-value-field="userset_namespace" phx-debounce="200"
                value={@row.userset_namespace}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="ns" />
              <input type="text" name="userset_oid" phx-keyup="update_row_userset" phx-value-idx={@idx} phx-value-field="userset_object_id" phx-debounce="200"
                value={@row.userset_object_id}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="obj" />
              <input type="text" name="userset_rel" phx-keyup="update_row_userset" phx-value-idx={@idx} phx-value-field="userset_relation" phx-debounce="200"
                value={@row.userset_relation}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="rel" />
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr(:filter, :map, required: true)
  attr(:subject_type, :string, required: true)
  attr(:zookie, :string, required: true)
  attr(:results, :any, default: nil)
  attr(:result_tuples, :list, default: [])
  attr(:json_export, :string, default: nil)

  def read_tab(assigns) do
    ~H"""
    <div class="bg-surface border border-border-subtle p-stack-md">
      <h3 class="font-headline-md text-headline-md text-text-primary mb-stack-md">Read Tuples</h3>
      <div class="grid grid-cols-4 gap-stack-sm mb-stack-md">
        <div>
          <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Namespace</label>
          <input type="text" name="namespace" phx-keyup="update_filter" phx-value-field="namespace" phx-debounce="200"
            value={@filter.namespace}
            class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
            placeholder="doc" />
        </div>
        <div>
          <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Object ID</label>
          <input type="text" name="object_id" phx-keyup="update_filter" phx-value-field="object_id" phx-debounce="200"
            value={@filter.object_id}
            class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
            placeholder="doc-1" />
        </div>
        <div>
          <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Relation</label>
          <input type="text" name="relation" phx-keyup="update_filter" phx-value-field="relation" phx-debounce="200"
            value={@filter.relation}
            class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
            placeholder="viewer" />
        </div>
        <div>
          <div class="flex items-center justify-between mb-0.5">
            <label class="font-label-mono text-label-mono text-text-muted">Subject</label>
            <button phx-click="toggle_filter_subject"
              class="font-label-mono text-[10px] text-text-muted hover:text-text-primary border border-border-subtle px-1.5 py-0.5 transition-colors">
              {@subject_type}
            </button>
          </div>
          <%= if @subject_type == "user" do %>
            <input type="text" name="subject" phx-keyup="update_filter" phx-value-field="subject" phx-debounce="200"
              value={@filter.subject}
              class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
              placeholder="user:alice" />
          <% else %>
            <div class="grid grid-cols-3 gap-1">
              <input type="text" name="userset_ns" phx-keyup="update_filter_userset" phx-value-field="userset_namespace" phx-debounce="200"
                value={@filter.userset_namespace}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="ns" />
              <input type="text" name="userset_oid" phx-keyup="update_filter_userset" phx-value-field="userset_object_id" phx-debounce="200"
                value={@filter.userset_object_id}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="obj" />
              <input type="text" name="userset_rel" phx-keyup="update_filter_userset" phx-value-field="userset_relation" phx-debounce="200"
                value={@filter.userset_relation}
                class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
                placeholder="rel" />
            </div>
          <% end %>
        </div>
      </div>
      <div class="mb-stack-md">
        <label class="block font-label-mono text-label-mono text-text-muted mb-0.5">Zookie (optional)</label>
        <input type="text" name="zookie" phx-keyup="update_zookie" phx-debounce="200"
          value={@zookie}
          class="w-full bg-background border border-border-subtle font-code-block text-code-block text-text-primary px-2 py-1.5 focus:border-white focus:ring-0"
          placeholder="Consistency token" />
      </div>
      <div class="flex gap-stack-sm">
        <button phx-click="read_tuples" phx-disable-with="Reading..."
          class="bg-emerald-success text-background px-stack-md py-2 font-label-mono text-label-mono font-bold flex items-center gap-2 hover:opacity-90 transition-opacity">
          <span class="material-symbols-outlined">search</span>
          Read Tuples
        </button>
        <%= if @result_tuples != [] do %>
          <button phx-click="export_json"
            class="border border-border-subtle text-text-secondary px-stack-md py-2 font-label-mono text-label-mono hover:text-text-primary transition-colors">
            Export JSON
          </button>
        <% end %>
      </div>
    </div>

    <%= if @result_tuples != [] do %>
      <div class="bg-surface border border-border-subtle overflow-hidden">
        <div class="bg-surface-container-low border-b border-border-subtle px-stack-md py-2 flex items-center justify-between">
          <span class="font-label-mono text-label-mono text-text-muted uppercase">Results ({length(@result_tuples)} tuples)</span>
        </div>
        <div class="overflow-x-auto custom-scrollbar">
          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="bg-surface-container-low border-b border-border-subtle">
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase">Namespace</th>
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase">Object ID</th>
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase">Relation</th>
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase">Subject</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-border-subtle">
              <%= for t <- @result_tuples do %>
                <tr class="hover:bg-surface-container-high transition-colors group font-code-block text-code-block">
                  <td class="px-stack-md py-stack-sm text-text-primary">{t.namespace}</td>
                  <td class="px-stack-md py-stack-sm text-text-primary">{t.object_id}</td>
                  <td class="px-stack-md py-stack-sm text-text-secondary">{t.relation}</td>
                  <td class="px-stack-md py-stack-sm text-text-secondary">{format_subject(t.subject)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%= if @json_export do %>
      <div class="bg-surface border border-border-subtle p-stack-md">
        <div class="flex items-center justify-between mb-stack-sm">
          <span class="font-label-mono text-label-mono text-text-muted uppercase">JSON Export</span>
          <button phx-click="dismiss_json"
            class="text-text-muted hover:text-text-primary transition-colors">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <pre class="bg-surface-container-lowest border border-border-subtle p-stack-md font-code-block text-code-block text-text-primary overflow-x-auto custom-scrollbar max-h-80"><%= @json_export %></pre>
      </div>
    <% end %>
    """
  end

  attr(:rows, :list, required: true)
  attr(:results, :any, default: nil)

  def delete_tab(assigns) do
    ~H"""
    <div class="bg-surface border border-border-subtle p-stack-md">
      <h3 class="font-headline-md text-headline-md text-text-primary mb-stack-md">Delete Tuples</h3>
      <div class="space-y-stack-sm">
        <%= for {row, idx} <- Enum.with_index(@rows) do %>
          <.tuple_row row={row} idx={idx} />
        <% end %>
      </div>
      <div class="flex gap-stack-sm mt-stack-md">
        <button phx-click="add_row"
          class="border border-border-subtle text-text-secondary px-stack-md py-1.5 font-label-mono text-label-mono flex items-center gap-1 hover:text-text-primary hover:bg-surface-container-high transition-colors">
          <span class="material-symbols-outlined">add</span>
          Add Row
        </button>
        <button phx-click="delete_tuples" phx-disable-with="Deleting..."
          class="bg-ruby-error text-white px-stack-md py-2 font-label-mono text-label-mono font-bold flex items-center gap-2 hover:opacity-90 transition-opacity">
          <span class="material-symbols-outlined">delete</span>
          Delete Tuples
        </button>
      </div>
    </div>

    <%= if @results do %>
      <div class={"bg-surface border border-border-subtle p-stack-md " <> if @results.deleted > 0, do: "border-emerald-success/30", else: "border-border-subtle"}>
        <div class="flex items-center gap-2">
          <span class="material-symbols-outlined text-emerald-success">check_circle</span>
          <span class="font-label-mono text-label-mono text-text-primary">
            Deleted {@results.deleted} tuple(s)
          </span>
        </div>
        <div class="mt-stack-sm font-code-block text-code-block text-text-muted break-all">
          Zookie: {@results.zookie}
        </div>
      </div>
    <% end %>
    """
  end

  def handle_event("select_tenant", %{"tenant_id" => id}, socket) do
    {:noreply,
     assign(socket, selected_tenant_id: id, results: nil, result_tuples: [], json_export: nil)}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply,
     assign(socket,
       tab: String.to_existing_atom(tab),
       results: nil,
       result_tuples: [],
       json_export: nil
     )}
  end

  def handle_event("add_row", _, socket) do
    {:noreply, assign(socket, rows: socket.assigns.rows ++ [new_row()])}
  end

  def handle_event("remove_row", %{"idx" => idx}, socket) do
    idx = String.to_integer(idx)
    rows = List.delete_at(socket.assigns.rows, idx)
    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("update_row", %{"idx" => idx, "field" => field, "value" => value}, socket) do
    idx = String.to_integer(idx)
    rows = update_row_at(socket.assigns.rows, idx, field, value)
    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("toggle_subject_type", %{"idx" => idx}, socket) do
    idx = String.to_integer(idx)

    rows =
      socket.assigns.rows
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        if i == idx do
          current = row.subject_type
          new_type = if current == "user", do: "userset", else: "user"

          %{
            row
            | subject_type: new_type,
              subject: "",
              userset_namespace: "",
              userset_object_id: "",
              userset_relation: ""
          }
        else
          row
        end
      end)

    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event(
        "update_row_userset",
        %{"idx" => idx, "field" => field, "value" => value},
        socket
      ) do
    idx = String.to_integer(idx)
    rows = update_row_at(socket.assigns.rows, idx, field, value)
    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("update_filter", %{"field" => field, "value" => value}, socket) do
    {:noreply,
     assign(socket,
       read_filter: Map.put(socket.assigns.read_filter, String.to_existing_atom(field), value)
     )}
  end

  def handle_event("toggle_filter_subject", _, socket) do
    current = socket.assigns.subject_type
    new_type = if current == "user", do: "userset", else: "user"

    {:noreply,
     assign(socket,
       subject_type: new_type,
       read_filter:
         Map.merge(socket.assigns.read_filter, %{
           subject: "",
           userset_namespace: "",
           userset_object_id: "",
           userset_relation: ""
         })
     )}
  end

  def handle_event("update_filter_userset", %{"field" => field, "value" => value}, socket) do
    {:noreply,
     assign(socket,
       read_filter: Map.put(socket.assigns.read_filter, String.to_existing_atom(field), value)
     )}
  end

  def handle_event("update_zookie", %{"value" => value}, socket) do
    {:noreply, assign(socket, zookie: value)}
  end

  def handle_event("write_tuples", _, socket) do
    %{selected_tenant_id: tid, rows: rows} = socket.assigns

    cond do
      tid == "" ->
        {:noreply, assign(socket, error: "Select a tenant first")}

      true ->
        tuples = build_tuples_from_rows(rows)

        if tuples == [] do
          {:noreply, assign(socket, error: "No valid tuples to write")}
        else
          case Tuples.write(tid, tuples) do
            {:ok, result} ->
              {:noreply,
               assign(socket,
                 results: result,
                 rows: [new_row()],
                 error: nil
               )}

            {:error, reason} ->
              {:noreply, assign(socket, error: "Write failed: #{inspect(reason)}")}
          end
        end
    end
  end

  def handle_event("read_tuples", _, socket) do
    %{selected_tenant_id: tid, read_filter: filter, subject_type: subj_type, zookie: zookie} =
      socket.assigns

    cond do
      tid == "" ->
        {:noreply, assign(socket, error: "Select a tenant first")}

      true ->
        query_filter = build_read_filter(filter, subj_type)
        opts = if zookie != "", do: [consistency: zookie], else: []
        result = Tuples.read(tid, query_filter, opts)

        {:noreply,
         assign(socket, result_tuples: result, results: nil, json_export: nil, error: nil)}
    end
  end

  def handle_event("delete_tuples", _, socket) do
    %{selected_tenant_id: tid, rows: rows} = socket.assigns

    cond do
      tid == "" ->
        {:noreply, assign(socket, error: "Select a tenant first")}

      true ->
        tuples = build_tuples_from_rows(rows)

        if tuples == [] do
          {:noreply, assign(socket, error: "No valid tuples to delete")}
        else
          case Tuples.delete(tid, tuples) do
            {:ok, result} ->
              {:noreply,
               assign(socket,
                 results: result,
                 rows: [new_row()],
                 error: nil
               )}

            {:error, reason} ->
              {:noreply, assign(socket, error: "Delete failed: #{inspect(reason)}")}
          end
        end
    end
  end

  def handle_event("export_json", _, socket) do
    json = Jason.encode!(socket.assigns.result_tuples, pretty: true)
    {:noreply, assign(socket, json_export: json)}
  end

  def handle_event("dismiss_json", _, socket) do
    {:noreply, assign(socket, json_export: nil)}
  end

  defp new_row do
    %{
      namespace: "",
      object_id: "",
      relation: "",
      subject: "",
      subject_type: "user",
      userset_namespace: "",
      userset_object_id: "",
      userset_relation: ""
    }
  end

  defp update_row_at(rows, idx, field, value) do
    rows
    |> Enum.with_index()
    |> Enum.map(fn {row, i} ->
      if i == idx, do: Map.put(row, String.to_existing_atom(field), value), else: row
    end)
  end

  defp build_tuples_from_rows(rows) do
    rows
    |> Enum.filter(fn r -> r.namespace != "" and r.object_id != "" and r.relation != "" end)
    |> Enum.map(fn r ->
      subject =
        case r.subject_type do
          "userset" ->
            {:userset, r.userset_namespace, r.userset_object_id, r.userset_relation}

          _ ->
            if String.contains?(r.subject, ":") do
              {:user, r.subject}
            else
              r.subject
            end
        end

      %{namespace: r.namespace, object_id: r.object_id, relation: r.relation, subject: subject}
    end)
    |> Enum.filter(fn t -> valid_tuple_subject?(t.subject) end)
  end

  defp valid_tuple_subject?({:user, uid}) when is_binary(uid) and uid != "", do: true

  defp valid_tuple_subject?({:userset, ns, oid, rel})
       when is_binary(ns) and ns != "" and is_binary(oid) and oid != "" and is_binary(rel) and
              rel != "",
       do: true

  defp valid_tuple_subject?(uid) when is_binary(uid) and uid != "", do: true
  defp valid_tuple_subject?(_), do: false

  defp build_read_filter(filter, subject_type) do
    base = %{}

    base = if filter.namespace != "", do: Map.put(base, :namespace, filter.namespace), else: base
    base = if filter.object_id != "", do: Map.put(base, :object_id, filter.object_id), else: base
    base = if filter.relation != "", do: Map.put(base, :relation, filter.relation), else: base

    case subject_type do
      "user" ->
        if filter.subject != "" do
          subject =
            if String.contains?(filter.subject, ":") do
              {:user, filter.subject}
            else
              filter.subject
            end

          Map.put(base, :subject, subject)
        else
          base
        end

      "userset" ->
        if filter.userset_namespace != "" and filter.userset_object_id != "" and
             filter.userset_relation != "" do
          Map.put(
            base,
            :subject,
            {:userset, filter.userset_namespace, filter.userset_object_id,
             filter.userset_relation}
          )
        else
          base
        end
    end
  end

  defp format_subject({:user, uid}), do: "user:#{uid}"
  defp format_subject({:userset, ns, oid, rel}), do: "#{ns}:#{oid}##{rel}"
end
