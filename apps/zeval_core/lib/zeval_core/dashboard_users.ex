defmodule ZevalCore.DashboardUsers do
  @moduledoc """
  Manages dashboard user accounts (human administrators).
  """

  import Ecto.Query, warn: false
  alias ZevalCore.{Repo, DashboardUser}

  @doc "Creates a new dashboard user with a hashed password."
  def create(attrs) do
    %DashboardUser{}
    |> DashboardUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Gets a dashboard user by ID."
  def get(id), do: Repo.get(DashboardUser, id)

  @doc "Gets a dashboard user by email."
  def get_by_email(email) when is_binary(email) do
    Repo.one(from u in DashboardUser, where: u.email == ^email)
  end

  @doc "Validates email and password. Returns `{:ok, user}` or `{:error, reason}`."
  def authenticate(email, password) when is_binary(email) and is_binary(password) do
    case get_by_email(email) do
      nil -> {:error, "invalid email or password"}
      user ->
        if Bcrypt.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, "invalid email or password"}
        end
    end
  end

  @doc "Returns all dashboard users."
  def list, do: Repo.all(from u in DashboardUser, order_by: u.email)
end