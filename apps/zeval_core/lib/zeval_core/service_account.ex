defmodule ZevalCore.ServiceAccount do
  @moduledoc """
  Ecto schema for the `service_accounts` table.

  API keys are stored hashed (SHA-256). The raw key is shown once on
  creation and never stored — same pattern as Stripe.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "service_accounts" do
    field :tenant_id, :binary_id
    field :name, :string
    field :key_hash, :string
    field :key_prefix, :string
    field :last_used_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: false)
  end

  def changeset(%__MODULE__{} = acct, attrs) do
    acct
    |> cast(attrs, [:tenant_id, :name, :key_hash, :key_prefix])
    |> validate_required([:tenant_id, :name, :key_hash, :key_prefix])
    |> unique_constraint(:key_hash)
  end
end