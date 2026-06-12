defmodule ZevalCore.Namespace do
  @moduledoc """
  Public API for managing namespace configurations.

  Every operation scopes to a tenant. The caller is responsible for
  providing the correct tenant_id — this module does not perform
  authorization checks (that's the plug layer's job).
  """

  import Ecto.Query, warn: false
  alias ZevalCore.Repo
  alias ZevalCore.Namespace.{NamespaceConfig, Cache, RuleValidator}

  @doc """
  Validates and writes a namespace config. Upserts by (tenant_id, name).
  Returns `{:ok, config}` or `{:error, changeset}`.
  """
  @spec write(binary(), map()) ::
          {:ok, NamespaceConfig.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def write(tenant_id, params) when is_map(params) do
    with {:ok, validated} <- RuleValidator.validate_config(params),
         config_name = validated["name"],
         existing <- get_record(tenant_id, config_name) do
      attrs = %{
        tenant_id: tenant_id,
        name: config_name,
        config: validated,
        version: ((existing && existing.version) || 0) + 1
      }

      result =
        if existing do
          existing
          |> NamespaceConfig.changeset(attrs)
          |> Repo.update()
        else
          %NamespaceConfig{}
          |> NamespaceConfig.changeset(attrs)
          |> Repo.insert()
        end

      case result do
        {:ok, config} ->
          Cache.put(tenant_id, config_name, config)
          {:ok, config}

        {:error, _} = error ->
          error
      end
    end
  end

  @doc """
  Gets a namespace config by tenant and name. Checks ETS cache first,
  falls back to DB on miss, and populates the cache.
  Returns `{:ok, config}` or `{:error, :not_found}`.
  """
  @spec get(binary(), String.t()) :: {:ok, NamespaceConfig.t()} | {:error, :not_found}
  def get(tenant_id, name) do
    case Cache.get(tenant_id, name) do
      nil ->
        case get_record(tenant_id, name) do
          nil ->
            {:error, :not_found}

          config ->
            Cache.put(tenant_id, name, config)
            {:ok, config}
        end

      config ->
        {:ok, config}
    end
  end

  @doc """
  Lists all namespace configs for a tenant.
  """
  @spec list(binary()) :: [NamespaceConfig.t()]
  def list(tenant_id) do
    Repo.all(from(c in NamespaceConfig, where: c.tenant_id == ^tenant_id, order_by: c.name))
  end

  @doc """
  Gets a namespace config record by id, scoped to tenants the user belongs to.
  Returns the record or nil.
  """
  @spec get_record_for_user(binary(), binary()) :: NamespaceConfig.t() | nil
  def get_record_for_user(user_id, id) do
    Repo.one(
      from(c in NamespaceConfig,
        join: m in ZevalCore.TenantMembership,
        on: m.tenant_id == c.tenant_id,
        where: c.id == ^id and m.user_id == ^user_id
      )
    )
  end

  @doc """
  Lists namespace configs across every tenant the user belongs to, as plain
  maps including the tenant name (for dashboard listing). Optionally filtered
  to a single tenant the user must also belong to.
  """
  @spec list_for_user(binary(), binary() | nil) :: [map()]
  def list_for_user(user_id, tenant_id \\ nil) do
    base =
      from(c in NamespaceConfig,
        join: t in ZevalCore.Tenant,
        on: t.id == c.tenant_id,
        join: m in ZevalCore.TenantMembership,
        on: m.tenant_id == c.tenant_id,
        where: m.user_id == ^user_id,
        order_by: [desc: c.inserted_at],
        select: %{
          id: c.id,
          name: c.name,
          version: c.version,
          inserted_at: c.inserted_at,
          tenant_id: c.tenant_id,
          tenant_name: t.name,
          config: c.config
        }
      )

    query = if tenant_id, do: from([c] in base, where: c.tenant_id == ^tenant_id), else: base
    Repo.all(query)
  end

  @doc """
  Deletes a namespace config. Returns `:ok` or `{:error, :not_found}`.
  """
  @spec delete(binary(), String.t()) :: :ok | {:error, :not_found}
  def delete(tenant_id, name) do
    case get_record(tenant_id, name) do
      nil ->
        {:error, :not_found}

      config ->
        Repo.delete!(config)
        Cache.invalidate(tenant_id, name)
        :ok
    end
  end

  # -- Private --

  defp get_record(tenant_id, name) do
    Repo.one(
      from(c in NamespaceConfig,
        where: c.tenant_id == ^tenant_id and c.name == ^name
      )
    )
  end
end
