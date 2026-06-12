defmodule ZevalWeb.DashboardLive.TenantLive do
  use ZevalWeb, :live_view

  alias ZevalCore.Tenants
  alias ZevalWeb.ChangesetError

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active: "tenants",
       page_title: "Zeval Engine — Tenants",
       tenants: Tenants.list_for_user(socket.assigns.current_user.id),
       show_create: false,
       new_name: "",
       error: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-stack-lg">
      <div class="flex items-end justify-between">
        <div>
          <nav class="flex items-center gap-2 font-label-mono text-label-mono mb-stack-xs">
            <span class="text-text-muted">Zeval Engine</span>
            <span class="text-text-muted">/</span>
            <span class="text-text-primary">Tenants</span>
          </nav>
          <h2 class="font-headline-lg text-headline-lg text-text-primary">Tenants Management</h2>
          <p class="text-text-secondary font-body-md text-body-md mt-1">Manage isolated environments and their associated resources.</p>
        </div>
        <button
          phx-click="show_create"
          class="bg-emerald-success text-background px-stack-md py-2 font-label-mono text-label-mono font-bold flex items-center gap-2 hover:opacity-90 transition-opacity"
        >
          <span class="material-symbols-outlined">add</span>
          New Tenant
        </button>
      </div>

      <%= if @show_create do %>
        <div class="bg-surface border border-border-subtle p-stack-md">
          <h3 class="font-headline-md text-headline-md text-text-primary mb-stack-md">Create Tenant</h3>
          <%= if @error do %>
            <div class="bg-ruby-error/10 border border-ruby-error/30 text-ruby-error px-stack-md py-stack-sm font-label-mono text-label-mono mb-stack-md">{@error}</div>
          <% end %>
          <form phx-submit="create">
            <div class="flex gap-3 items-end">
              <div class="flex-1">
                <label class="block font-label-mono text-label-mono text-text-muted mb-stack-xs">Name</label>
                <input
                  type="text"
                  name="name"
                  phx-keyup="update_name"
                  phx-debounce="200"
                  class="w-full bg-surface-container-lowest border border-border-subtle font-label-mono text-label-mono text-text-primary px-3 py-2 focus:border-white focus:ring-0 transition-colors"
                  placeholder="my-org"
                />
              </div>
              <button
                type="submit"
                phx-disable-with="Creating..."
                class="bg-emerald-success text-background px-stack-md py-2 font-label-mono text-label-mono font-bold"
              >
                Create
              </button>
              <button
                type="button"
                phx-click="hide_create"
                class="border border-border-subtle text-text-secondary px-stack-md py-2 font-label-mono text-label-mono hover:text-text-primary transition-colors"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      <% end %>

      <div class="grid grid-cols-1 md:grid-cols-4 gap-gutter">
        <div class="bg-surface border border-border-subtle p-stack-md">
          <p class="font-label-mono text-label-mono text-text-muted uppercase mb-1">Total Tenants</p>
          <p class="font-headline-lg text-headline-lg text-emerald-success">{length(@tenants)}</p>
        </div>
        <div class="bg-surface border border-border-subtle p-stack-md">
          <p class="font-label-mono text-label-mono text-text-muted uppercase mb-1">Active Namespaces</p>
          <p class="font-headline-lg text-headline-lg text-text-primary">-</p>
        </div>
        <div class="bg-surface border border-border-subtle p-stack-md">
          <p class="font-label-mono text-label-mono text-text-muted uppercase mb-1">Service Accounts</p>
          <p class="font-headline-lg text-headline-lg text-text-primary">-</p>
        </div>
        <div class="bg-surface border border-border-subtle p-stack-md">
          <p class="font-label-mono text-label-mono text-text-muted uppercase mb-1">System Health</p>
          <div class="flex items-center gap-2 mt-2">
            <span class="w-3 h-3 rounded-full bg-emerald-success"></span>
            <span class="font-label-mono text-label-mono text-emerald-success uppercase">Operational</span>
          </div>
        </div>
      </div>

      <div class="bg-surface border border-border-subtle overflow-hidden">
        <div class="overflow-x-auto custom-scrollbar">
          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="bg-surface-container-low border-b border-border-subtle">
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase">Name</th>
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase">Created Date</th>
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase">Tenant ID</th>
                <th class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-muted uppercase text-right">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-border-subtle">
              <%= for tenant <- @tenants do %>
                <tr class="hover:bg-surface-container-high transition-colors group">
                  <td class="px-stack-md py-stack-sm">
                    <a href={"/dashboard/tenants/#{tenant.id}"} class="flex items-center gap-3">
                      <div class="w-8 h-8 flex items-center justify-center bg-surface-container-highest border border-border-subtle font-label-mono text-primary text-sm uppercase">
                        {String.slice(tenant.name, 0, 2)}
                      </div>
                      <div>
                        <p class="font-body-md text-body-md text-text-primary">{tenant.name}</p>
                        <p class="font-label-mono text-[10px] text-text-muted">ID: {String.slice(tenant.id, 0, 12)}..</p>
                      </div>
                    </a>
                  </td>
                  <td class="px-stack-md py-stack-sm font-label-mono text-label-mono text-text-secondary">
                    <%= if tenant.inserted_at do %>
                      {Calendar.strftime(tenant.inserted_at, "%Y-%m-%d %H:%M")}
                    <% end %>
                  </td>
                  <td class="px-stack-md py-stack-sm font-code-block text-code-block text-text-muted">
                    {String.slice(tenant.id, 0, 8)}
                  </td>
                  <td class="px-stack-md py-stack-sm text-right">
                    <div class="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                      <a href={"/dashboard/tenants/#{tenant.id}"} class="p-1 text-text-muted hover:text-text-primary transition-colors" title="View Details">
                        <span class="material-symbols-outlined">visibility</span>
                      </a>
                      <button
                        phx-click="delete"
                        phx-value-id={tenant.id}
                        phx-confirm="Delete this tenant and all its data?"
                        class="p-1 text-text-muted hover:text-ruby-error transition-colors"
                        title="Delete Tenant"
                      >
                        <span class="material-symbols-outlined">delete</span>
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
              <%= if @tenants == [] do %>
                <tr>
                  <td colspan="4" class="px-stack-md py-stack-lg text-center font-body-md text-body-md text-text-muted">
                    No tenants yet. Create one to get started.
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
        <div class="px-stack-md py-stack-sm bg-surface-container-low border-t border-border-subtle flex items-center justify-between">
          <p class="font-label-mono text-label-mono text-text-muted">Showing {length(@tenants)} of {length(@tenants)} results</p>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("update_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, new_name: name)}
  end

  def handle_event("show_create", _, socket) do
    {:noreply, assign(socket, show_create: true, error: nil)}
  end

  def handle_event("hide_create", _, socket) do
    {:noreply, assign(socket, show_create: false, error: nil)}
  end

  def handle_event("create", %{"name" => name}, socket) when byte_size(name) < 2 do
    {:noreply, assign(socket, error: "Name must be at least 2 characters")}
  end

  def handle_event("create", %{"name" => name}, socket) do
    case Tenants.create_for_user(socket.assigns.current_user.id, name) do
      {:ok, _tenant} ->
        {:noreply,
         assign(socket,
           tenants: Tenants.list_for_user(socket.assigns.current_user.id),
           show_create: false,
           new_name: "",
           error: nil
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, error: ChangesetError.first(changeset))}

      {:error, _other} ->
        {:noreply, assign(socket, error: "Could not create tenant")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Tenants.delete_for_user(user_id, id) do
      {:ok, _} ->
        {:noreply, assign(socket, tenants: Tenants.list_for_user(user_id), error: nil)}

      {:error, :not_found} ->
        {:noreply, assign(socket, error: "Tenant not found")}
    end
  end
end
