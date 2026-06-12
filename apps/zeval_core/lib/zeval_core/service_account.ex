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
  @type t :: %__MODULE__{}

  schema "service_accounts" do
    field(:tenant_id, :binary_id)
    field(:name, :string)
    field(:key_hash, :string)
    field(:key_prefix, :string)
    field(:last_used_at, :utc_datetime_usec)
    field(:revoked_at, :utc_datetime_usec)
    field(:created_by, :string)
    field(:revoked_by, :string)

    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: false)
  end

  def changeset(%__MODULE__{} = acct, attrs) do
    acct
    |> cast(attrs, [:tenant_id, :name, :key_hash, :key_prefix, :created_by])
    |> validate_required([:tenant_id, :name, :key_hash, :key_prefix])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:key_hash)
    |> unique_constraint(:name,
      name: :idx_service_accounts_active_name,
      message: "is already taken for this tenant"
    )
  end
end
