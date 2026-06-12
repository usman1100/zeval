defmodule ZevalWeb.Plugs.Session do
  @moduledoc """
  Runtime-configured session plug.

  Reads `:zeval_web, :session_options` at request time so the signing/
  encryption salts and the `secure` flag can be set from environment
  variables in `runtime.exs` (production) rather than baked into the
  compiled endpoint. Falls back to the dev defaults from `config.exs`.
  """

  @behaviour Plug

  @impl true
  def init(_opts), do: nil

  @impl true
  def call(conn, _opts) do
    opts =
      :zeval_web
      |> Application.fetch_env!(:session_options)
      |> Plug.Session.init()

    Plug.Session.call(conn, opts)
  end
end
