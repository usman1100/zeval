defmodule ZevalCore.Tuples.Tuple do
  @moduledoc """
  Represents a single relation tuple in the authorization system.

  A tuple declares that a subject has a particular relation on an object.

  ## Subject types

    * `{:user, user_id}` — a direct user
    * `{:userset, namespace, object_id, relation}` — a userset (e.g. all
      members of a group)

  ## Examples

      %Tuple{namespace: "doc", object_id: "readme", relation: "viewer", subject: {:user, "alice"}}

      %Tuple{
        namespace: "doc", object_id: "readme", relation: "viewer",
        subject: {:userset, "group", "eng", "member"}
      }
  """

  @type subject :: {:user, String.t()} | {:userset, String.t(), String.t(), String.t()}

  @type t :: %__MODULE__{
          namespace: String.t(),
          object_id: String.t(),
          relation: String.t(),
          subject: subject()
        }

  defstruct [:namespace, :object_id, :relation, :subject]
end
