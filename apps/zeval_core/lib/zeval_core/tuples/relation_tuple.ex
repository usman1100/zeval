defmodule ZevalCore.Tuples.RelationTuple do
  @moduledoc """
  Ecto schema for the `relation_tuples` table.

  This is the core data table in the Zanzibar model. Each row declares
  that a subject has a relation on an object.

  Soft-deletes via `deleted_at` so zookie-consistent reads can see
  historical state.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "relation_tuples" do
    field :tenant_id, :binary_id
    field :namespace, :string
    field :object_id, :string
    field :relation, :string
    field :subject_type, :string  # "user" or "userset"
    field :user_id, :string       # set when subject_type = "user"
    field :userset_namespace, :string
    field :userset_object_id, :string
    field :userset_relation, :string
    field :deleted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: false)
  end

  def changeset(%__MODULE__{} = tuple, attrs) do
    tuple
    |> cast(attrs, [
      :tenant_id, :namespace, :object_id, :relation,
      :subject_type, :user_id, :userset_namespace,
      :userset_object_id, :userset_relation
    ])
    |> validate_required([:tenant_id, :namespace, :object_id, :relation, :subject_type])
    |> validate_inclusion(:subject_type, ["user", "userset"])
  end
end