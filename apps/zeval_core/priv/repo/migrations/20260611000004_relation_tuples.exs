defmodule ZevalCore.Repo.Migrations.CreateRelationTuples do
  use Ecto.Migration

  def change do
    create table(:relation_tuples, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false
      add :namespace, :text, null: false
      add :object_id, :text, null: false
      add :relation, :text, null: false
      add :subject_type, :text, null: false
      add :user_id, :text
      add :userset_namespace, :text
      add :userset_object_id, :text
      add :userset_relation, :text
      add :inserted_at, :timestamptz, null: false, default: fragment("now()")
      add :deleted_at, :timestamptz
    end

    # Constraint: subject_type must be 'user' or 'userset'
    create constraint(:relation_tuples, :subject_type_check,
      check: "subject_type IN ('user', 'userset')")

    # Fast lookup by (tenant, namespace, object, relation) for active tuples
    create index(:relation_tuples, [:tenant_id, :namespace, :object_id, :relation],
      where: "deleted_at IS NULL",
      name: :idx_tuples_lookup)

    # Fast lookup by subject userset for tuple_to_userset resolution
    create index(:relation_tuples, [:tenant_id, :userset_namespace, :userset_object_id, :userset_relation],
      where: "deleted_at IS NULL AND subject_type = 'userset'",
      name: :idx_tuples_subject)
  end
end
