defmodule ZevalCore.Repo.Migrations.CreateZookies do
  use Ecto.Migration

  def change do
    # Zookies are opaque consistency tokens stored as raw text.
    # No id column — the token itself is the primary key.
    create table(:zookies, primary_key: false) do
      add :token, :text, primary_key: true, null: false
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :delete_all), null: false
      add :snapshot_at, :timestamptz, null: false, default: fragment("now()")
    end
  end
end
