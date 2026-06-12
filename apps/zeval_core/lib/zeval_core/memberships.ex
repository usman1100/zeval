defmodule ZevalCore.Memberships do
  @moduledoc """
  Dashboard user ↔ tenant membership — the dashboard's authorization boundary.
  """

  import Ecto.Query, warn: false
  alias ZevalCore.{Repo, TenantMembership}

  @doc "Creates a membership linking a user to a tenant."
  @spec create(binary(), binary(), String.t()) ::
          {:ok, TenantMembership.t()} | {:error, Ecto.Changeset.t()}
  def create(user_id, tenant_id, role \\ "owner") do
    %TenantMembership{}
    |> TenantMembership.changeset(%{user_id: user_id, tenant_id: tenant_id, role: role})
    |> Repo.insert()
  end

  @doc "Returns true if the user is a member of the tenant."
  @spec member?(binary(), binary()) :: boolean()
  def member?(user_id, tenant_id) when is_binary(user_id) and is_binary(tenant_id) do
    Repo.exists?(
      from(m in TenantMembership,
        where: m.user_id == ^user_id and m.tenant_id == ^tenant_id
      )
    )
  end

  def member?(_, _), do: false

  @doc "Lists tenant_ids the user belongs to."
  @spec tenant_ids_for_user(binary()) :: [binary()]
  def tenant_ids_for_user(user_id) do
    Repo.all(from(m in TenantMembership, where: m.user_id == ^user_id, select: m.tenant_id))
  end
end
