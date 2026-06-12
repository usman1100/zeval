defmodule ZevalCore.Repo.Migrations.TupleIntegrityAndIndexes do
  use Ecto.Migration

  def change do
    # Subject shape: exactly one of (user_id) / (userset triple) is populated,
    # matching subject_type. Prevents half-populated or mixed-subject rows.
    create constraint(:relation_tuples, :subject_shape_check,
             check: """
             (subject_type = 'user'
               AND user_id IS NOT NULL
               AND userset_namespace IS NULL
               AND userset_object_id IS NULL
               AND userset_relation IS NULL)
             OR
             (subject_type = 'userset'
               AND user_id IS NULL
               AND userset_namespace IS NOT NULL
               AND userset_object_id IS NOT NULL
               AND userset_relation IS NOT NULL)
             """
           )

    # Idempotent writes: at most one ACTIVE tuple per identity. Two partial
    # unique indexes (NULLs make a single combined index useless for usersets).
    create unique_index(
             :relation_tuples,
             [:tenant_id, :namespace, :object_id, :relation, :user_id],
             where: "deleted_at IS NULL AND subject_type = 'user'",
             name: :idx_tuples_unique_user
           )

    create unique_index(
             :relation_tuples,
             [
               :tenant_id,
               :namespace,
               :object_id,
               :relation,
               :userset_namespace,
               :userset_object_id,
               :userset_relation
             ],
             where: "deleted_at IS NULL AND subject_type = 'userset'",
             name: :idx_tuples_unique_userset
           )

    # Service accounts: unique name per tenant (active keys) + fast active lookup.
    create unique_index(:service_accounts, [:tenant_id, :name],
             where: "revoked_at IS NULL",
             name: :idx_service_accounts_active_name
           )

    create index(:service_accounts, [:key_hash],
             where: "revoked_at IS NULL",
             name: :idx_service_accounts_active_hash
           )
  end
end
