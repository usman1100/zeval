defmodule ZevalWeb.JsonHelpers do
  @moduledoc """
  Shared JSON helpers for consistent API responses.
  """

  import Plug.Conn

  @doc "Sends a JSON error response with the given status and message."
  def json_error(conn, status, message, code \\ nil) do
    body = %{error: message}
    body = if code, do: Map.put(body, :code, code), else: body

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
    |> halt()
  end

  @doc "Sends a 400 bad request error."
  def bad_request(conn, message \\ "bad request", code \\ "bad_request") do
    json_error(conn, 400, message, code)
  end

  @doc "Sends a 404 not found error."
  def not_found(conn, message \\ "not found", code \\ "not_found") do
    json_error(conn, 404, message, code)
  end

  @doc "Sends a 422 unprocessable entity error."
  def unprocessable(conn, changeset) do
    errors = format_changeset_errors(changeset)

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(422, Jason.encode!(%{error: "validation failed", code: "validation_error", details: errors}))
    |> halt()
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end