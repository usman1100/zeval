defmodule ZevalCore.Repo.Migrations.CreateDashboardUsers do
  use Ecto.Migration

  def change do
    create table(:dashboard_users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :text, null: false
      add :name, :text, null: false
      add :password_hash, :text, null: false
      add :inserted_at, :timestamptz, null: false, default: fragment("now()")
    end

    create unique_index(:dashboard_users, [:email])
  end
end
