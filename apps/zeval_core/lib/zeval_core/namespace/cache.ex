defmodule ZevalCore.Namespace.Cache do
  @moduledoc """
  ETS-backed cache for namespace configurations.

  Reads hit ETS first; on miss, the caller should populate from the DB.
  Provides get/put/invalidate operations keyed by `{tenant_id, name}`.

  Started as a GenServer in the supervision tree, but also works
  standalone — the ETS table is created lazily on first access.
  """

  use GenServer

  @table_name :namespace_cache

  # -- Client API --

  @doc "Retrieve a cached config, or nil on miss."
  def get(tenant_id, name) do
    ensure_table()

    case :ets.lookup(@table_name, cache_key(tenant_id, name)) do
      [{_, config}] -> config
      [] -> nil
    end
  end

  @doc "Store a config in the cache."
  def put(tenant_id, name, config) do
    ensure_table()
    :ets.insert(@table_name, {cache_key(tenant_id, name), config})
  end

  @doc "Remove a specific config from the cache."
  def invalidate(tenant_id, name) do
    ensure_table()
    :ets.delete(@table_name, cache_key(tenant_id, name))
  end

  @doc "Remove all configs for a tenant."
  def invalidate_tenant(tenant_id) do
    ensure_table()
    :ets.match_delete(@table_name, {{tenant_id, :_}, :_})
  end

  @doc "Flush the entire cache."
  def flush_all do
    ensure_table()
    :ets.delete_all_objects(@table_name)
  end

  # -- GenServer --

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    table = create_table()
    {:ok, %{table: table}}
  end

  # -- Private --

  defp ensure_table do
    case :ets.whereis(@table_name) do
      :undefined -> create_table()
      _ref -> :ok
    end
  end

  defp create_table do
    :ets.new(@table_name, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])
  rescue
    # Another process created the table between the whereis check and here.
    ArgumentError -> :ok
  end

  defp cache_key(tenant_id, name), do: {tenant_id, name}
end
