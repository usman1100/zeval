defmodule ZevalCore.Repo.Migrations.MembershipsAndCitextEmail do
  use Ecto.Migration

  def change do
    # Case-insensitive emails: "Admin@x.com" and "admin@x.com" are the same
    # account, and the existing unique index becomes case-insensitive.
    execute("CREATE EXTENSION IF NOT EXISTS citext", "DROP EXTENSION IF EXISTS citext")
    execute("ALTER TABLE dashboard_users ALTER COLUMN email TYPE citext",
            "ALTER TABLE dashboard_users ALTER COLUMN email TYPE text")

    # User <-> tenant membership: the dashboard authorization boundary.
    create table(:tenant_memberships, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      add :user_id,
          references(:dashboard_users, type: :uuid, on_delete: :delete_all),
          null: false

      add :tenant_id,
          references(:tenants, type: :uuid, on_delete: :delete_all),
          null: false

      add :role, :text, null: false, default: "owner"
      add :inserted_at, :timestamptz, null: false, default: fragment("now()")
    end

    create unique_index(:tenant_memberships, [:user_id, :tenant_id])
    create index(:tenant_memberships, [:tenant_id])
  end
end
