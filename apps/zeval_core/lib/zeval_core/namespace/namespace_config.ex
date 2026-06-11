defmodule ZevalCore.Namespace.NamespaceConfig do
  @moduledoc """
  Ecto schema for the namespace_configs table.

  The `config` column is stored as a JSONB map. We keep it as a raw map
  and validate it through `ZevalCore.Namespace.RuleValidator` rather than
  using Ecto embedded schemas for the nested structure.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "namespace_configs" do
    field :name, :string
    field :config, :map
    field :version, :integer, default: 1
    field :tenant_id, :binary_id

    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: false)
  end

  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:tenant_id, :name, :config, :version])
    |> validate_required([:tenant_id, :name, :config])
    |> unique_constraint([:tenant_id, :name], name: :namespace_configs_tenant_id_name_index)
  end
end
