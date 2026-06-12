defmodule ZevalWeb.Plugs.Session do
  @moduledoc """
  Runtime-configured session plug.

  Reads `:zeval_web, :session_options` at request time so the signing/
  encryption salts and the `secure` flag can be set from environment
  variables in `runtime.exs` (production) rather than baked into the
  compiled endpoint. Falls back to the dev defaults from `config.exs`.
  """

  @behaviour Plug

  @doc """
  The raw session options keyword list. Used both by this plug and by the
  LiveView socket's `connect_info: [session: {__MODULE__, :options, []}]` so
  the websocket can read the same session the HTTP request wrote.
  """
  def options, do: Application.fetch_env!(:zeval_web, :session_options)

  @impl true
  def init(_opts), do: nil

  @impl true
  def call(conn, _opts) do
    Plug.Session.call(conn, Plug.Session.init(options()))
  end
end
