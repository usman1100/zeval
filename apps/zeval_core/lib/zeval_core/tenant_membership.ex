defmodule ZevalCore.TenantMembership do
  @moduledoc """
  Join row linking a dashboard user to a tenant they may administer.

  Membership is the dashboard's authorization boundary: a user can only see
  and modify tenants they belong to.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @type t :: %__MODULE__{}

  @roles ~w(owner member)

  schema "tenant_memberships" do
    field(:user_id, :binary_id)
    field(:tenant_id, :binary_id)
    field(:role, :string, default: "owner")

    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: false)
  end

  def changeset(%__MODULE__{} = membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :tenant_id, :role])
    |> validate_required([:user_id, :tenant_id, :role])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:user_id, :tenant_id])
  end
end
