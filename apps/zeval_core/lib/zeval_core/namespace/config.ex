defmodule ZevalCore.Namespace.Config do
  @moduledoc """
  Embedded schema for namespace configuration.

  A namespace config defines the relationship graph for an authorization
  domain. Example config for a "doc" namespace:

      {
        "name": "doc",
        "relations": {
          "viewer": { "union": [
            { "this": {} },
            { "computed_userset": { "relation": "editor" } }
          ]},
          "editor": { "union": [
            { "this": {} },
            { "computed_userset": { "relation": "owner" } }
          ]},
          "owner": { "this": {} }
        }
      }
  """

  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field(:name, :string)
    embeds_many(:relations, ZevalCore.Namespace.Config.Relation)
  end

  defmodule Relation do
    @moduledoc false
    use Ecto.Schema

    embedded_schema do
      field(:name, :string)
      field(:rewrite, :map)
    end
  end

  @doc """
  Casts and validates a raw map into a Config struct.
  """
  def changeset(%__MODULE__{} = config, attrs) do
    config
    |> cast(attrs, [:name])
    |> cast_embed(:relations, with: &relation_changeset/2)
    |> validate_required([:name, :relations])
  end

  defp relation_changeset(relation, attrs) do
    relation
    |> cast(attrs, [:name, :rewrite])
    |> validate_required([:name, :rewrite])
  end
end
