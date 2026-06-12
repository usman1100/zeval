# Seeds — creates an initial dashboard admin user from environment variables.
#
# Usage:
#   SEED_ADMIN_EMAIL=you@example.com SEED_ADMIN_PASSWORD=... mix run priv/repo/seeds.exs
#
# Refuses to run without both variables set, so there is never a hardcoded
# default-credentials backdoor. The password is never printed.

alias ZevalCore.{Repo, DashboardUser}

email = System.get_env("SEED_ADMIN_EMAIL")
password = System.get_env("SEED_ADMIN_PASSWORD")

cond do
  is_nil(email) or is_nil(password) ->
    IO.puts(:stderr, """
    Skipping admin seed: set SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD to create one.
    """)

  String.length(password) < 12 ->
    raise "SEED_ADMIN_PASSWORD must be at least 12 characters"

  true ->
    case Repo.get_by(DashboardUser, email: email) do
      nil ->
        %DashboardUser{}
        |> DashboardUser.changeset(%{email: email, name: "Admin", password: password})
        |> Repo.insert!()

        IO.puts("Created admin user: #{email}")

      _user ->
        IO.puts("Admin user already exists: #{email}")
    end
end
