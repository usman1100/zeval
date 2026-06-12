defmodule ZevalCore.Repo.Migrations.ServiceAccountAuditColumns do
  use Ecto.Migration

  def change do
    # Who created / revoked each key. Free-text actor descriptor, e.g.
    # "user:<uuid>" (dashboard) or "account:<uuid>" (API).
    alter table(:service_accounts) do
      add :created_by, :text
      add :revoked_by, :text
    end
  end
end
