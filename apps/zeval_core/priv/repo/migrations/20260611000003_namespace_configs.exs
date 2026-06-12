defmodule ZevalCore.Repo.Migrations.CreateNamespaceConfigs do
  use Ecto.Migration

  def change do
    create table(:namespace_configs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :config, :jsonb, null: false
      add :version, :integer, null: false, default: 1
      add :inserted_at, :timestamptz, null: false, default: fragment("now()")
    end

    create unique_index(:namespace_configs, [:tenant_id, :name])
  end
end
