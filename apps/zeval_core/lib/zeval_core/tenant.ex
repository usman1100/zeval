defmodule ZevalCore.Tenant do
  @moduledoc """
  Ecto schema for the `tenants` table.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "tenants" do
    field(:name, :string)
    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: false)
  end

  def changeset(%__MODULE__{} = tenant, attrs) do
    tenant
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
