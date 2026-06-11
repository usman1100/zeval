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
  @spec write(binary(), map()) :: {:ok, NamespaceConfig.t()} | {:error, Ecto.Changeset.t()}
  def write(tenant_id, params) when is_map(params) do
    with {:ok, validated} <- RuleValidator.validate_config(params),
         config_name = validated["name"],
         existing <- get_record(tenant_id, config_name) do

      attrs = %{
        tenant_id: tenant_id,
        name: config_name,
        config: validated,
        version: (existing && existing.version || 0) + 1
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
          nil -> {:error, :not_found}
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
    Repo.all(from c in NamespaceConfig, where: c.tenant_id == ^tenant_id, order_by: c.name)
  end

  @doc """
  Deletes a namespace config. Returns `:ok` or `{:error, :not_found}`.
  """
  @spec delete(binary(), String.t()) :: :ok | {:error, :not_found}
  def delete(tenant_id, name) do
    case get_record(tenant_id, name) do
      nil -> {:error, :not_found}
      config ->
        Repo.delete!(config)
        Cache.invalidate(tenant_id, name)
        :ok
    end
  end

  # -- Private --

  defp get_record(tenant_id, name) do
    Repo.one(
      from c in NamespaceConfig,
        where: c.tenant_id == ^tenant_id and c.name == ^name
    )
  end
end
