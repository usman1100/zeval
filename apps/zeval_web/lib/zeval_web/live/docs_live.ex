defmodule ZevalWeb.DashboardLive.DocsLive do
  use ZevalWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active: "docs",
       page_title: "Zeval Engine — API Reference"
     )}
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
