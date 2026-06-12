# Seeds for development — creates an initial dashboard admin user.
#
# Usage: mix run priv/repo/seeds.exs

alias ZevalCore.{Repo, DashboardUser}

admin = %{
  email: "admin@zeval.dev",
  name: "Admin",
  password: "password123"
}

case Repo.get_by(DashboardUser, email: admin.email) do
  nil ->
    %DashboardUser{}
    |> DashboardUser.changeset(admin)
    |> Repo.insert!()
    |> then(fn user -> IO.puts("Created admin user: #{user.email} / password123") end)

  _user ->
    IO.puts("Admin user already exists: #{admin.email}")
end
