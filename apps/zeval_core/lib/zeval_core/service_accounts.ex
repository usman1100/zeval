defmodule ZevalCore.ServiceAccounts do
  @moduledoc """
  Manages service account API keys for the auth system.

  Keys follow the format `perm_{env}_{random_32_bytes_hex}` and are
  stored hashed (SHA-256). The raw key is returned once on creation
  and never stored again.
  """

  import Ecto.Query, warn: false
  alias ZevalCore.{Repo, ServiceAccount}

  @doc """
  Creates a new service account with a generated API key.
  Returns `{:ok, %{account: ..., raw_key: ...}}` or `{:error, changeset}`.

  The `raw_key` must be shown to the user once — it will never be
  visible again.
  """
  @spec create(binary(), String.t(), keyword()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
  def create(tenant_id, name, opts \\ []) when is_binary(name) do
    raw_key = generate_key()
    key_prefix = String.slice(raw_key, 0, 12)
    key_hash = hash_key(raw_key)

    %ServiceAccount{}
    |> ServiceAccount.changeset(%{
      tenant_id: tenant_id,
      name: name,
      key_hash: key_hash,
      key_prefix: key_prefix,
      created_by: Keyword.get(opts, :created_by)
    })
    |> Repo.insert()
    |> case do
      {:ok, account} -> {:ok, %{account: account, raw_key: raw_key}}
      {:error, _} = err -> err
    end
  end

  @doc """
  Looks up a service account by its hashed key.
  Returns `{:ok, account}` or `{:error, :not_found}`.
  Only returns non-revoked accounts.
  """
  @spec get_by_hash(binary()) :: {:ok, ServiceAccount.t()} | {:error, :not_found}
  def get_by_hash(key_hash) do
    case Repo.one(
           from(a in ServiceAccount,
             where: a.key_hash == ^key_hash and is_nil(a.revoked_at)
           )
         ) do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end

  @doc """
  Touches the `last_used_at` timestamp on an account.
  """
  @spec touch_last_used(binary()) :: :ok
  def touch_last_used(account_id) do
    Repo.update_all(
      from(a in ServiceAccount, where: a.id == ^account_id),
      set: [last_used_at: DateTime.utc_now()]
    )

    :ok
  end

  @doc """
  Fetches a service account by ID, or nil if the ID is missing/malformed.
  Includes revoked accounts (callers decide what to do with the status).
  """
  @spec get(binary()) :: ServiceAccount.t() | nil
  def get(account_id) when is_binary(account_id) do
    case Ecto.UUID.cast(account_id) do
      {:ok, _} -> Repo.get(ServiceAccount, account_id)
      :error -> nil
    end
  end

  def get(_), do: nil

  @doc """
  Revokes a service account by ID. Atomic and idempotent: a single
  `UPDATE ... WHERE id = ? AND revoked_at IS NULL` so concurrent callers
  don't both "succeed" and an already-revoked account reports not_found.

  Returns `{:ok, account}` or `{:error, :not_found}`.
  """
  @spec revoke(binary(), keyword()) :: {:ok, ServiceAccount.t()} | {:error, :not_found}
  def revoke(account_id, opts \\ []) when is_binary(account_id) do
    case Ecto.UUID.cast(account_id) do
      :error ->
        {:error, :not_found}

      {:ok, _} ->
        query =
          from(a in ServiceAccount,
            where: a.id == ^account_id and is_nil(a.revoked_at),
            select: a
          )

        set = [revoked_at: DateTime.utc_now(), revoked_by: Keyword.get(opts, :revoked_by)]

        case Repo.update_all(query, set: set) do
          {1, [account]} -> {:ok, account}
          {0, _} -> {:error, :not_found}
        end
    end
  end

  @doc """
  Lists all non-revoked service accounts for a tenant.
  """
  @spec list(binary()) :: [ServiceAccount.t()]
  def list(tenant_id) do
    Repo.all(
      from(a in ServiceAccount,
        where: a.tenant_id == ^tenant_id and is_nil(a.revoked_at),
        order_by: a.inserted_at
      )
    )
  end

  @doc """
  Lists service accounts (active and revoked) across every tenant the
  dashboard user belongs to, newest first.
  """
  @spec list_for_user(binary()) :: [ServiceAccount.t()]
  def list_for_user(user_id) do
    Repo.all(
      from(a in ServiceAccount,
        join: m in ZevalCore.TenantMembership,
        on: m.tenant_id == a.tenant_id,
        where: m.user_id == ^user_id,
        order_by: [desc: a.inserted_at]
      )
    )
  end

  # -- Key generation and hashing --

  @doc false
  def generate_key do
    env = Application.get_env(:zeval_web, :env, "dev")
    random = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    "perm_#{env}_#{random}"
  end

  @doc false
  def hash_key(raw_key) when is_binary(raw_key) do
    :crypto.hash(:sha256, raw_key) |> Base.encode16(case: :lower)
  end
end
