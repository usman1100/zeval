ExUnit.start()

# zeval_web has no Repo of its own — it uses ZevalCore.Repo, which is started
# by the zeval_core application. Put it in manual sandbox mode for tests.
Ecto.Adapters.SQL.Sandbox.mode(ZevalCore.Repo, :manual)
