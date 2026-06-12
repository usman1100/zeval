defmodule ZevalCore.Tuples.Zookie do
  @moduledoc """
  Consistency tokens (zookies) for read-your-writes semantics.

  A zookie records a point-in-time snapshot using Postgres's NOW()
  to avoid clock drift between the application and database.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias ZevalCore.Repo

  @primary_key {:token, :string, []}
  schema "zookies" do
    field(:tenant_id, :binary_id)
    field(:snapshot_at, :utc_datetime_usec)
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
  Returns the `snapshot_at` timestamp from a zookie token, scoped to a tenant.

  A zookie is only honored for the tenant that minted it — otherwise a token
  from tenant A could be used to pick a read snapshot in tenant B. Returns
  `nil` if the token doesn't exist for this tenant.
  """
  @spec snapshot_at(binary(), binary()) :: DateTime.t() | nil
  def snapshot_at(token, tenant_id) when is_binary(token) and is_binary(tenant_id) do
    Repo.one(
      from(z in __MODULE__,
        where: z.token == ^token and z.tenant_id == ^tenant_id,
        select: z.snapshot_at
      )
    )
  end

  def snapshot_at(_, _), do: nil
end
