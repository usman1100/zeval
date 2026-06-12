defmodule ZevalCore.DashboardUser do
  @moduledoc """
  Ecto schema for the `dashboard_users` table.

  Dashboard users are human administrators who access the web UI.
  Passwords are stored as bcrypt hashes.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "dashboard_users" do
    field :email, :string
    field :name, :string
    field :password_hash, :string
    field :password, :string, virtual: true

    timestamps(type: :utc_datetime_usec, inserted_at: :inserted_at, updated_at: false)
  end

  def changeset(%__MODULE__{} = user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password])
    |> validate_required([:email, :name, :password])
    |> validate_length(:email, max: 255)
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> hash_password()
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = changeset) do
    change(changeset, password_hash: Bcrypt.hash_pwd_salt(pw))
  end

  defp hash_password(changeset), do: changeset
end