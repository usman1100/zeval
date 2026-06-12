defmodule ZevalCore.Repo.Migrations.CreateServiceAccounts do
  use Ecto.Migration

  def change do
    create table(:service_accounts, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :key_hash, :text, null: false
      add :key_prefix, :text, null: false
      add :last_used_at, :timestamptz
      add :inserted_at, :timestamptz, null: false, default: fragment("now()")
      add :revoked_at, :timestamptz
    end

    create unique_index(:service_accounts, [:key_hash])
    create index(:service_accounts, [:tenant_id])
  end
end
