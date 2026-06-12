defmodule ZevalWeb.DashboardLive.NamespaceEditorLive do
  use ZevalWeb, :live_view
  import Phoenix.Component

  alias ZevalCore.{Namespace, Tenants, Memberships}
  alias ZevalCore.Namespace.RuleValidator
  alias ZevalWeb.ChangesetError

  def mount(%{"id" => id}, _session, socket) do
    user_id = socket.assigns.current_user.id

    case Namespace.get_record_for_user(user_id, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Namespace not found")
         |> redirect(to: "/dashboard/namespaces")}

      ns ->
        form = config_to_form(ns.name, ns.config, ns.tenant_id)

        {:ok,
         assign(socket,
           active: "namespaces",
           page_title: "Zeval Engine — Edit #{ns.name}",
           mode: :visual,
           namespace_name: ns.name,
           tenant_id: ns.tenant_id,
           relations: form.relations,
           json_text: Jason.encode!(ns.config, pretty: true),
           error: nil,
           saved: false,
           tenants: Tenants.list_for_user(user_id)
         )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       active: "namespaces",
       page_title: "Zeval Engine — New Namespace",
       mode: :visual,
       namespace_name: "",
       tenant_id: "",
       relations: [],
       json_text: ~s({\n  "name": "",\n  "relations": {}\n}),
       error: nil,
       saved: false,
       tenants: Tenants.list_for_user(socket.assigns.current_user.id)
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h2 class="text-2xl font-bold text-white">
        <%= if @namespace_name == "", do: "New Namespace", else: "Edit: #{@namespace_name}" %>
      </h2>
      <div class="flex gap-2">
        <button
          phx-click="switch_mode"
          class="bg-gray-700 hover:bg-gray-600 text-white px-4 py-2 rounded-lg text-sm font-medium"
        >
          <%= if @mode == :visual, do: "Switch to JSON", else: "Switch to Visual" %>
        </button>
      </div>
    </div>

    <%= if @error do %>
      <div class="bg-red-900/50 border border-red-700 text-red-300 px-4 py-3 rounded-lg mb-4 text-sm">{@error}</div>
    <% end %>

    <%= if @saved do %>
      <div class="bg-green-900/50 border border-green-700 text-green-300 px-4 py-3 rounded-lg mb-4 text-sm">
        Namespace saved successfully!
        <a href="/dashboard/namespaces" class="underline ml-2">Back to list</a>
      </div>
    <% end %>

    <%= if @mode == :visual do %>
      <.visual_editor
        namespace_name={@namespace_name}
        tenant_id={@tenant_id}
        tenants={@tenants}
        relations={@relations}
        saved={@saved}
      />
    <% else %>
      <.json_editor json_text={@json_text} saved={@saved} />
    <% end %>

    <form id="editor-form"></form>
    """
  end

  attr(:namespace_name, :string, required: true)
  attr(:tenant_id, :string, required: true)
  attr(:tenants, :list, required: true)
  attr(:relations, :list, required: true)
  attr(:saved, :boolean, required: true)

  def visual_editor(assigns) do
    ~H"""
      <div class="space-y-6">
        <div class="bg-gray-900 border border-gray-700 rounded-xl p-6">
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-300 mb-1">Namespace Name</label>
            <input type="text" name="namespace_name" form="editor-form" phx-keyup="set_namespace_name" phx-debounce="200"
              value={@namespace_name}
              class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white"
              placeholder="doc" />
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-300 mb-1">Tenant</label>
          <select name="tenant_id" form="editor-form" phx-change="set_tenant"
            class="w-full bg-gray-800 border border-gray-600 rounded-lg px-3 py-2 text-sm text-white">
            <option value="">Select a tenant</option>
            <%= for t <- @tenants do %>
              <option value={t.id} selected={@tenant_id == t.id}><%= t.name %></option>
            <% end %>
          </select>
        </div>
      </div>

      <div class="bg-gray-900 border border-gray-700 rounded-xl p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-white">Relations</h3>
          <button phx-click="add_relation"
            class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1.5 rounded-lg text-sm font-medium">
            + Add Relation
          </button>
        </div>

        <%= if @relations == [] do %>
          <p class="text-gray-500 text-sm">No relations defined. Add one to get started.</p>
        <% end %>

        <div class="space-y-4">
          <%= for rel <- @relations do %>
            <.relation_card rel={rel} />
          <% end %>
        </div>
      </div>

      <div class="flex gap-3">
        <button phx-click="save" phx-disable-with="Saving..."
          class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium">
          Save
        </button>
        <a href="/dashboard/namespaces"
          class="bg-gray-700 hover:bg-gray-600 text-gray-300 px-4 py-2 rounded-lg text-sm">
          Cancel
        </a>
      </div>
    </div>
    """
  end

  attr(:rel, :map, required: true)

  def relation_card(assigns) do
    ~H"""
    <div class="bg-gray-800 border border-gray-600 rounded-lg p-4">
      <div class="flex items-center justify-between mb-3">
        <div class="flex-1 mr-3">
          <label class="block text-xs font-medium text-gray-400 mb-0.5">Relation Name</label>
          <input type="text" name="relation_name" form="editor-form" phx-keyup="set_relation_name" phx-value-rel-id={@rel.id} phx-debounce="200"
            value={@rel.name}
            class="w-full bg-gray-950 border border-gray-600 rounded px-2 py-1.5 text-sm text-white font-mono"
            placeholder="viewer" />
        </div>
        <button phx-click="remove_relation" phx-value-rel-id={@rel.id}
          class="text-red-400 hover:text-red-300 text-sm shrink-0">Remove</button>
      </div>
      <.rule_block rule={@rel.rule} depth={0} />
    </div>
    """
  end

  attr(:rule, :map, required: true)
  attr(:depth, :integer, required: true)

  def rule_block(assigns) do
    ~H"""
    <div class="border-l-2 border-gray-600 pl-4 ml-0" style={"margin-left: #{@depth * 12}px"}>
      <div class="flex items-center gap-2 mb-2">
        <label class="text-xs font-medium text-gray-400">Type</label>
        <select name="rule_type" form="editor-form" phx-change="rule_set_type" phx-value-rule-id={@rule.id}
          class="bg-gray-950 border border-gray-600 rounded px-2 py-1 text-sm text-white">
          <option value="this" selected={@rule.type == "this"}>this</option>
          <option value="computed_userset" selected={@rule.type == "computed_userset"}>computed_userset</option>
          <option value="tuple_to_userset" selected={@rule.type == "tuple_to_userset"}>tuple_to_userset</option>
          <option value="union" selected={@rule.type == "union"}>union</option>
          <option value="intersection" selected={@rule.type == "intersection"}>intersection</option>
          <option value="exclusion" selected={@rule.type == "exclusion"}>exclusion</option>
        </select>
      </div>

      <%= if @rule.type == "computed_userset" do %>
        <.param_input rule_id={@rule.id} param="relation" value={@rule.params["relation"]} label="Relation" />
      <% end %>

      <%= if @rule.type == "tuple_to_userset" do %>
        <.param_input rule_id={@rule.id} param="tupleset_relation" value={@rule.params["tupleset_relation"]} label="Tupleset Relation" />
        <.param_input rule_id={@rule.id} param="computed_userset_relation" value={@rule.params["computed_userset_relation"]} label="Computed Userset Relation" />
      <% end %>

      <%= if @rule.type == "union" or @rule.type == "intersection" do %>
        <div class="space-y-2 mt-2">
          <%= for child <- @rule.children do %>
            <div class="relative group">
              <.rule_block rule={child} depth={@depth + 1} />
              <button phx-click="rule_remove_child" phx-value-rule-id={child.id} phx-value-parent-id={@rule.id}
                class="absolute -top-1 -right-1 bg-red-800 hover:bg-red-700 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity">
                &times;
              </button>
            </div>
          <% end %>
          <button phx-click="rule_add_child" phx-value-rule-id={@rule.id}
            class="text-blue-400 hover:text-blue-300 text-xs">+ Add child</button>
        </div>
      <% end %>

      <%= if @rule.type == "exclusion" do %>
        <div class="mt-2 space-y-2">
          <div class="text-xs font-medium text-gray-400 mb-1">Base</div>
          <div class="relative group">
            <.rule_block rule={@rule.base} depth={@depth + 1} />
            <button phx-click="rule_remove_child" phx-value-rule-id={@rule.base.id} phx-value-parent-id={@rule.id}
              class="absolute -top-1 -right-1 bg-red-800 hover:bg-red-700 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity">
              &times;
            </button>
          </div>
          <div class="text-xs font-medium text-gray-400 mb-1">Subtract</div>
          <div class="relative group">
            <.rule_block rule={@rule.subtract} depth={@depth + 1} />
            <button phx-click="rule_remove_child" phx-value-rule-id={@rule.subtract.id} phx-value-parent-id={@rule.id}
              class="absolute -top-1 -right-1 bg-red-800 hover:bg-red-700 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity">
              &times;
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr(:rule_id, :string, required: true)
  attr(:param, :string, required: true)
  attr(:value, :string, default: "")
  attr(:label, :string, required: true)

  def param_input(assigns) do
    ~H"""
    <div class="mb-2">
      <label class="block text-xs font-medium text-gray-400 mb-0.5"><%= @label %></label>
      <input type="text" name="rule_param" form="editor-form" phx-keyup="rule_set_param" phx-value-rule-id={@rule_id} phx-value-param={@param} phx-debounce="200"
        value={@value}
        class="w-full bg-gray-950 border border-gray-600 rounded px-2 py-1.5 text-sm text-white font-mono"
        placeholder={@label} />
    </div>
    """
  end

  attr(:json_text, :string, required: true)
  attr(:saved, :boolean, required: true)

  def json_editor(assigns) do
    ~H"""
    <div class="bg-gray-900 border border-gray-700 rounded-xl p-6">
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-300 mb-1">Raw JSON Configuration</label>
        <textarea name="json_text" form="editor-form" phx-change="json_change"
          class="w-full bg-gray-950 border border-gray-600 rounded-lg px-3 py-2 text-sm font-mono text-green-300 min-h-[400px]"
          placeholder="{ &quot;name&quot;: &quot;doc&quot;, &quot;relations&quot;: { ... } }"><%= @json_text %></textarea>
      </div>
      <div class="flex gap-3">
        <button phx-click="save_json"
          class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium">Save</button>
        <button phx-click="json_validate"
          class="bg-gray-700 hover:bg-gray-600 text-gray-300 px-4 py-2 rounded-lg text-sm">Validate</button>
        <a href="/dashboard/namespaces"
          class="bg-gray-700 hover:bg-gray-600 text-gray-300 px-4 py-2 rounded-lg text-sm">Cancel</a>
      </div>
    </div>
    """
  end

  def handle_event("switch_mode", _, socket) do
    case socket.assigns.mode do
      :visual ->
        config = form_to_config(socket.assigns)
        json = Jason.encode!(config, pretty: true)
        {:noreply, assign(socket, mode: :json, json_text: json)}

      :json ->
        case Jason.decode(socket.assigns.json_text) do
          {:ok, config} ->
            case RuleValidator.validate_config(config) do
              {:ok, _} ->
                form =
                  config_to_form(
                    config["name"] || "",
                    config,
                    socket.assigns.tenant_id
                  )

                {:noreply,
                 assign(socket,
                   mode: :visual,
                   namespace_name: config["name"] || "",
                   relations: form.relations,
                   error: nil
                 )}

              {:error, reason} ->
                {:noreply, assign(socket, error: reason)}
            end

          {:error, _} ->
            {:noreply, assign(socket, error: "Invalid JSON")}
        end
    end
  end

  def handle_event("set_namespace_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, namespace_name: name)}
  end

  def handle_event("set_tenant", %{"tenant_id" => id}, socket) do
    {:noreply, assign(socket, tenant_id: id)}
  end

  def handle_event("add_relation", _, socket) do
    rel = %{
      id: Ecto.UUID.generate(),
      name: "",
      rule: %{
        id: Ecto.UUID.generate(),
        type: "this",
        params: %{},
        children: [],
        base: nil,
        subtract: nil
      }
    }

    {:noreply, assign(socket, relations: socket.assigns.relations ++ [rel])}
  end

  def handle_event("remove_relation", %{"rel-id" => rel_id}, socket) do
    rels = Enum.reject(socket.assigns.relations, fn r -> r.id == rel_id end)
    {:noreply, assign(socket, relations: rels)}
  end

  def handle_event("set_relation_name", %{"rel-id" => rel_id, "value" => name}, socket) do
    rels =
      Enum.map(socket.assigns.relations, fn r ->
        if r.id == rel_id, do: %{r | name: name}, else: r
      end)

    {:noreply, assign(socket, relations: rels)}
  end

  def handle_event("rule_set_type", %{"rule-id" => rule_id, "rule_type" => type}, socket) do
    updater = fn rule ->
      base =
        if type == "exclusion" do
          %{
            id: Ecto.UUID.generate(),
            type: "this",
            params: %{},
            children: [],
            base: nil,
            subtract: nil
          }
        else
          nil
        end

      subtract =
        if type == "exclusion" do
          %{
            id: Ecto.UUID.generate(),
            type: "this",
            params: %{},
            children: [],
            base: nil,
            subtract: nil
          }
        else
          nil
        end

      %{
        rule
        | type: type,
          params: %{},
          children: if(type in ["union", "intersection"], do: [], else: rule.children || []),
          base: base,
          subtract: subtract
      }
    end

    rels = update_rule_in_relations(socket.assigns.relations, rule_id, updater)
    {:noreply, assign(socket, relations: rels)}
  end

  def handle_event(
        "rule_set_param",
        %{"rule-id" => rule_id, "param" => param, "value" => value},
        socket
      ) do
    updater = fn rule ->
      %{rule | params: Map.put(rule.params || %{}, param, value)}
    end

    rels = update_rule_in_relations(socket.assigns.relations, rule_id, updater)
    {:noreply, assign(socket, relations: rels)}
  end

  def handle_event("rule_add_child", %{"rule-id" => rule_id}, socket) do
    child = %{
      id: Ecto.UUID.generate(),
      type: "this",
      params: %{},
      children: [],
      base: nil,
      subtract: nil
    }

    updater = fn rule ->
      if rule.type in ["union", "intersection"] do
        %{rule | children: rule.children ++ [child]}
      else
        rule
      end
    end

    rels = update_rule_in_relations(socket.assigns.relations, rule_id, updater)
    {:noreply, assign(socket, relations: rels)}
  end

  def handle_event(
        "rule_remove_child",
        %{"rule-id" => child_id, "parent-id" => parent_id},
        socket
      ) do
    updater = fn rule ->
      rule
      |> Map.put(:children, Enum.reject(rule.children || [], fn c -> c.id == child_id end))
      |> Map.update(:base, nil, fn b -> if b && b.id == child_id, do: nil, else: b end)
      |> Map.update(:subtract, nil, fn s -> if s && s.id == child_id, do: nil, else: s end)
    end

    rels = update_rule_in_relations(socket.assigns.relations, parent_id, updater)
    {:noreply, assign(socket, relations: rels)}
  end

  def handle_event("save", _, socket) do
    %{namespace_name: name, tenant_id: tid, relations: rels} = socket.assigns

    cond do
      name == "" or tid == "" ->
        {:noreply, assign(socket, error: "Namespace name and tenant are required")}

      not Memberships.member?(socket.assigns.current_user.id, tid) ->
        {:noreply, assign(socket, error: "You do not have access to that tenant")}

      true ->
        config = form_to_config(%{namespace_name: name, relations: rels})
        save_config(socket, tid, config)
    end
  end

  def handle_event("json_change", %{"json_text" => text}, socket) do
    {:noreply, assign(socket, json_text: text)}
  end

  def handle_event("json_validate", _, socket) do
    case Jason.decode(socket.assigns.json_text) do
      {:ok, config} ->
        case RuleValidator.validate_config(config) do
          {:ok, _} ->
            {:noreply, assign(socket, error: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, error: reason)}
        end

      {:error, _} ->
        {:noreply, assign(socket, error: "Invalid JSON")}
    end
  end

  def handle_event("save_json", _, socket) do
    case Jason.decode(socket.assigns.json_text) do
      {:ok, config} ->
        tid = socket.assigns.tenant_id

        cond do
          tid == "" ->
            {:noreply, assign(socket, error: "Select a tenant first (switch to Visual mode)")}

          not Memberships.member?(socket.assigns.current_user.id, tid) ->
            {:noreply, assign(socket, error: "You do not have access to that tenant")}

          true ->
            save_config(socket, tid, config)
        end

      {:error, _} ->
        {:noreply, assign(socket, error: "Invalid JSON")}
    end
  end

  defp save_config(socket, tid, config) do
    case Namespace.write(tid, config) do
      {:ok, _ns} ->
        {:noreply, assign(socket, saved: true, error: nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, error: ChangesetError.first(changeset))}

      {:error, reason} when is_binary(reason) ->
        {:noreply, assign(socket, error: reason)}

      {:error, _} ->
        {:noreply, assign(socket, error: "Could not save namespace")}
    end
  end

  defp config_to_form(name, config, tenant_id) do
    relations =
      (config["relations"] || %{})
      |> Enum.map(fn {rel_name, rule} ->
        %{id: Ecto.UUID.generate(), name: rel_name, rule: rule_to_form(rule)}
      end)

    %{namespace_name: name, tenant_id: tenant_id, relations: relations}
  end

  defp rule_to_form(%{"this" => _}) do
    %{id: Ecto.UUID.generate(), type: "this", params: %{}, children: [], base: nil, subtract: nil}
  end

  defp rule_to_form(%{"computed_userset" => %{"relation" => rel}}) do
    %{
      id: Ecto.UUID.generate(),
      type: "computed_userset",
      params: %{"relation" => rel},
      children: [],
      base: nil,
      subtract: nil
    }
  end

  defp rule_to_form(%{"tuple_to_userset" => params}) do
    %{
      id: Ecto.UUID.generate(),
      type: "tuple_to_userset",
      params: params,
      children: [],
      base: nil,
      subtract: nil
    }
  end

  defp rule_to_form(%{"union" => children}) do
    %{
      id: Ecto.UUID.generate(),
      type: "union",
      params: %{},
      children: Enum.map(children, &rule_to_form/1),
      base: nil,
      subtract: nil
    }
  end

  defp rule_to_form(%{"intersection" => children}) do
    %{
      id: Ecto.UUID.generate(),
      type: "intersection",
      params: %{},
      children: Enum.map(children, &rule_to_form/1),
      base: nil,
      subtract: nil
    }
  end

  defp rule_to_form(%{"exclusion" => %{"base" => base, "subtract" => subtract}}) do
    %{
      id: Ecto.UUID.generate(),
      type: "exclusion",
      params: %{},
      children: [],
      base: rule_to_form(base),
      subtract: rule_to_form(subtract)
    }
  end

  defp rule_to_form(_unknown) do
    %{id: Ecto.UUID.generate(), type: "this", params: %{}, children: [], base: nil, subtract: nil}
  end

  defp form_to_config(%{namespace_name: name, relations: rels}) do
    relations =
      rels
      |> Enum.filter(fn r -> r.name != "" end)
      |> Enum.map(fn r -> {r.name, rule_to_config(r.rule)} end)
      |> Map.new()

    %{"name" => name, "relations" => relations}
  end

  defp rule_to_config(%{type: "this"}) do
    %{"this" => %{}}
  end

  defp rule_to_config(%{type: "computed_userset", params: params}) do
    %{"computed_userset" => %{"relation" => Map.get(params, "relation", "")}}
  end

  defp rule_to_config(%{type: "tuple_to_userset", params: params}) do
    %{
      "tuple_to_userset" => %{
        "tupleset_relation" => Map.get(params, "tupleset_relation", ""),
        "computed_userset_relation" => Map.get(params, "computed_userset_relation", "")
      }
    }
  end

  defp rule_to_config(%{type: "union", children: children}) do
    %{"union" => Enum.map(children, &rule_to_config/1)}
  end

  defp rule_to_config(%{type: "intersection", children: children}) do
    %{"intersection" => Enum.map(children, &rule_to_config/1)}
  end

  defp rule_to_config(%{type: "exclusion", base: base, subtract: subtract}) do
    %{
      "exclusion" => %{
        "base" => rule_to_config(base),
        "subtract" => rule_to_config(subtract)
      }
    }
  end

  defp update_rule_in_relations(relations, rule_id, updater) do
    Enum.map(relations, fn rel ->
      %{rel | rule: update_rule_tree(rel.rule, rule_id, updater)}
    end)
  end

  defp update_rule_tree(%{id: id} = rule, target_id, updater) when id == target_id do
    updater.(rule)
  end

  defp update_rule_tree(rule, target_id, updater) do
    rule
    |> Map.update(:children, [], fn children ->
      Enum.map(children, fn c -> update_rule_tree(c, target_id, updater) end)
    end)
    |> Map.update(:base, nil, fn base ->
      if base, do: update_rule_tree(base, target_id, updater), else: nil
    end)
    |> Map.update(:subtract, nil, fn subtract ->
      if subtract, do: update_rule_tree(subtract, target_id, updater), else: nil
    end)
  end
end
