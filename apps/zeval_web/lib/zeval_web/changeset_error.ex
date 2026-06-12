defmodule ZevalWeb.ChangesetError do
  @moduledoc """
  Extracts a single human-readable message from a changeset for flash/error
  display, safely (no crashing on unexpected error shapes).
  """

  @doc "Returns the first validation error as `\"field: message\"`, or a fallback."
  @spec first(Ecto.Changeset.t(), String.t()) :: String.t()
  def first(%Ecto.Changeset{} = changeset, fallback \\ "Something went wrong") do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.find_value(fallback, fn
      {field, [msg | _]} -> "#{field}: #{msg}"
      _ -> nil
    end)
  end
end
