defmodule ZevalWeb.Plugs.ValidateParams do
  @moduledoc """
  Validates API parameters against the engine's naming rules.

  Checks `namespace`, `object_id`, `relation`, and `name` params when
  present in the request body or path.
  """

  import Plug.Conn

  @namespace_regex ~r/^[a-z][a-z0-9_]{0,63}$/
  @relation_regex  ~r/^[a-z][a-z0-9_]{0,63}$/
  @object_id_regex ~r/^[a-zA-Z0-9_\-\.]{1,256}$/
  @user_id_regex   ~r/^[a-zA-Z0-9_\-\.@]{1,256}$/

  def init(opts), do: opts

  def call(conn, _opts) do
    params = conn.params

    with :ok <- check_field(params, "namespace", @namespace_regex),
         :ok <- check_field(params, "name", @namespace_regex),
         :ok <- check_field(params, "relation", @relation_regex),
         :ok <- check_field(params, "object_id", @object_id_regex),
         :ok <- check_field(params, "user_id", @user_id_regex),
         :ok <- check_field(params, "subject", @user_id_regex) do
      conn
    else
      {:error, field, msg} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: "invalid #{field}: #{msg}", code: "validation_error"}))
        |> halt()
    end
  end

  defp check_field(params, key, regex) do
    case params[key] do
      nil -> :ok
      val when is_binary(val) ->
        if Regex.match?(regex, val), do: :ok, else: {:error, key, "does not match required pattern"}
      _ -> :ok
    end
  end
end