defmodule ZevalCore.Tenants do
  @moduledoc """
  Manages tenants — the top-level organizational unit.
  """
  import Ecto.Query, warn: false
  alias ZevalCore.{Repo, Tenant}

  @doc "Creates a new tenant."
  def create(name) when is_binary(name) do
    %Tenant{}
    |> Tenant.changeset(%{name: name})
    |> Repo.insert()
  end

  @doc "Gets a tenant by ID."
  def get(id), do: Repo.get(Tenant, id)

  @doc "Lists all tenants ordered by name."
  def list, do: Repo.all(from t in Tenant, order_by: t.name)

  @doc "Deletes a tenant by struct or ID."
  def delete(%Tenant{} = tenant), do: Repo.delete(tenant)
  def delete(id) do
    case get(id) do
      nil -> {:error, :not_found}
      tenant -> Repo.delete(tenant)
    end
  end
end