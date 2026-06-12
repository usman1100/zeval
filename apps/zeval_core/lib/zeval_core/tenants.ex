defmodule ZevalCore.Tenants do
  @moduledoc """
  Manages tenants — the top-level organizational unit.

  The `*_for_user` functions enforce the dashboard authorization boundary:
  a user may only see and mutate tenants they are a member of.
  """
  import Ecto.Query, warn: false
  alias ZevalCore.{Repo, Tenant, TenantMembership, Memberships}

  @doc "Creates a new tenant (no membership — API/bootstrap path)."
  def create(name) when is_binary(name) do
    %Tenant{}
    |> Tenant.changeset(%{name: name})
    |> Repo.insert()
  end

  @doc """
  Creates a tenant and an owner membership for `user_id`, atomically.
  """
  @spec create_for_user(binary(), String.t()) :: {:ok, Tenant.t()} | {:error, term()}
  def create_for_user(user_id, name) when is_binary(name) do
    Repo.transaction(fn ->
      case create(name) do
        {:ok, tenant} ->
          case Memberships.create(user_id, tenant.id, "owner") do
            {:ok, _} -> tenant
            {:error, changeset} -> Repo.rollback(changeset)
          end

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc "Gets a tenant by ID."
  def get(id), do: Repo.get(Tenant, id)

  @doc "Gets a tenant by ID only if `user_id` is a member, else nil."
  @spec get_for_user(binary(), binary()) :: Tenant.t() | nil
  def get_for_user(user_id, tenant_id) do
    Repo.one(
      from(t in Tenant,
        join: m in TenantMembership,
        on: m.tenant_id == t.id,
        where: t.id == ^tenant_id and m.user_id == ^user_id
      )
    )
  end

  @doc "Lists all tenants ordered by name (API/admin path)."
  def list, do: Repo.all(from(t in Tenant, order_by: t.name))

  @doc "Lists tenants the user is a member of, ordered by name."
  @spec list_for_user(binary()) :: [Tenant.t()]
  def list_for_user(user_id) do
    Repo.all(
      from(t in Tenant,
        join: m in TenantMembership,
        on: m.tenant_id == t.id,
        where: m.user_id == ^user_id,
        order_by: t.name
      )
    )
  end

  @doc "Deletes a tenant by struct or ID."
  def delete(%Tenant{} = tenant), do: Repo.delete(tenant)

  def delete(id) do
    case get(id) do
      nil -> {:error, :not_found}
      tenant -> Repo.delete(tenant)
    end
  end

  @doc "Deletes a tenant only if `user_id` is a member."
  @spec delete_for_user(binary(), binary()) :: {:ok, Tenant.t()} | {:error, :not_found}
  def delete_for_user(user_id, tenant_id) do
    case get_for_user(user_id, tenant_id) do
      nil -> {:error, :not_found}
      tenant -> Repo.delete(tenant)
    end
  end
end
