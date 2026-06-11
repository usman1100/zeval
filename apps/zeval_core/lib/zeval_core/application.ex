defmodule ZevalCore.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ZevalCore.Repo
    ]

    opts = [strategy: :one_for_one, name: ZevalCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
