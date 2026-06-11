defmodule ZevalCore.Tuples.Parser do
  @moduledoc """
  Parses the Zanzibar shorthand tuple notation into `%Tuple{}` structs.

  ## Forms

      doc:readme#viewer@alice           # user subject
      doc:readme#viewer@group:eng#member  # userset subject

  The general grammar is:

      <namespace>:<object_id>#<relation>@<subject>
  """

  alias ZevalCore.Tuples.Tuple

  @doc """
  Parses a shorthand tuple string into a `%Tuple{}` struct.

  Returns `{:ok, %Tuple{}}` on success, `{:error, reason}` on malformed input.
  """
  @spec parse(String.t()) :: {:ok, Tuple.t()} | {:error, String.t()}
  def parse(shorthand) when is_binary(shorthand) do
    with {:ok, object_part, subject_part} <- split_object_and_subject(shorthand),
         {:ok, ns, obj, rel} <- parse_object_part(object_part),
         {:ok, subject} <- parse_subject(subject_part) do
      {:ok, %Tuple{namespace: ns, object_id: obj, relation: rel, subject: subject}}
    end
  end

  def parse(_), do: {:error, "input must be a string"}

  # Splits "doc:readme#viewer@alice" into object_part="doc:readme#viewer" and subject_part="alice"
  defp split_object_and_subject(shorthand) do
    case String.split(shorthand, "@", parts: 2) do
      [object_part, subject_part] when object_part != "" and subject_part != "" ->
        {:ok, object_part, subject_part}

      _ ->
        {:error, "malformed tuple: missing '@' separator or empty parts"}
    end
  end

  # Parses "doc:readme#viewer" into {"doc", "readme", "viewer"}
  defp parse_object_part(object_part) do
    case String.split(object_part, "#", parts: 2) do
      [ns_and_obj, relation] when relation != "" ->
        case String.split(ns_and_obj, ":", parts: 2) do
          [ns, obj] when ns != "" and obj != "" ->
            {:ok, ns, obj, relation}

          _ ->
            {:error, "malformed object part: expected <namespace>:<object_id>#<relation>"}
        end

      _ ->
        {:error, "malformed object part: missing '#' before relation"}
    end
  end

  # Parses the subject part.
  # If it contains ':' or '#', treat as userset: "group:eng#member"
  # Otherwise treat as direct user: "alice"
  defp parse_subject(subject_part) do
    if String.contains?(subject_part, ":") or String.contains?(subject_part, "#") do
      # Userset form: "group:eng#member"
      case String.split(subject_part, "#", parts: 2) do
        [ns_and_obj, relation] when relation != "" ->
          case String.split(ns_and_obj, ":", parts: 2) do
            [ns, obj] when ns != "" and obj != "" ->
              {:ok, {:userset, ns, obj, relation}}

            _ ->
              {:error, "malformed userset subject: expected <namespace>:<object_id>#<relation>"}
          end

        _ ->
          {:error, "malformed userset subject: missing '#'"}
      end
    else
      {:ok, {:user, subject_part}}
    end
  end
end