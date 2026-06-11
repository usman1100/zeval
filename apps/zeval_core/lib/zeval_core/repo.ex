defmodule ZevalCore.Repo do
  use Ecto.Repo,
    otp_app: :zeval_core,
    adapter: Ecto.Adapters.Postgres
end
