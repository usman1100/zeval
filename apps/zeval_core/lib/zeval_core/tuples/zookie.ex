defmodule ZevalCore.Tuples.Zookie do
  @moduledoc """
  Consistency tokens (zookies) for read-your-writes semantics.

  A zookie records a point-in-time snapshot using Postgres's NOW()
  to avoid clock drift between the application and database.
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias ZevalCore.Repo

  @primary_key {:token, :string, []}
  schema "zookies" do
    field :tenant_id, :binary_id
    field :snapshot_at, :utc_datetime_usec
  end

  @doc """
  Mints a new zookie. Uses Postgres NOW() for the snapshot timestamp
  so it stays in sync with tuple `inserted_at` values.
  """
  @spec mint(binary()) :: {:ok, %__MODULE__{}}
  def mint(tenant_id) do
    token = "zookie:#{Ecto.UUID.generate()}"
    %Postgrex.Result{rows: [[%DateTime{} = now]]} =
      Repo.query!("SELECT NOW()", [])

    %__MODULE__{
      token: token,
      tenant_id: tenant_id,
      snapshot_at: now
    }
    |> change()
    |> then(&Repo.insert!(&1))
    |> then(&{:ok, &1})
  end

  @doc """
  Decodes a zookie token string into the zookie struct, or nil if not found.
  """
  @spec decode(binary()) :: %__MODULE__{} | nil
  def decode(token) when is_binary(token) do
    Repo.get(__MODULE__, token)
  end

  @doc """
  Mints a zookie with a specific snapshot_at time. Used in tests to create
  deterministic consistency tokens.
  """
  @spec mint_raw(binary(), DateTime.t(), String.t()) :: {:ok, %__MODULE__{}}
  def mint_raw(tenant_id, snapshot_at, token) do
    %__MODULE__{
      token: token,
      tenant_id: tenant_id,
      snapshot_at: snapshot_at
    }
    |> change()
    |> then(&Repo.insert!(&1))
    |> then(&{:ok, &1})
  end

  @doc """
  Returns the `snapshot_at` timestamp from a zookie token.
  Used in read queries to filter by consistency.
  Returns `nil` if the zookie doesn't exist.
  """
  @spec snapshot_at(binary()) :: DateTime.t() | nil
  def snapshot_at(token) do
    case decode(token) do
      nil -> nil
      %__MODULE__{snapshot_at: snap} -> snap
    end
  end
end