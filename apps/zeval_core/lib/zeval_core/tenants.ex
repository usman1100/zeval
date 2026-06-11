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
end